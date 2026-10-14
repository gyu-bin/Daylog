# 모바일 UI 설정 (iPhone·iPad OTA Remote Config)

앱을 다시 설치하지 않고, **앱에 미리 만들어 둔 표시 설정**을 원격에서 바꾸는 장치다. iPhone·iPad 전용이고 macOS에는 없다.

- 바꿀 수 있는 것: 대시보드의 기본 카드 배치·간격·여백, 허용된 강조 색, 카드 스타일, 정해진 문구 몇 개, 정해진 표시 두 가지.
- 바꿀 수 없는 것: 화면 코드, 새 기능, 기록(SwiftData), 동기화(CloudKit), 알림 권한, 식사 표시·휴가·테마 같은 개인 설정, 설정을 받는 주소.
- 설정 파일은 JSON 하나다. 코드나 스크립트를 내려받아 실행하지 않는다.

## 지금 상태 (2026-10-12)

| 항목 | 상태 |
|---|---|
| 앱 | iOS 1.0.0 (5)부터 들어 있다. TestFlight에 올림(2026-10-12 21:02) |
| Production | **configVersion 2 게시됨**(2026-10-12). 내용은 앱의 내장 기본값과 같다(화면이 달라지지 않는다) |
| Development | 아직 게시하지 않음(Debug 빌드는 내장 기본값) |
| 저장소의 파일 | `configVersion 2`. 게시된 것과 같다 |
| 관리 스크립트 | `Tools/mobile-config.sh` |

### 게시 기록

| 날짜 | 채널 | configVersion | 내용 |
|---|---|---|---|
| 2026-10-12 | Production | 1 | 첫 게시. 내장 기본값과 같은 설정(카드 배치·간격·민트·옅은 테두리·기본 문구). 커밋 `689a020`의 `RemoteConfig/mobile-ui.json`, SHA-256 `c2925ca9…f0024` |

| 2026-10-12 | Production | 2 | `splash.duration: 1.5` 칸 추가(스플래시 재생 시간, 빌드 6의 기본값과 같은 값). 커밋 `54ea52f`의 파일, SHA-256 `0ecb56dc…25328`. 빌드 5는 이 칸을 무시한다 |

게시 뒤 확인한 것(v1 기준, v2도 같은 항목을 확인했다): 공개 주소에서 받은 파일이 저장소의 파일과 바이트까지 같다. 조건부 요청(ETag)에 304가 온다. 릴리스 `mobile-config`는 사전 출시이고 최신 릴리스는 그대로 `v1.5.2`다. Mac의 appcast와 v1.5.2의 자산(체크섬)은 바뀌지 않았다.
Release 빌드(1.0.0 (5), 시뮬레이터)에서 [UI 설정 새로고침]을 누르자 실제 주소에서 "버전 1"을 받아 적용했고, 적용 전후의 오늘 화면은 픽셀까지 같았다.

### 실기기에서 확인할 것 (TestFlight 빌드 5)

1. TestFlight에서 1.0.0 (5)로 업데이트한다. 기록과 카드 배치가 그대로인지 본다.
2. 설정 → 정보에 "UI 설정"이 "앱 기본값"으로 보인다(처음 열었을 때는 곧 "버전 1"로 바뀔 수 있다).
3. [UI 설정 새로고침]을 누른다 → "버전 1", "지금 쓰는 설정이 최신이에요." 또는 "버전 1을 받아 적용했어요."가 나온다. 오늘 화면은 달라지지 않아야 한다.
4. 비행기 모드에서 앱을 다시 연다 → 평소대로 열리고 "버전 1"이 유지된다. 새로고침은 "확인하지 못했어요"로 남는다.
5. 카드 하나를 숨기거나 옮긴 뒤 새로고침한다 → 배치가 그대로다.
6. iPhone ↔ iPad ↔ Mac 동기화가 평소대로 되는지 본다(이 기능은 동기화와 무관하지만, 새 빌드라 함께 확인한다).

### 되돌리는 명령

```bash
Tools/mobile-config.sh status                               # 지금 게시된 버전
Tools/mobile-config.sh rollback --to 1 --confirm <새 번호>   # v2 이후를 게시했다가 v1의 내용으로 되돌릴 때
```

