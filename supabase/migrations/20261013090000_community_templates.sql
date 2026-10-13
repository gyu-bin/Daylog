-- Daylog 공개 템플릿 (Phase 5-D1)
--
-- 이 파일은 설계와 검토를 위한 마이그레이션이다. 2026-10-13 기준으로 어떤 원격 프로젝트에도 적용하지 않았고,
-- 로컬 Postgres가 없어 실행해 보지도 못했다. 적용 전에 supabase/tests/community_rls_test.sql 을 반드시 통과시킨다.
--
-- 원칙
--   * 앱은 anon 키와 로그인한 사용자의 JWT만 쓴다. service_role 키는 앱에 넣지 않는다.
--   * 게시자·검토 상태·신고 수는 클라이언트가 쓸 수 없다(열 권한 + 트리거가 서버 값으로 덮는다).
--   * 관리자 여부는 private 스키마의 표로만 정하고, API로 노출되는 스키마에는 두지 않는다.
--   * 템플릿 내용은 정해진 칸만 받는다(모르는 칸이 있으면 거절). 개인 기록이 실려 올 자리가 없다.

create schema if not exists private;

-- ---------------------------------------------------------------------------
-- 관리자
-- ---------------------------------------------------------------------------

-- 관리자 목록. SQL 콘솔(또는 service_role)로만 넣는다. anon·authenticated 에는 아무 권한도 주지 않는다.
create table private.moderators (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

revoke all on table private.moderators from public, anon, authenticated;

-- 지금 요청한 사용자가 관리자인지. 자기 자신에 대한 참/거짓만 돌려준다.
create function private.is_moderator()
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from private.moderators m where m.user_id = (select auth.uid())
  );
$$;

revoke execute on function private.is_moderator() from public;
grant usage on schema private to anon, authenticated;
grant execute on function private.is_moderator() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 템플릿
-- ---------------------------------------------------------------------------

