# Daylog 공개 템플릿 (Phase 5-D1) — 보류

> **2026-10-13 결정: Supabase 커뮤니티는 보류한다.** 사용자 간 공유는 서버 없이 **템플릿 파일**로 한다(Phase 5-D, [ARCHITECTURE.md](../ARCHITECTURE.md) "템플릿 파일 공유").
> 이 문서의 서버 설계와 `Services/Community/`의 코드, `supabase/`의 SQL은 지우지 않고 꺼 둔 채로 남긴다.
> 앱 설정에 서버 주소가 없으므로 관련 화면은 나오지 않고, 실제 프로젝트를 만들거나 연결하지 않는다.
> 아래 "승인이 필요한 일"은 커뮤니티를 다시 진행하기로 할 때의 목록이며, 지금은 어느 것도 진행하지 않는다.

사용자가 자기 루틴을 템플릿으로 올리고, 다른 사람이 그것을 가져가는 기능의 서버 구조와 앱 쪽 기반.

## 지금 상태 (2026-10-13)

| 항목 | 상태 |
|---|---|
| 앱 코드(게시·관리·신고·차단·탐색 연결) | 구현. 가짜 서버(`MockCommunityBackend`)와 가짜 전송(`StubTransport`)으로 검증 |
| SQL 스키마·행 수준 보안(RLS)·검사 스크립트 | 작성. **한 번도 실행하지 못했다**(이 Mac에 Postgres·Supabase CLI·Docker가 없다) |
| Supabase 프로젝트 | **없음.** 만들지 않았다(승인 필요) |
| 실제 서버 연동 | **안 됨.** 앱 설정에 서버 주소·키가 없어 공유 기능은 꺼져 있다 |
| Apple 로그인 | 코드만 있다. 앱 서명에 권한이 없어 동작하지 않는다(승인 필요) |
| macOS의 서버 연결 | 샌드박스에 네트워크 권한이 없어 지금은 연결할 수 없다(승인 필요) |

배포된 앱과 저장소의 기본 빌드에서는 공유와 관련된 화면이 전혀 나오지 않는다. 템플릿 메뉴는 Phase 5-C와 같이 공식 템플릿 11개만 보여 준다.

## 원칙

- 템플릿 탐색과 가져오기는 로그인 없이 된다. 게시·수정·삭제·신고·차단만 로그인이 필요하다.
- 개인 기록(루틴·체크·식사·휴가)은 로그인과 무관하다. 로그아웃·계정 삭제·네트워크 오류가 개인 기록을 바꾸지 않는다.
- 공유용 계정은 iCloud 계정과 별개다. 같은 사람이라고 가정하지 않는다.
- 게시물은 게시한 때의 사본이다. 내 루틴을 바꿔도 따라 바뀌지 않고, 게시물을 지워도 다른 사람이 가져간 루틴은 남는다.
- 앱에는 공개(anon) 키만 넣는다. `service_role` 키는 넣지 않는다(`CommunityConfiguration`이 그런 키를 거절한다).
- 좋아요·댓글·팔로우·채팅은 없다.

## 올라가는 것과 올라가지 않는 것

올라가는 것(= `TemplateDraft.payload()`의 전부):

| 칸 | 내용 |
|---|---|
| `title`, `summary` | 제목, 설명 |
| `category`, `tags` | 분류, 태그 |
| `thumbnail` | 기호 이름과 색 이름(사진 아님) |
| `author_name` | 사용자가 적은 표시 이름(선택, 비우면 "익명") |
| `content.groups[]` | 그룹 이름·색, 루틴의 이름·요일·시각, (사용자가 포함한다고 켠 경우에만) 루틴 설명 |
| `visibility` | 공개 / 비공개 |

올라가지 않는 것: 체크·완료·건너뛰기 기록, 식사, 휴가, 통계, 사진과 대시보드 배경, 텍스트 카드, 기기·iCloud 식별자, 그룹·루틴의 내부 ID와 동기화 정보.
게시 내용은 `TemplatePublishing.GroupSource`에서만 만들어지는데, 이 값에 위의 칸 말고는 들어갈 자리가 없다. 서버도 정해진 칸 말고는 받지 않는다(`private.template_content_error`).
게시 화면의 "5. 공개될 내용"은 서버로 보내는 JSON과 같은 내용을 보여 주고, 원문도 펼쳐 볼 수 있다.

## 서버 구조

마이그레이션: [supabase/migrations/20261013090000_community_templates.sql](../supabase/migrations/20261013090000_community_templates.sql)

### 표