지금 게시된 것은 v2이고, v1의 사본도 남아 있다. `rollback --to 1 --confirm 3`이면 v1의 내용(스플래시 칸 없음 = 기본 1.5초)을 v3으로 다시 게시한다. 두 버전 모두 내장 기본값과 같은 화면이다.

## 구조

```
RemoteConfig/mobile-ui.json ──(Tools/mobile-config.sh publish)──▶ GitHub 릴리스 mobile-config 의 mobile-ui.json
                                                                        │ HTTPS, ETag
                                                                        ▼
                    MobileUIConfigStore ── 검사 ──▶ 캐시(Application Support/MobileConfig) ──▶ 화면(환경값 mobileUI)
```

- 파일을 고쳐 `git push` 하는 것만으로는 아무에게도 적용되지 않는다. `publish`가 릴리스 자산을 바꿔야 적용된다.
- 별도 서버는 없다. GitHub 릴리스 자산의 고정 주소를 쓴다.
- 설정용 릴리스는 "사전 출시"로 둔다. Mac 앱의 업데이트 피드(`…/releases/latest/…`)가 보는 최신 릴리스가 되지 않게 하기 위해서다(`publish`가 게시 뒤에 확인한다).

### 주소와 환경 분리

| 채널 | 파일 | 주소 | 누가 보나 |
|---|---|---|---|
| Production | `RemoteConfig/mobile-ui.json` | `https://github.com/gyu-bin/Daylog/releases/download/mobile-config/mobile-ui.json` | Release 빌드(TestFlight·App Store) |
| Development | `RemoteConfig/mobile-ui.dev.json` | `https://github.com/gyu-bin/Daylog/releases/download/mobile-config-dev/mobile-ui.json` | Debug 빌드 |

주소는 앱에 고정돼 있다(`MobileUIConfigChannel`). 원격 설정이나 사용자 설정으로 바꿀 수 없다.
Debug 빌드에서만 `-DaylogDebugConfigURL http://127.0.0.1:<포트>/mobile-ui.json`으로 이 Mac의 시험 서버를 볼 수 있다.

## 설정 형식 (schemaVersion 1)

```json
{
  "schemaVersion": 1,
  "configVersion": 2,
  "minimumSupportedAppBuild": 5,
  "updatedAt": "2026-10-12T12:00:00Z",
  "dashboard": {
    "defaultCardOrder": ["achievement", "nextRoutine", "routines", "meals", "recentDays", "tomorrow", "vacation", "summary", "calendar", "trend", "routineRates"],
    "defaultHiddenCards": ["summary", "calendar", "trend", "routineRates"],
    "layoutStyle": "standard",
    "cardSpacing": 16,
    "cardPadding": 18
  },
  "appearance": { "accent": "mint", "cardStyle": "bordered" },
  "splash": { "duration": 1.5 },
  "content": {
    "onboarding": { "introTitle": "…", "notificationTitle": "…", "notificationBody": "…" },
    "dashboard": { "greeting": "…" },
    "emptyStates": { "noRoutinesToday": "…", "noRoutinesYet": "…" }
  },
  "features": { "greetingIcon": true, "onboardingNotificationGuide": true }
}
```

머리말 네 칸은 필수다. 나머지는 모두 선택이고, 적지 않은 칸은 앱의 내장 기본값을 쓴다.