create table public.templates (
  id             uuid primary key default gen_random_uuid(),
  -- 게시자. 클라이언트는 이 열을 쓸 수 없고, 트리거가 항상 auth.uid() 로 채운다.
  author_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  -- 게시자가 고른 표시 이름(선택). 실명이나 Apple 계정 정보를 자동으로 넣지 않는다.
  author_name    text not null default '' check (char_length(author_name) <= 20),
  title          text not null check (char_length(btrim(title)) between 1 and 30),
  summary        text not null default '' check (char_length(summary) <= 80),
  category       text not null check (category in ('morning', 'fitness', 'study', 'focus', 'lifestyle')),
  tags           text[] not null default '{}' check (cardinality(tags) <= 8),
  -- {"symbol": "sunrise.fill", "colorKey": "orange"}
  thumbnail      jsonb not null,
  -- {"groups": [{"title": "...", "colorKey": "...", "routines": [{"title": "...", "weekdays": [1,2], "time": "07:00", "note": ""}]}]}
  content        jsonb not null,
  visibility     text not null default 'private' check (visibility in ('public', 'private')),
  -- 운영 상태. active = 정상, under_review = 신고가 쌓여 검토 중(목록에서 숨김), removed = 관리자가 내림.
  moderation     text not null default 'active' check (moderation in ('active', 'under_review', 'removed')),
  report_count   integer not null default 0 check (report_count >= 0),
  format_version integer not null default 1 check (format_version = 1),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index templates_listing_idx on public.templates (created_at desc) where visibility = 'public' and moderation = 'active';
create index templates_author_idx on public.templates (author_id);
create index templates_tags_idx on public.templates using gin (tags);

-- 내용 검사. 통과하면 null, 아니면 까닭을 돌려준다.
create function private.template_content_error(p_content jsonb, p_thumbnail jsonb, p_tags text[])
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_group   jsonb;
  v_routine jsonb;
  v_day     jsonb;
  v_tag     text;
  v_total   integer := 0;
  v_days    integer[];
begin
  -- 없는 칸은 jsonb_typeof 가 null 을 돌려준다. null 과의 비교는 조건을 그냥 지나가게 하므로 "is distinct from" 으로 본다.
  if p_content is null or p_thumbnail is null or p_tags is null then return 'content, thumbnail and tags are required'; end if;
  if octet_length(p_content::text) > 16000 then return 'content too large'; end if;
  if jsonb_typeof(p_content) is distinct from 'object' then return 'content must be an object'; end if;
  if (select count(*) from jsonb_object_keys(p_content) k where k <> 'groups') > 0 then
    return 'content has unknown fields';
  end if;
  if jsonb_typeof(p_content -> 'groups') is distinct from 'array' then return 'groups must be an array'; end if;
  if jsonb_array_length(p_content -> 'groups') not between 1 and 10 then return 'groups must have 1 to 10 items'; end if;

  for v_group in select * from jsonb_array_elements(p_content -> 'groups') loop
    if jsonb_typeof(v_group) is distinct from 'object' then return 'group must be an object'; end if;
    if (select count(*) from jsonb_object_keys(v_group) k where k not in ('title', 'colorKey', 'routines')) > 0 then
      return 'group has unknown fields';
    end if;
    if jsonb_typeof(v_group -> 'title') is distinct from 'string' then return 'group title is required'; end if;
    if char_length(btrim(v_group ->> 'title')) not between 1 and 40 then return 'group title must be 1 to 40 characters'; end if;
    if v_group ? 'colorKey' and jsonb_typeof(v_group -> 'colorKey') is distinct from 'null' then
      if jsonb_typeof(v_group -> 'colorKey') is distinct from 'string' then return 'group colorKey must be a string'; end if;
      if (v_group ->> 'colorKey') !~ '^[a-z]{1,12}$' then return 'group colorKey is invalid'; end if;
    end if;
    if jsonb_typeof(v_group -> 'routines') is distinct from 'array' then return 'routines must be an array'; end if;
    if jsonb_array_length(v_group -> 'routines') < 1 then return 'group must have routines'; end if;

    for v_routine in select * from jsonb_array_elements(v_group -> 'routines') loop
      v_total := v_total + 1;
      if jsonb_typeof(v_routine) is distinct from 'object' then return 'routine must be an object'; end if;
      if (select count(*) from jsonb_object_keys(v_routine) k where k not in ('title', 'weekdays', 'time', 'note')) > 0 then
        return 'routine has unknown fields';
      end if;
      if jsonb_typeof(v_routine -> 'title') is distinct from 'string' then return 'routine title is required'; end if;
      if char_length(btrim(v_routine ->> 'title')) not between 1 and 60 then return 'routine title must be 1 to 60 characters'; end if;
      if jsonb_typeof(v_routine -> 'weekdays') is distinct from 'array' then return 'weekdays must be an array'; end if;
      if jsonb_array_length(v_routine -> 'weekdays') not between 1 and 7 then return 'weekdays must have 1 to 7 items'; end if;
      v_days := '{}';
      for v_day in select * from jsonb_array_elements(v_routine -> 'weekdays') loop
        if jsonb_typeof(v_day) is distinct from 'number' then return 'weekdays must be numbers'; end if;
        if (v_day #>> '{}') !~ '^[1-7]$' then return 'weekdays must be integers 1 to 7'; end if;
        if (v_day #>> '{}')::integer = any (v_days) then return 'weekdays must be distinct'; end if;
        v_days := v_days || (v_day #>> '{}')::integer;
      end loop;
      if jsonb_typeof(v_routine -> 'time') is distinct from 'string' then return 'time must be a string'; end if;
      if char_length(v_routine ->> 'time') > 12 then return 'time must be up to 12 characters'; end if;
      if jsonb_typeof(v_routine -> 'note') is distinct from 'string' then return 'note must be a string'; end if;
      if char_length(v_routine ->> 'note') > 60 then return 'note must be up to 60 characters'; end if;
    end loop;
  end loop;
  if v_total > 20 then return 'at most 20 routines'; end if;

  if jsonb_typeof(p_thumbnail) is distinct from 'object' then return 'thumbnail must be an object'; end if;
  if (select count(*) from jsonb_object_keys(p_thumbnail) k where k not in ('symbol', 'colorKey')) > 0 then
    return 'thumbnail has unknown fields';
  end if;
  if jsonb_typeof(p_thumbnail -> 'symbol') is distinct from 'string' or jsonb_typeof(p_thumbnail -> 'colorKey') is distinct from 'string' then
    return 'thumbnail symbol and colorKey are required';
  end if;
  if (p_thumbnail ->> 'symbol') !~ '^[a-z0-9.]{1,40}$' or (p_thumbnail ->> 'colorKey') !~ '^[a-z]{1,12}$' then
    return 'thumbnail is invalid';
  end if;

  foreach v_tag in array p_tags loop
    if v_tag is null or char_length(btrim(v_tag)) not between 1 and 12 then return 'tags must be 1 to 12 characters'; end if;
  end loop;
  return null;
end;
$$;

-- 쓰기 직전: 게시자·운영 상태·신고 수·시각을 서버 값으로 고정하고 내용을 검사한다.
-- security invoker 로 돈다. API 를 거친 요청은 current_user 가 anon/authenticated 이고,
-- 아래의 security definer 함수(신고 집계·관리자 처리) 안에서는 함수 소유자다.
create function private.templates_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_error text;
  v_uid   uuid := (select auth.uid());
begin
  if current_user in ('anon', 'authenticated') then
    if tg_op = 'INSERT' then
      if v_uid is null then raise exception 'sign in required' using errcode = '42501'; end if;
      new.author_id := v_uid;
      new.moderation := 'active';
      new.report_count := 0;
      new.format_version := 1;
      new.created_at := now();
      if (select count(*) from public.templates t where t.author_id = v_uid) >= 30 then
        raise exception 'template limit reached' using errcode = 'P0001', hint = 'limit_reached';
      end if;
    else
      new.id := old.id;
      new.author_id := old.author_id;
      new.moderation := old.moderation;
      new.report_count := old.report_count;
      new.format_version := old.format_version;
      new.created_at := old.created_at;
    end if;
  end if;
  new.updated_at := now();
  new.author_name := btrim(new.author_name);
  v_error := private.template_content_error(new.content, new.thumbnail, new.tags);
  if v_error is not null then
    raise exception 'invalid template: %', v_error using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger templates_before_write
  before insert or update on public.templates
  for each row execute function private.templates_before_write();

-- ---------------------------------------------------------------------------
-- 차단
-- ---------------------------------------------------------------------------

create table public.blocked_authors (
  blocker_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  blocked_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.blocked_authors enable row level security;

create policy "blocked_authors: read own" on public.blocked_authors
  for select to authenticated using (blocker_id = (select auth.uid()));
create policy "blocked_authors: add own" on public.blocked_authors
  for insert to authenticated with check (blocker_id = (select auth.uid()));
create policy "blocked_authors: remove own" on public.blocked_authors
  for delete to authenticated using (blocker_id = (select auth.uid()));

revoke all on table public.blocked_authors from public, anon, authenticated;
grant select, delete on table public.blocked_authors to authenticated;
-- blocker_id 는 쓸 수 없다(기본값 auth.uid()).
grant insert (blocked_id) on table public.blocked_authors to authenticated;

-- ---------------------------------------------------------------------------
-- 템플릿의 행 수준 보안과 권한
-- ---------------------------------------------------------------------------

alter table public.templates enable row level security;

-- 보이는 것: 내 것 전부 / 공개이고 정상이며 내가 차단하지 않은 게시자의 것 / (관리자) 전부.
-- 차단 표는 자기 줄만 보이므로, 아래의 하위 질의는 "내가 차단한 게시자"만 본다.
create policy "templates: read public or own" on public.templates
  for select to anon, authenticated
  using (
    author_id = (select auth.uid())
    or (
      visibility = 'public'
      and moderation = 'active'
      and not exists (
        select 1 from public.blocked_authors b
        where b.blocker_id = (select auth.uid()) and b.blocked_id = templates.author_id
      )
    )
    or (select private.is_moderator())
  );

create policy "templates: insert own" on public.templates
  for insert to authenticated with check (author_id = (select auth.uid()));
create policy "templates: update own" on public.templates
  for update to authenticated
  using (author_id = (select auth.uid())) with check (author_id = (select auth.uid()));
create policy "templates: delete own" on public.templates
  for delete to authenticated using (author_id = (select auth.uid()));

revoke all on table public.templates from public, anon, authenticated;
-- report_count 는 읽을 수도 없다. 앱은 열을 이름으로 고른다(select=* 를 쓰지 않는다).
grant select (id, author_id, author_name, title, summary, category, tags, thumbnail, content, visibility, moderation,
              format_version, created_at, updated_at)
  on table public.templates to anon, authenticated;
-- author_id·moderation·report_count·시각은 쓸 수 없다.
grant insert (author_name, title, summary, category, tags, thumbnail, content, visibility)
  on table public.templates to authenticated;
grant update (author_name, title, summary, category, tags, thumbnail, content, visibility)
  on table public.templates to authenticated;
grant delete on table public.templates to authenticated;

-- ---------------------------------------------------------------------------
-- 신고
-- ---------------------------------------------------------------------------

create table public.template_reports (
  id          uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.templates (id) on delete cascade,
  reporter_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  reason      text not null check (reason in ('spam', 'inappropriate', 'personal_info', 'copyright', 'other')),
  detail      text not null default '' check (char_length(detail) <= 200),
  -- 관리자 검토 상태.
  status      text not null default 'open' check (status in ('open', 'reviewing', 'dismissed', 'actioned')),
  reviewed_by uuid,
  reviewed_at timestamptz,
  created_at  timestamptz not null default now(),
  -- 한 사람은 한 템플릿을 한 번만 신고한다.
  unique (template_id, reporter_id)
);

create index template_reports_open_idx on public.template_reports (created_at) where status in ('open', 'reviewing');

-- 신고 직전: 신고자를 서버 값으로 고정하고, 신고할 수 있는 대상인지와 하루 한도를 본다.
-- 다른 사람의 템플릿과 신고 수를 읽어야 해서 security definer 다.
create function private.template_reports_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_author uuid;
begin
  if v_uid is null then raise exception 'sign in required' using errcode = '42501'; end if;
  new.reporter_id := v_uid;
  new.status := 'open';
  new.reviewed_by := null;
  new.reviewed_at := null;
  new.created_at := now();

  select t.author_id into v_author
  from public.templates t
  where t.id = new.template_id and t.visibility = 'public' and t.moderation in ('active', 'under_review');
  if v_author is null then raise exception 'template cannot be reported' using errcode = 'P0001', hint = 'not_reportable'; end if;
  if v_author = v_uid then raise exception 'cannot report your own template' using errcode = 'P0001', hint = 'own_template'; end if;

  if (select count(*) from public.template_reports r
      where r.reporter_id = v_uid and r.created_at > now() - interval '24 hours') >= 10 then
    raise exception 'report limit reached' using errcode = 'P0001', hint = 'limit_reached';
  end if;
  return new;
end;
$$;

create trigger template_reports_before_insert
  before insert on public.template_reports
  for each row execute function private.template_reports_before_insert();

-- 신고 뒤: 신고 수를 올리고, 서로 다른 세 사람이 신고하면 검토가 끝날 때까지 목록에서 숨긴다.
create function private.template_reports_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.templates t
  set report_count = t.report_count + 1,
      moderation = case when t.moderation = 'active' and t.report_count + 1 >= 3 then 'under_review' else t.moderation end
  where t.id = new.template_id;
  return null;
end;
$$;

create trigger template_reports_after_insert
  after insert on public.template_reports
  for each row execute function private.template_reports_after_insert();

alter table public.template_reports enable row level security;

-- 신고는 넣기만 한다. 고치거나 지우는 정책이 없다(관리자 처리는 아래 함수로만).
create policy "template_reports: insert own" on public.template_reports
  for insert to authenticated with check (reporter_id = (select auth.uid()));
create policy "template_reports: read own" on public.template_reports
  for select to authenticated using (reporter_id = (select auth.uid()) or (select private.is_moderator()));

revoke all on table public.template_reports from public, anon, authenticated;
grant select (id, template_id, reason, detail, status, created_at) on table public.template_reports to authenticated;
grant insert (template_id, reason, detail) on table public.template_reports to authenticated;

-- ---------------------------------------------------------------------------
-- 관리자 처리와 계정 삭제 (RPC)
-- ---------------------------------------------------------------------------

-- 검토 대기 목록. 관리자가 아니면 거절한다.
create function public.moderation_queue()
returns table (
  template_id uuid, title text, author_id uuid, visibility text, moderation text, report_count integer,
  open_reports bigint, last_reported_at timestamptz
)
language plpgsql
security definer
set search_path = ''
stable
as $$
begin
  if not private.is_moderator() then raise exception 'forbidden' using errcode = '42501'; end if;
  return query
    select t.id, t.title, t.author_id, t.visibility, t.moderation, t.report_count,
           count(r.id) filter (where r.status in ('open', 'reviewing')), max(r.created_at)
    from public.templates t
    join public.template_reports r on r.template_id = t.id
    group by t.id
    having count(r.id) filter (where r.status in ('open', 'reviewing')) > 0
    order by max(r.created_at) desc;
end;
$$;

-- 템플릿의 운영 상태를 정하고, 열려 있던 신고를 처리 상태로 바꾼다. 관리자가 아니면 거절한다.
create function public.moderate_template(p_template_id uuid, p_moderation text, p_report_status text default 'actioned')
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_moderator() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_moderation not in ('active', 'under_review', 'removed') or p_report_status not in ('reviewing', 'dismissed', 'actioned') then
    raise exception 'invalid state' using errcode = '22023';
  end if;
  update public.templates t
  set moderation = p_moderation,
      report_count = case when p_moderation = 'active' then 0 else t.report_count end
  where t.id = p_template_id;
  if not found then raise exception 'template not found' using errcode = 'P0002'; end if;
  update public.template_reports r
  set status = p_report_status, reviewed_by = (select auth.uid()), reviewed_at = now()
  where r.template_id = p_template_id and r.status in ('open', 'reviewing');
end;
$$;

-- 계정 삭제(App Store 심사 지침 5.1.1(v)). 자기 계정만 지운다. 템플릿·신고·차단은 외래 키로 함께 지워진다.
-- 다른 사람이 이미 가져간 루틴은 각자의 기기에 있는 사본이라 영향이 없다.
create function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'sign in required' using errcode = '42501'; end if;
  delete from auth.users u where u.id = v_uid;
end;
$$;

revoke execute on function public.moderation_queue() from public, anon;
revoke execute on function public.moderate_template(uuid, text, text) from public, anon;
revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.moderation_queue() to authenticated;
grant execute on function public.moderate_template(uuid, text, text) to authenticated;
grant execute on function public.delete_my_account() to authenticated;
