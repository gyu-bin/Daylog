-- 공개 템플릿의 권한 검사. 마이그레이션을 적용한 데이터베이스에서 관리자(postgres)로 실행한다:
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/community_rls_test.sql
--   (Supabase CLI: supabase db reset && psql "$(supabase status -o env | grep DB_URL | cut -d= -f2- | tr -d '"')" -f ...)
--
-- 전부 한 트랜잭션 안에서 돌고 마지막에 rollback 하므로 데이터가 남지 않는다. 어긋나는 것이 있으면 예외로 멈춘다.
-- 2026-10-13 기준: 로컬 Postgres가 없어 아직 한 번도 실행하지 못했다.

begin;

create schema rls_test;
grant usage on schema rls_test to anon, authenticated;

-- 사용자로 행동한다: API 요청과 같이 역할과 JWT 정보를 건다.
create function rls_test.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
end $$;

create function rls_test.act_as_anon() returns void language plpgsql as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
end $$;

create function rls_test.act_as_admin() returns void language plpgsql as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end $$;

-- 문장이 예외로 끝나면 true.
create function rls_test.fails(p_sql text) returns boolean language plpgsql as $$
begin
  execute p_sql;
  return false;
exception when others then
  return true;
end $$;

-- 문장이 바꾼 줄 수. 보이지 않는 줄을 고치거나 지우면 예외 없이 0이다.
create function rls_test.affected(p_sql text) returns integer language plpgsql as $$
declare v_count integer;
begin
  execute p_sql;
  get diagnostics v_count = row_count;
  return v_count;
end $$;

create function rls_test.expect(p_ok boolean, p_name text) returns void language plpgsql as $$
begin
  if p_ok is not true then raise exception 'FAILED: %', p_name; end if;
  raise notice 'ok - %', p_name;
end $$;

grant execute on all functions in schema rls_test to anon, authenticated;

do $$
declare
  alice uuid := '00000000-0000-0000-0000-00000000000a';
  bob   uuid := '00000000-0000-0000-0000-00000000000b';
  carol uuid := '00000000-0000-0000-0000-00000000000c';
  dave  uuid := '00000000-0000-0000-0000-00000000000d';
  admin uuid := '00000000-0000-0000-0000-0000000000ad';
  v_content   text := '{"groups":[{"title":"아침 루틴","colorKey":"orange","routines":[{"title":"물 한 잔","weekdays":[1,2,3,4,5,6,7],"time":"07:00","note":""}]}]}';
  v_thumbnail text := '{"symbol":"sunrise.fill","colorKey":"orange"}';
  v_public  uuid;
  v_private uuid;
  v_bobs    uuid;
  v_insert  text;
begin
  insert into auth.users (id, email) values
    (alice, 'alice@example.test'), (bob, 'bob@example.test'), (carol, 'carol@example.test'),
    (dave, 'dave@example.test'), (admin, 'admin@example.test');
  insert into private.moderators (user_id) values (admin);

  v_insert := format(
    'insert into public.templates (title, category, thumbnail, content, visibility) values (%%L, ''morning'', %L::jsonb, %L::jsonb, %%L) returning id',
    v_thumbnail, v_content);

  -- 비로그인: 게시할 수 없다 -------------------------------------------------------------------
  perform rls_test.act_as_anon();
  perform rls_test.expect(rls_test.fails(format(v_insert, '익명 게시', 'public')), 'anon cannot publish');

  -- 로그인: 게시한다. 게시자는 서버가 정한다 ---------------------------------------------------
  perform rls_test.act_as(alice);
  execute format(v_insert, '앨리스의 공개 템플릿', 'public') into v_public;
  execute format(v_insert, '앨리스의 비공개 템플릿', 'private') into v_private;
  perform rls_test.expect(
    (select author_id = alice and moderation = 'active' from public.templates where id = v_public), 'author is the signed-in user');
  -- 게시자·운영 상태·신고 수는 쓸 수 없는 열이다.
  perform rls_test.expect(rls_test.fails(format(
    'insert into public.templates (author_id, title, category, thumbnail, content) values (%L, ''위조'', ''morning'', %L::jsonb, %L::jsonb)',
    bob, v_thumbnail, v_content)), 'cannot forge author_id on insert');
  perform rls_test.expect(rls_test.fails(format('update public.templates set author_id = %L where id = %L', bob, v_public)),
    'cannot change author_id');
  perform rls_test.expect(rls_test.fails(format('update public.templates set moderation = ''active'', report_count = 0 where id = %L', v_public)),
    'cannot write moderation or report_count');
  perform rls_test.expect(rls_test.fails('select report_count from public.templates'), 'report_count is not readable');
  perform rls_test.expect(rls_test.fails('select * from private.moderators'), 'moderators table is not readable');

  -- 내용 검사: 모르는 칸, 빠진 칸, 범위를 벗어난 값 -------------------------------------------
  perform rls_test.expect(rls_test.fails(format(
    'insert into public.templates (title, category, thumbnail, content) values (''칸 추가'', ''morning'', %L::jsonb, %L::jsonb)',
    v_thumbnail, '{"groups":[{"title":"그룹","routines":[{"title":"루틴","weekdays":[1],"time":"","note":"","isDone":true}]}]}')),
    'unknown routine fields are rejected');
  perform rls_test.expect(rls_test.fails(format(
    'insert into public.templates (title, category, thumbnail, content) values (''기록 끼워 넣기'', ''morning'', %L::jsonb, %L::jsonb)',
    v_thumbnail, '{"groups":[{"title":"그룹","routines":[{"title":"루틴","weekdays":[1],"time":"","note":""}]}],"meals":["아침"]}')),
    'unknown top-level fields are rejected');
  perform rls_test.expect(rls_test.fails(format(
    'insert into public.templates (title, category, thumbnail, content) values (''제목 없음'', ''morning'', %L::jsonb, %L::jsonb)',
    v_thumbnail, '{"groups":[{"title":"그룹","routines":[{"weekdays":[1],"time":"","note":""}]}]}')),
    'missing routine title is rejected');
  perform rls_test.expect(rls_test.fails(format(
    'insert into public.templates (title, category, thumbnail, content) values (''요일'', ''morning'', %L::jsonb, %L::jsonb)',
    v_thumbnail, '{"groups":[{"title":"그룹","routines":[{"title":"루틴","weekdays":[8],"time":"","note":""}]}]}')),
    'weekdays outside 1 to 7 are rejected');
  perform rls_test.expect(rls_test.fails(format(
    'insert into public.templates (title, category, thumbnail, content) values (''분류'', ''travel'', %L::jsonb, %L::jsonb)',
    v_thumbnail, v_content)), 'unknown category is rejected');

  -- 조회: 공개만 남에게 보인다 -----------------------------------------------------------------
  perform rls_test.expect((select count(*) = 2 from public.templates), 'author sees own public and private');
  perform rls_test.act_as_anon();
  perform rls_test.expect((select count(*) = 1 from public.templates where id = v_public), 'anon sees public');
  perform rls_test.expect((select count(*) = 0 from public.templates where id = v_private), 'anon cannot see private');
  perform rls_test.act_as(bob);
  perform rls_test.expect((select count(*) = 0 from public.templates where id = v_private), 'another user cannot see private');

  -- 수정·삭제: 게시자만 ------------------------------------------------------------------------
  perform rls_test.expect(rls_test.affected(format('update public.templates set title = ''가로채기'' where id = %L', v_public)) = 0,
    'another user cannot update');
  perform rls_test.expect(rls_test.affected(format('delete from public.templates where id = %L', v_public)) = 0,
    'another user cannot delete');
  perform rls_test.act_as(alice);
  perform rls_test.expect(rls_test.affected(format('update public.templates set title = ''고친 제목'' where id = %L', v_public)) = 1,
    'author can update');
  perform rls_test.expect(rls_test.affected(format('update public.templates set visibility = ''public'' where id = %L', v_private)) = 1,
    'author can publish a private template');
  perform rls_test.expect(rls_test.affected(format('update public.templates set visibility = ''private'' where id = %L', v_private)) = 1,
    'author can make it private again');

  -- 차단: 내가 차단한 게시자의 것은 서버가 걸러 준다 -------------------------------------------
  perform rls_test.act_as(bob);
  execute format(v_insert, '밥의 공개 템플릿', 'public') into v_bobs;
  perform rls_test.expect(rls_test.fails(format('insert into public.blocked_authors (blocker_id, blocked_id) values (%L, %L)', carol, alice)),
    'cannot block on behalf of someone else');
  execute format('insert into public.blocked_authors (blocked_id) values (%L)', alice);
  perform rls_test.expect((select count(*) = 0 from public.templates where author_id = alice), 'blocked author is hidden');
  perform rls_test.expect(rls_test.fails(format('insert into public.blocked_authors (blocked_id) values (%L)', bob)), 'cannot block yourself');
  perform rls_test.act_as(carol);
  perform rls_test.expect((select count(*) = 0 from public.blocked_authors), 'block lists are private');
  perform rls_test.expect((select count(*) = 1 from public.templates where id = v_public), 'blocks do not affect other users');
  perform rls_test.act_as(bob);
  perform rls_test.expect(rls_test.affected(format('delete from public.blocked_authors where blocked_id = %L', alice)) = 1, 'can unblock');
  perform rls_test.expect((select count(*) = 1 from public.templates where id = v_public), 'unblocked author is visible again');

  -- 신고: 로그인 필요, 한 번만, 자기 것·비공개는 안 됨 ----------------------------------------
  perform rls_test.act_as_anon();
  perform rls_test.expect(rls_test.fails(format('insert into public.template_reports (template_id, reason) values (%L, ''spam'')', v_public)),
    'anon cannot report');
  perform rls_test.act_as(alice);
  perform rls_test.expect(rls_test.fails(format('insert into public.template_reports (template_id, reason) values (%L, ''spam'')', v_public)),
    'cannot report your own template');
  perform rls_test.act_as(bob);
  perform rls_test.expect(rls_test.fails(format('insert into public.template_reports (template_id, reason) values (%L, ''spam'')', v_private)),
    'cannot report a private template');
  perform rls_test.expect(rls_test.fails(format(
    'insert into public.template_reports (template_id, reporter_id, reason) values (%L, %L, ''spam'')', v_public, carol)),
    'cannot forge reporter_id');
  perform rls_test.expect(rls_test.fails(format(
    'insert into public.template_reports (template_id, reason, status) values (%L, ''spam'', ''actioned'')', v_public)),
    'cannot set report status');
  execute format('insert into public.template_reports (template_id, reason, detail) values (%L, ''spam'', ''광고'')', v_public);
  perform rls_test.expect(rls_test.fails(format('insert into public.template_reports (template_id, reason) values (%L, ''other'')', v_public)),
    'duplicate report is rejected');
  perform rls_test.expect((select count(*) = 1 from public.template_reports), 'reporter sees own report');
  perform rls_test.expect(rls_test.fails('update public.template_reports set status = ''dismissed'''), 'reporter cannot change a report');
  perform rls_test.act_as(alice);
  perform rls_test.expect((select count(*) = 0 from public.template_reports), 'author cannot see who reported');

  -- 신고가 세 사람에게서 오면 검토 중으로 바뀌어 목록에서 빠진다 -------------------------------
  perform rls_test.act_as(carol);
  execute format('insert into public.template_reports (template_id, reason) values (%L, ''inappropriate'')', v_public);
  perform rls_test.expect((select count(*) = 1 from public.templates where id = v_public), 'two reports keep it listed');
  perform rls_test.act_as(dave);
  execute format('insert into public.template_reports (template_id, reason) values (%L, ''inappropriate'')', v_public);
  perform rls_test.expect((select count(*) = 0 from public.templates where id = v_public), 'three reports hide it pending review');
  perform rls_test.act_as(alice);
  perform rls_test.expect((select moderation = 'under_review' from public.templates where id = v_public), 'author sees the review state');
  perform rls_test.expect(rls_test.fails(format('update public.templates set moderation = ''active'' where id = %L', v_public)),
    'author cannot clear the review state');
  -- 게시자가 내용을 고쳐도 운영 상태는 그대로다.
  perform rls_test.expect(rls_test.affected(format('update public.templates set title = ''다시 고친 제목'' where id = %L', v_public)) = 1
    and (select moderation = 'under_review' from public.templates where id = v_public), 'editing does not reset moderation');

  -- 관리자 처리: 서버가 관리자인지 확인한다 ---------------------------------------------------
  perform rls_test.act_as(bob);
  perform rls_test.expect(rls_test.fails(format('select public.moderate_template(%L, ''active'', ''dismissed'')', v_public)),
    'regular user cannot moderate');
  perform rls_test.expect(rls_test.fails('select * from public.moderation_queue()'), 'regular user cannot read the queue');
  perform rls_test.act_as_anon();
  perform rls_test.expect(rls_test.fails('select * from public.moderation_queue()'), 'anon cannot read the queue');
  perform rls_test.act_as(admin);
  perform rls_test.expect((select count(*) = 1 from public.moderation_queue() where template_id = v_public and open_reports = 3),
    'moderator sees the queue');
  perform public.moderate_template(v_public, 'removed', 'actioned');
  perform rls_test.expect((select count(*) = 3 from public.template_reports where status = 'actioned'), 'reports are marked reviewed');
  perform rls_test.act_as(carol);
  perform rls_test.expect((select count(*) = 0 from public.templates where id = v_public), 'removed template stays hidden');
  perform rls_test.act_as(admin);
  perform public.moderate_template(v_public, 'active', 'dismissed');
  perform rls_test.act_as_anon();
  perform rls_test.expect((select count(*) = 1 from public.templates where id = v_public), 'restored template is listed again');

  -- 계정 삭제: 자기 것만 사라진다 --------------------------------------------------------------
  perform rls_test.act_as_anon();
  perform rls_test.expect(rls_test.fails('select public.delete_my_account()'), 'anon cannot call delete_my_account');
  perform rls_test.act_as(bob);
  perform public.delete_my_account();
  perform rls_test.act_as_admin();
  perform rls_test.expect((select count(*) = 0 from public.templates where id = v_bobs), 'deleting the account removes its templates');
  perform rls_test.expect((select count(*) = 2 from public.templates where author_id = alice), 'other users are untouched');
  perform rls_test.expect((select count(*) = 0 from auth.users where id = bob), 'the account is gone');

  raise notice 'community RLS tests passed';
end $$;

rollback;