| 칸 | 뜻 | 허용값 |
|---|---|---|
| `schemaVersion` | 형식 번호. 앱이 모르는 번호면 파일 전체를 거부한다 | `1` |
| `configVersion` | 설정의 버전. 게시할 때마다 올린다 | 1 이상의 정수 |
| `minimumSupportedAppBuild` | 이 설정을 써도 되는 가장 낮은 iOS 빌드 번호. 그보다 낮은 앱은 거부한다 | 1 이상, 지금 iOS 빌드 번호 이하 |
| `updatedAt` | 게시 시각(UTC) | `2026-10-12T12:00:00Z` 모양 |
| `dashboard.defaultCardOrder` | iPhone의 기본 카드 순서 | 카드 11개를 한 번씩. 나중에 생긴 `weeklyGrowth`는 선택(적지 않으면 앱이 달성 현황 뒤에 둔다) |
| `dashboard.defaultHiddenCards` | 처음에 숨겨 두는 카드(iPhone·iPad) | 아는 카드, `routines` 제외 |
| `dashboard.layoutStyle` | 간격 묶음 | `standard`(16/18), `compact`(12/14), `airy`(20/20) |
| `dashboard.cardSpacing` | 카드 사이 간격. 적으면 묶음보다 우선 | 8~24 |
| `dashboard.cardPadding` | 카드 안쪽 여백(여백을 따로 정하지 않은 카드) | 10~24 |
| `appearance.accent` | 강조 색 | `mint`, `green`, `blue`, `purple`, `coral`, `orange` |
| `appearance.cardStyle` | 카드 스타일 | `bordered`(옅은 테두리), `soft`(옅은 그림자), `flat`(평평) |
| `splash.duration` | 스플래시 재생 시간(초). 적지 않으면 1.5 | 0.5~2.0 |
| `content.*` | 문구. 한 줄, 줄바꿈·제어 문자 없음 | 제목류 24자, 설명류 40자 |
| `features.greetingIcon` | 오늘 화면 인사말 옆의 해 아이콘 | `true`/`false` |
| `features.onboardingNotificationGuide` | 시작 안내 3단계의 알림 안내 | `true`/`false` |

카드 이름: `summary`, `nextRoutine`, `vacation`, `routines`, `meals`, `achievement`, `recentDays`, `tomorrow`, `calendar`, `trend`, `routineRates`.

바꿀 수 있는 문구는 여섯 개뿐이다: 시작 안내의 첫 제목과 알림 안내의 제목·설명, 오늘 화면의 인사말, 루틴 카드의 빈 상태 둘("오늘은 예정된 루틴이 없어요.", "아직 등록된 루틴이 없어요."). 글자 그대로 보여 주고 서식으로 해석하지 않는다.

### 적용 범위

- 강조 색: iPhone·iPad의 단추·스위치와 `Theme.accent`를 쓰는 곳. **앱을 다시 열 때 바뀐다**(실행 중에는 바꾸지 않는다). 탭·사이드바의 메뉴 색과 "오늘 달성률"의 민트 같은 뜻이 정해진 색은 그대로다.
- 카드 스타일: `Card`로 그린 카드와 다음 루틴 카드, 휴가 카드(휴가 중이 아닐 때).
- 간격·여백: 대시보드의 카드 사이 간격, 그리고 여백을 따로 정하지 않은 카드의 안쪽 여백.
- 기본 카드 순서는 iPhone(한 열)에만, 숨김 기본값은 iPhone·iPad에 쓴다.

### 스플래시 시간 바꾸기

앱을 열 때 나오는 스플래시의 길이를 `splash.duration`(초)으로 정한다. iOS 빌드 6부터 읽는다(빌드 5는 이 칸을 무시하고 약 1.1초로 재생한다).

```json
"splash": { "duration": 1.2 }
```

- 기본값은 1.5초, 허용 범위는 0.5~2.0초다. 칸이 없거나 범위를 벗어나면 1.5초로 재생한다.
- 장면의 순서와 비율은 그대로 두고 전체 길이만 늘이거나 줄인다(`SplashTimeline.make(reduceMotion:duration:)`). 동작 줄이기에서는 같은 비율로 더 짧다.
- 스플래시는 앱이 켜지는 순간에 재생되므로, 그때 **이미 받아 둔 설정**(캐시)의 값을 쓴다. 새로 게시한 값은 앱이 한 번 받아 둔 뒤 **그다음 실행부터** 적용된다.
- 바꾸는 절차는 다른 칸과 같다: 값을 고치고 `configVersion`을 올린 뒤 `validate` → `preview` → 커밋·push → (승인 뒤) `publish`.

## 우선순위

1. 사용자가 직접 정한 설정
2. 유효한 원격 설정
3. 앱의 내장 기본값