| 표 | 용도 | 주요 열 |
|---|---|---|
| `public.templates` | 템플릿 | `id`, `author_id`, `author_name`, `title`, `summary`, `category`, `tags`, `thumbnail`(jsonb), `content`(jsonb), `visibility`(public/private), `moderation`(active/under_review/removed), `report_count`, `created_at`, `updated_at` |
| `public.template_reports` | 신고 | `template_id`, `reporter_id`, `reason`, `detail`, `status`(open/reviewing/dismissed/actioned), `reviewed_by`, `reviewed_at`. `(template_id, reporter_id)` 유일 |
| `public.blocked_authors` | 차단 | `blocker_id`, `blocked_id` |
| `private.moderators` | 관리자 | `user_id`. API로 노출되지 않는 스키마 |

### 누가 무엇을 할 수 있나

| 동작 | 비로그인 | 로그인 | 게시자 본인 | 관리자 |
|---|---|---|---|---|
| 공개·정상 템플릿 읽기 | 가능 | 가능(차단한 게시자 제외) | 가능 | 가능 |
| 비공개·검토 중·내린 템플릿 읽기 | 불가 | 불가 | 자기 것만 | 가능 |
| 게시 | 불가 | 가능(자기 이름으로만) | — | — |
| 수정·삭제 | 불가 | 불가 | 자기 것만 | (함수로 상태만) |
| 신고 | 불가 | 남의 공개 템플릿, 한 번만 | 불가(자기 것) | — |
| 신고 목록 읽기 | 불가 | 자기가 한 신고만 | 불가(누가 신고했는지 모름) | 가능 |
| 차단 목록 | 불가 | 자기 것만 | — | — |
| 운영 상태 변경 | 불가 | 불가 | 불가 | `moderate_template()` |

### 위조와 악용을 막는 장치

- **게시자 위조**: `author_id`는 쓸 수 있는 열이 아니다(열 권한). 기본값이 `auth.uid()`이고, 쓰기 직전 트리거가 다시 `auth.uid()`로 덮는다. 수정할 때는 예전 값으로 되돌린다.
- **운영 상태·신고 수**: `moderation`, `report_count`도 쓸 수 없는 열이고 트리거가 고정한다. `report_count`는 읽을 수도 없다.
- **내용**: `content`와 `thumbnail`은 정해진 칸만 받는다. 모르는 칸, 빠진 칸, 범위를 벗어난 값(요일 1~7, 루틴 20개, 16KB 등)은 거절한다.
- **게시 한도**: 한 사람당 30개.
- **신고**: 신고자는 서버가 정한다. 한 템플릿에 한 번, 하루 10건, 자기 것과 비공개는 신고할 수 없다. 서로 다른 세 사람이 신고하면 `under_review`가 되어 검토가 끝날 때까지 목록에서 빠진다.
  (세 계정이 짜고 멀쩡한 템플릿을 잠시 숨길 수는 있다. 관리자가 `active`로 되돌리면 신고 수가 0으로 돌아간다. 운영하면서 문턱을 조정한다.)
- **차단**: `blocker_id`는 서버가 정한다. 차단한 게시자의 템플릿은 서버의 읽기 정책이 걸러 준다. 다른 사람의 차단 목록은 볼 수 없다.
- **관리자**: 관리자 목록은 `private` 스키마에 있고 일반 사용자에게 아무 권한이 없다. 관리자 여부는 서버의 `private.is_moderator()`가 판단한다. 관리자 계정은 SQL 콘솔에서만 추가한다.
- **계정 삭제**: `delete_my_account()`가 자기 계정만 지운다. 템플릿·신고·차단이 함께 지워진다(App Store 심사 지침 5.1.1(v)).

### 검사 스크립트