- 카드 배치: 사용자가 카드를 옮기거나 숨기거나 다시 보이게 하면 그 배치를 사용자의 것으로 기억한다(`DevicePreferences.isLayoutCustomized`). 그 뒤로 원격 기본 배치는 그 기기의 배치를 바꾸지 않는다.
  [기본 배치 복원]을 누르면 지금의 기본값(원격이 준 것)으로 돌아가고, 다시 기본값을 따른다.
- 이 기능이 생기기 전에 저장된 배치는, 내장 기본 배치와 다르면 사용자가 바꾼 것으로 본다.
- 테마(라이트/다크), 식사 표시, 알림, 휴가, 한 주의 시작 같은 개인 설정은 원격 설정에 칸이 없다. 바꿀 방법 자체가 없다.

## 받기와 적용

- 확인 시점: 앱을 열 때, 백그라운드에서 돌아올 때(둘 다 마지막 확인에서 1시간이 지났을 때만), 그리고 설정 → 정보의 [UI 설정 새로고침]을 눌렀을 때(바로).
- `If-None-Match`(ETag)로 묻는다. 바뀌지 않았으면 본문을 받지 않는다(304).
- 받은 뒤: 크기(64KB) → JSON → `schemaVersion` → 머리말 값 → `minimumSupportedAppBuild` → 값 범위·허용 목록 → 캐시에 저장 → 적용.
- 적용 시점
  - 스스로 확인해 받은 설정: 저장만 해 두고 **다음에 앱을 열거나 돌아올 때** 적용한다(쓰는 도중에 화면이 움직이지 않게).
  - [UI 설정 새로고침]으로 받은 설정: 바로 적용한다.
  - 설정을 한 번도 받은 적 없는 설치의 첫 설정: 바로 적용한다(새 사용자가 처음부터 그 기본값으로 시작하게).
  - 강조 색은 어느 경우든 앱을 다시 열 때 바뀐다.
- 실패했을 때
  - 네트워크가 없거나 받지 못함: 쓰던 설정을 그대로 둔다. 앱은 평소대로 동작한다.
  - 잘못된 JSON, 모르는 형식 번호, 더 새 앱용 설정, 너무 큰 파일: 거부하고 쓰던 설정을 그대로 둔다. 거부한 파일의 ETag는 기억하지 않는다.
  - 형식은 맞는데 일부 칸이 허용 범위 밖: 그 칸만 내장 기본값으로 둔다. 모르는 칸과 모르는 기능 표시는 무시한다.
- 캐시: 마지막 유효 설정을 `Application Support/MobileConfig/`에 둔다. 앱을 다시 열 때와 오프라인일 때 이것을 쓴다. 다른 주소에서 받은 캐시는 쓰지 않는다.

## 관리 명령

```bash
Tools/mobile-config.sh validate            # 형식·허용값·버전·앱 호환성 검사(엄격: 틀린 칸이 하나라도 있으면 실패)
Tools/mobile-config.sh preview             # 지금 게시된 설정과의 차이
Tools/mobile-config.sh status              # 지금 게시된 버전과 주소
Tools/mobile-config.sh publish --confirm <configVersion>
Tools/mobile-config.sh rollback --to <configVersion> --confirm <새 configVersion>
```

모든 명령에 `--dev`를 붙이면 Development 채널을 다룬다.

### 게시 절차

1. `RemoteConfig/mobile-ui.json`을 고치고 `configVersion`을 올린다(`updatedAt`도).
2. `Tools/mobile-config.sh validate` → `preview`로 차이를 확인한다.
3. 커밋·push한다(Production은 커밋·push된 파일만 올린다).
4. **사용자 승인을 받은 뒤** `Tools/mobile-config.sh publish --confirm <configVersion>`.
   게시 뒤 스크립트가 공개 주소의 내용이 같은지, 최신 앱 릴리스가 그대로인지 확인한다.
5. 사용자의 앱은 다음에 열릴 때(확인 간격 1시간) 받아서, 그다음 실행부터 쓴다. 바로 보려면 설정 → 정보 → [UI 설정 새로고침].

`publish`와 `rollback`은 실제 사용자의 화면을 바꾼다. 승인 없이 실행하지 않는다. `--confirm`에 게시할 버전을 한 번 더 적어야 실행된다.

### 되돌리기