[supabase/tests/community_rls_test.sql](../supabase/tests/community_rls_test.sql)이 위 표의 권한을 사용자 역할을 바꿔 가며 확인한다(게시자 위조, 남의 것 수정·삭제, 비공개 조회, 중복 신고, 세 번 신고 뒤 숨김, 차단, 관리자 함수, 계정 삭제 등 40여 가지).
한 트랜잭션 안에서 돌고 끝에 되돌리므로 데이터가 남지 않는다.

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/community_rls_test.sql
```

이 스크립트와 마이그레이션은 아직 실행하지 못했다. **적용 전에 로컬 Supabase나 빈 프로젝트에서 반드시 통과시킨다.** 통과하기 전에는 권한이 검증됐다고 말할 수 없다.

## 앱 구조

| 파일 | 역할 |
|---|---|
| `Services/Community/CommunityModels.swift` | 설정(`CommunityConfiguration`), 게시 내용(`TemplateDraft`), 서버의 템플릿(`CommunityTemplate`), 오류 |
| `Services/Community/CommunityBackend.swift` | 서버가 해 주는 일의 목록(`CommunityBackend`), 전송과 로그인 저장소의 틀 |
| `Services/Community/SupabaseCommunityBackend.swift` | 실제 구현. SDK 없이 HTTPS로 PostgREST와 Auth에 요청한다 |
| `Services/Community/KeychainSessionStore.swift` | 로그인 정보를 이 기기의 키체인에 둔다(iCloud 키체인 동기화 안 함) |
| `Services/Community/MockCommunityBackend.swift` | 시험용 서버(Debug 빌드에만). 서버의 규칙을 흉내 낸다 |
| `Services/Community/TemplatePublishing.swift` | 내 루틴에서 게시 내용을 만든다 |
| `Services/Community/CommunityStore.swift` | 화면 상태. `AppStore`(개인 기록)와 서로 모른다 |
| `Views/Templates/TemplatePublishSheet.swift` | [내 템플릿 올리기]와 수정 |
| `Views/Templates/MyTemplatesSheet.swift` | [내 템플릿]: 상태, 수정, 공개·비공개, 삭제, 차단 해제, 로그인 관리 / 신고 시트 |
| `Views/Templates/CommunityAccountSection.swift` | 로그인·로그아웃·계정 삭제 |

- **탐색**: 템플릿 화면은 공식 템플릿 뒤에 공개 템플릿을 이어서 같은 검색·분류·미리보기로 보여 준다. 카드에 "공식" 또는 게시자 이름이 붙는다.
  공개 템플릿을 받지 못하면 안내 한 줄과 [다시 시도]만 나오고 공식 템플릿은 그대로다.
- **가져오기**: 공개 템플릿도 공식 템플릿과 같은 `RoutineTransferService`를 지난다(겹치는 줄은 건너뛰고, 기존 루틴은 고치지 않고, 오늘부터 적용).
  서버에서 받은 템플릿은 앱의 검사(`RoutineTemplate.validationError`)를 한 번 더 통과해야 목록에 나온다.
- **요청**: 모든 요청에 공개 키를 `apikey`로 싣고, 로그인했으면 사용자의 접근 토큰을, 아니면 공개 키를 `Authorization`에 싣는다. 게시자 ID는 보내지 않는다.
  읽는 열은 이름으로 고른다(`report_count`는 읽을 권한이 없다).
- **로그인 정보**: 접근 토큰과 갱신 토큰은 키체인에만 둔다. 만료가 가까우면 갱신하고, 갱신이 거절되면 지우고 다시 로그인하게 한다. 네트워크 오류로는 지우지 않는다.
- **Apple 로그인**: `SignInWithAppleButton`으로 ID 토큰을 받아 Supabase Auth의 `grant_type=id_token`으로 바꾼다. 이름·이메일은 요청하지 않는다. 요청마다 새 nonce를 쓴다(원문은 서버로, SHA-256은 Apple로).

### 켜는 방법 (승인 뒤)

`Config/Daylog-Info.plist`와 `Config/DaylogiOS-Info.plist`에 다음 값을 넣으면 공유 기능이 켜진다. 값이 없거나 형식이 틀리면 꺼진 채다.

| 키 | 값 |
|---|---|
| `DaylogCommunityURL` | `https://<프로젝트>.supabase.co` |
| `DaylogCommunityAnonKey` | 공개(anon / publishable) 키. `service_role`·`sb_secret_` 키는 거절된다 |
| `DaylogCommunityAppleSignIn` | Apple 로그인 권한을 서명에 넣은 뒤 `true` |

### 화면 검증용 (Debug 빌드)

`-DaylogDebugCommunity mock`(비로그인) / `mock-signed-in` / `mock-offline`을 실행 인자로 주면 메모리 안의 시험용 서버에 붙는다. 화면에 "시험용 서버" 표시가 뜬다. 실제 서버에는 닿지 않는다.

## 승인이 필요한 일 (하지 않았다)

1. **Supabase 프로젝트 만들기.** 지금 계정에는 Daylog용 프로젝트가 없다(다른 앱용 6개, 그중 2개가 활성). 제안: 조직 `gyu-bin's Org`에 `daylog` 프로젝트, 지역 `ap-northeast-2`(서울).
   무료 요금제는 활성 프로젝트가 2개까지라, 지금 활성인 2개 중 하나를 멈추거나 요금제를 올려야 할 수 있다.
2. **마이그레이션 적용과 검사 스크립트 실행.** 로컬 Supabase(Docker 필요)나 새 프로젝트에서 먼저 돌린다.
3. **Supabase Auth에 Apple 제공자 설정**(앱의 번들 ID를 Client ID로 등록).
4. **앱 서명에 Sign in with Apple 권한 추가**(App ID 설정과 프로비저닝 프로파일, entitlements 변경).
5. **macOS 샌드박스에 네트워크 클라이언트 권한 추가**(`com.apple.security.network.client`). 지금 macOS 앱은 네트워크 권한 없이 Sparkle의 별도 서비스로만 업데이트를 받는다.
6. **앱 설정에 서버 주소와 공개 키 넣기**, 그 뒤 실기기에서 로그인·게시·신고를 실제 서버로 확인.
7. **운영 준비**: 관리자 계정 지정, 신고 처리 절차, 이용 약관·개인정보 처리방침(사용자 생성 콘텐츠는 App Store 심사 지침 1.2의 신고·차단·연락처 요건이 있다).