- 게시할 때마다 `mobile-ui-v<버전>.json` 사본을 같은 릴리스에 남긴다.
- `Tools/mobile-config.sh rollback --to 3 --confirm 6`: v3의 내용을 새 번호(v6)로 다시 게시한다. 번호는 늘 올라간다.
  `RemoteConfig/mobile-ui.json`도 그 내용으로 바뀌므로 커밋·push해 Git에 남긴다.
- 내장 기본값으로 돌아가려면 선택 칸을 모두 뺀 설정(머리말만)을 게시한다.
- 잘못 게시된 설정이 앱을 못 쓰게 만들 수는 없다: 설정은 표시 값만 바꾸고, 값은 허용 범위 안으로 제한되며, 읽을 수 없는 파일은 쓰지 않는다.

## 설정 화면

iPhone·iPad의 설정 → 정보에 "UI 설정" 줄이 있다: 지금 쓰는 설정의 버전("앱 기본값" 또는 "버전 N"), 마지막 확인 시각, 마지막 결과, [UI 설정 새로고침].
앱 버전 업데이트가 아니라는 설명을 함께 적었다. macOS 설정에는 없다.

## 구현 위치

- `Daylog/Services/MobileConfig/MobileUIConfig.swift` — 파일 형식, 검사, 허용 목록(`MobileUISettings`).
- `Daylog/Services/MobileConfig/MobileUIConfigStore.swift` — 주소, 받기, 캐시, 적용 시점.
- `Daylog/Services/MobileConfig/MobileUIEnvironment.swift` — 화면에 내려보내는 환경값, 카드 스타일.
- `Daylog/Models/DevicePreferences.swift` — 사용자 배치 우선(`applyRemoteDefaults`).
- `Daylog/Views/Settings/MobileUIConfigRow.swift` — 설정 화면의 줄.
- `DaylogTests/MobileUIConfigTests.swift` — 형식·캐시·거부·롤백·우선순위. 저장소의 설정 파일이 앱의 검사를 통과하고 내장 기본값과 같은지도 본다.

## 검증 (2026-10-12, 시뮬레이터 + 이 Mac의 시험 서버)

Debug 빌드를 `-DaylogDebugConfigURL http://127.0.0.1:8766/mobile-ui.json`으로 띄우고, 서버의 파일을 바꿔 가며 확인했다. 실제 주소에는 아무것도 올리지 않았다.

| 흐름 | 결과 |
|---|---|
| 기존 설정(v1)으로 실행 | 처음 받은 v1을 바로 적용, 화면은 내장 기본값과 같음 |
| 원격 설정 변경(v2) → 같은 프로세스에서 새로고침 | 인사말·해 아이콘·카드 순서·간격·카드 스타일이 바로 바뀜(재설치·재실행 없음) |
| 앱을 다시 실행 | v2 유지, 강조 색(파랑)이 이때 반영됨 |
| 서버를 끄고 다시 실행 | v2 유지. 새로고침은 "확인하지 못함"으로 남고 그대로 |
| 잘못된 JSON / schemaVersion 2 / 더 새 앱용 / 80KB 파일 | 모두 거부, v2 유지 |
| 값이 범위 밖인 파일 | 틀린 칸만 내장 기본값 |
| 되돌리기(v1의 내용을 v4로 게시) | 기본값으로 복귀(카드 배치 포함) |
| 사용자가 카드를 숨긴 뒤 새 기본 배치(v5) 게시 | 배치는 사용자의 것 그대로, 문구·간격만 바뀜 |
| 스스로 확인(1시간 간격) 중 받은 v6 | 받아 두기만 하고, 다음 실행 때 적용 |
| iPad | 설정 줄과 대시보드에 같은 설정 반영 |

하지 못한 것: `rollback`의 실제 실행(이전 버전이 아직 없다), 실기기, 백그라운드에서 돌아올 때의 확인을 화면으로 보는 것(규칙은 단위 테스트), 루틴·식사·휴가·알림·위젯의 회귀는 전체 테스트와 시뮬레이터 실행으로만 확인.
`publish`의 실제 실행과 실제 주소에서 받기, Release 빌드에서의 동작은 Production v1 게시 때 확인했다(위 "게시 기록").
