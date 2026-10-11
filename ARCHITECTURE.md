# Daylog 설계

macOS 14+ / iOS 17+ / SwiftUI / SwiftData / Swift Charts / CloudKit. 자체 서버 없음. macOS 업데이트 기반에만 Sparkle 2.10.0을 사용한다(배포 활성화 전).

장기 개발: [로드맵](docs/DEVELOPMENT_PLAN.md) · [Phase 3 명세](docs/PHASE3.md) · [현재 진행](docs/PROGRESS.md).

## 엔티티

| 엔티티 | 핵심 필드 | 생성 | 수정 | 삭제 |
|---|---|---|---|---|
| `RoutineGroup` | id, title, colorKey, order, isArchived, deletedAt, createdAt, updatedAt | 사용자(또는 기존 항목 이전 시 "기본 루틴") | 사용자 | 삭제 시각만 기록(v1.3.1) |
| `RoutineItem` | id, title, note, timeLabel, weekdays, order, isArchived, deletedAt, updatedAt, groupID | 사용자 | 사용자 | 삭제 시각만 기록(v1.3.1) |
| `RoutineRevision` | routineID, effectiveFromKey, 당시 title·timeLabel·weekdays·isArchived·order·그룹(ID·이름·색·순서), updatedAt | 루틴 변경 시 자동 | 같은 날(또는 더 늦은 날짜의 이력이 있으면 그 이력) 재변경 시 덮어씀 | 없음 |
| `DayRecord` | dateKey, checks, 식사 4종, mealMemo, tomorrowTask, activityAt, syncID, mergeState | 날짜를 처음 열 때 | 사용자, 병합 | 없음 |
| `DayCheck` | routineID, title, timeLabel, note, order, isDone, isHidden, syncID, 그날의 그룹(ID·이름·색·순서) | 기록 생성·오늘 동기화·병합 | 오늘만 동기화 | 없음(대상에서 빠지면 숨김) |
| `FieldEdit` | dateKey, field, deviceID, value, editedAt, seenState | 텍스트 칸을 고쳐 저장할 때 | 그 기기만 | 없음 |
| `AppSettings` | achieveThreshold, firstRoutineDate, updatedAt, syncID | 최초 필요 시 | 사용자, 병합 | 없음 |

v1.2부터 앱은 어떤 기록도 지우지 않는다. 동기화 환경에서는 "한 기기가 지운 것을 다른 기기가 아직 쓰고 있는" 경우를
되돌릴 방법이 없기 때문이다. v1.3.1의 "삭제"도 레코드를 지우지 않고 `deletedAt`만 남긴다(아래 "삭제" 절).

관계: `DayRecord 1:N DayCheck` (cascade). `RoutineItem`과 `DayCheck`/`RoutineRevision`은 관계가 아니라
`routineID` 값으로만 연결한다. 루틴이 바뀌어도 과거 스냅샷이 따라 바뀌지 않게 하기 위함이다.

## 진실의 원천

| 질문 | 원천 |
|---|---|
| 그날 무엇을 했는가 | `DayRecord.checks` (스냅샷) |
| 기록이 없는 날 무엇이 예정되어 있었는가 | `RoutineRevision` (`ScheduleResolver`) |
| 그날을 실제로 기록했는가 | `DayRecord.activityAt != nil` |
| 오늘이 며칠인가 | `AppStore.today` (`Day.today()`), 자정·활성화·깨어남·시간대 변경 시 갱신 |

## 상태 소유권

| 데이터 | 위치 | 이유 |
|---|---|---|
| 영속 데이터 | SwiftData `mainContext` 하나 | 모든 쓰기를 메인 액터로 직렬화한다. 한 기기 안에서는 날짜별 중복이 생기지 않고, 기기 간 중복은 `SyncReconciler`가 합친다 |
| 선택 날짜·오늘·통계 결과 | `AppStore` (@Observable) | 대시보드와 통계 화면이 같은 계산 결과를 공유한다 |
| 입력 초안(빠른 추가, 루틴 편집 중 텍스트) | 뷰 `@State` | 확정 전에는 저장하지 않는다 |

## 결정 기록

| 결정 | 대안 | 선택 이유 |
|---|---|---|
| 날짜를 `Day`(연·월·일) 값 타입으로 다루고 연산은 UTC 달력으로 수행 | `Date` + `Calendar.current` | 서머타임·시간대 변경에도 `dateKey`가 흔들리지 않는다 |
| `DayRecord.date`, `firstRoutineDate`는 해당 날짜의 UTC 정오 | 로컬 자정 | 시간대가 바뀌어도 같은 달력 날짜로 복원된다 |
| 요일은 `weekdayMask: Int`로 저장, `weekdays: [Int]`는 계산 속성 | `[Int]` 직접 저장 | 스토어 표현이 단순하고 이력 비교가 쉽다 |
| 이력은 (routineID, 적용 시작일)당 1건, 같은 날 변경은 덮어씀 | 변경마다 1건 | "하루의 최종 유효 상태"가 자동으로 일관된다. 종료일은 다음 이력의 시작일이 경계다 |
| 미기록 판정은 `activityAt` | `DayRecord` 존재 여부 | 과거 날짜를 열어 자동 생성된 기록이 정상 기록일로 바뀌지 않는다 |
| 통계는 `StatsService` → `StatsCalculator`(순수 함수) 한 경로 | 뷰별 계산 | 카드·표·캘린더·차트가 같은 `DayOutcome`을 쓴다 |
| 루틴 변경 = 정의 + 이력 + 오늘 기록을 한 번의 `save()`로 | 단계별 저장 | 중간에 종료돼도 서로 모순된 상태가 남지 않는다 |
| 단위 테스트는 앱을 호스트로 실행하되 앱은 테스트 중 in-memory 스토어 사용 | 별도 프레임워크 분리 | 타깃 구조를 단순하게 유지하면서 실제 저장소를 건드리지 않는다 |
| App Sandbox 켬, 네트워크 권한 없음 | 샌드박스 끔 | 저장소가 앱 컨테이너에 격리된다. iCloud 통신은 시스템이 대신하므로 앱 자체에는 네트워크 권한이 필요 없다(실측) |

| 루틴 관리 화면은 `List`가 아니라 `ScrollView` + 직접 구현한 끌어다 놓기 | `List` + `onMove` | macOS `List` 행 안의 입력 칸은 첫 클릭이 행 선택으로 처리돼 바로 편집되지 않았다(실행 검증에서 확인) |
| 식사 입력 칸은 `TextField(axis: .vertical)` + `fixedSize(vertical:)` | `TextEditor` | Enter로 다음 칸 이동이 가능하고, `fixedSize`가 없으면 macOS에서 긴 내용이 한 줄에서 잘린다(실행 검증에서 확인) |

## 가정 (명세에 없어 기본값으로 정한 것)

- 달성 여부는 화면에 보이는 반올림된 백분율이 기준값 이상인지로 판정한다.
- 체크·식사·메모·내일 할 일 중 무엇이든 사용자가 입력하면 그날은 기록일이다.
- 추천 칩은 첫 루틴을 만든 당일까지만 보인다.
- 날짜가 바뀌는 순간 텍스트를 입력 중이면 선택 날짜를 유지한다(입력 중인 칸이 비워지지 않게).
- 루틴 이름은 60자로 자른다.

## 경계

- `Views` → `AppStore` → `Services` → `Models`. 뷰는 서비스나 `ModelContext`를 직접 호출하지 않는다.
- `Services`의 순수 계산(`Achievement`, `StatsCalculator`, `ScheduleResolver`)은 SwiftData에 의존하지 않는다.

## 범위 제외

명세 20절 그대로: iOS, iCloud, 로그인, 서버, 알림, 메뉴바, 위젯, 체중, 칼로리, 음식 검색, 사진,
가져오기/내보내기, 공유, 결제, AI, 분석 SDK, 서명·공증.

## iCloud 동기화 (v1.2)

SwiftData + CloudKit(Private Database). Bundle ID `com.mungyubin.daylog`, 컨테이너 `iCloud.com.mungyubin.daylog`.

### 켜지는 조건

앱 서명에 iCloud(CloudKit) 권한이 있으면 켜진다(`CloudSyncConfiguration`). 컨테이너 이름은 코드에 없고
`Config/Daylog.entitlements`에만 있다. 권한이 없는 빌드와 단위 테스트는 로컬 전용이다.

### 저장소 형식과 기존 기록

| 항목 | 내용 |
|---|---|
| v1.1 형식 | `DaylogSchemaV1`에 동결. 수정 금지 |
| v1.2 형식 | `DaylogSchemaV2`에 동결. 고유 제약 제거, 모든 속성 기본값, `checks` optional, 새 속성·`FieldEdit` 추가 |
| v1.3 형식 | `DaylogSchemaV3`에 동결. `RoutineGroup` 추가, 항목·체크·이력에 그룹 속성 추가. 전부 추가뿐 |
| v1.3.1 형식 | `DaylogSchemaV4`(현재). `RoutineItem.deletedAt`, `RoutineGroup.deletedAt`(둘 다 optional) 추가뿐 |
| 옮기는 방법 | 경량 마이그레이션(`DaylogMigrationPlan`) |
| 열기 전 | 형식이 바뀌거나 iCloud에 처음 연결할 때 `Backups/<이름>-<사유>-<시각>/`에 백업을 만들고 무결성과 기록 수를 검증 |
| 순서 | 백업 → iCloud 없이 로컬에서만 옮김 → 기록 수 대조·동기화 식별자 채움 → 그다음 iCloud 연결 |
| 실패 시 | 백업으로 되돌리고 오류 화면에 백업 위치 표시. 빈 저장소로 대체하지 않음 |

`StoreLock`: 저장소 하나는 한 번에 한 프로세스만 연다(`<이름>.store.lock`에 `flock`). 형식이 다른 두 버전이 같은 저장소에
동시에 쓰면 기록이 깨질 수 있어서, 두 번째 프로세스는 백업·변환 전에 오류 화면에서 멈춘다.

저장소 옆의 `<이름>.store.info.json`에 마지막으로 연 형식, iCloud 연결 여부, 기기 식별자를 적는다(동기화되지 않음).

### iCloud가 실제로 하는 일 (2026-10-10 실측, 한 Mac에서 저장소 2개로 두 기기를 재현)

| 상황 | 결과 |
|---|---|
| 한 기기에서 수정 | 앱이 활성 상태면 1~5초 안에 올라가고, 다른 쪽은 실행·활성화 때 1~3초 안에 받음 |
| 앱이 비활성(백그라운드) 상태에서 수정 | 시스템이 보내기를 미룸(90초 이상). 다음 활성화·실행 때 올라감 |
| 앱이 켜진 채 비활성 상태일 때 다른 쪽이 수정 | 150초 동안 받지 못함. 앱을 다시 활성화하면 3초 안에 받고 재실행 없이 화면 값이 갱신됨 |
| 앱이 맨 앞에 떠 있는 동안 푸시로 즉시 받기 | **미검증**. 같은 Mac의 두 인스턴스로는 확인할 수 없다(CloudKit은 변경을 만든 기기에는 알림을 보내지 않는다). 원격 알림 등록(`AppDelegate`)은 넣어 두었다 |
| 두 기기가 같은 기록의 **다른 칸**을 동시에 수정 | 둘 다 보존됨 |
| 두 기기가 **같은 칸**을 동시에 수정 | 나중에 동기화한 기기의 값으로 덮어쓰고 다른 값은 흔적 없이 사라짐 → `FieldEdit`으로 보완 |
| 두 기기가 같은 날짜를 각자 생성 | 같은 `dateKey`의 기록이 둘 생김 → `SyncReconciler`로 보완 |

### 병합 규칙 (`SyncReconciler`)

- 실행 시점: 앱 시작, 저장소 변경 알림(`NSPersistentStoreRemoteChange`), 앱 활성화. 자체 폴링 없음.
- 아무것도 지우지 않고, 다른 기록은 고치지 않고, 대표 기록에만 쓴다.
- 대표 기록: 먼저 만들어진 것, 같으면 `syncID` 순. 어느 기기에서든 같은 것이 뽑힌다.
- 체크: 루틴당 대표 하나(`checkList`). 다른 쪽의 완료 표시를 대표로 가져온다.
- 텍스트: 한쪽이 비었거나 포함 관계면 그대로, 서로 다르면 둘 다 남기고 설정 화면에 안내를 쌓는다.
- `mergeState`(장부): 이미 가져온 내용을 기억해서, 가져온 뒤 사용자가 고치거나 지운 것이 되살아나지 않게 한다.
- `FieldEdit`: 기기마다 "이 칸에 마지막으로 쓴 값"과 "그때 보고 있던 다른 기기의 편집 시각"을 남긴다.
  상대 편집을 보고 쓴 것이면 순차 편집(나중 값), 못 보고 쓴 것이면 동시 편집(둘 다 보존)이다.
- 설정: 기준값은 가장 나중에 바꾼 값, 통계 시작일은 가장 이른 날.
- 루틴·기준값·체크의 같은 항목 동시 수정은 iCloud 기본 동작(나중에 동기화한 쪽)이 그대로 적용된다.

### 두 Mac에서 쓰기

개발용 서명 빌드는 계정에 등록된 Mac에서만 실행된다. 다른 Mac에서는 이 프로젝트를 Xcode로 열어 한 번 빌드하면
Xcode가 그 Mac을 등록한다. 두 Mac 모두 개발용 서명이면 CloudKit **Development** 환경을 쓴다.
Developer ID로 배포하려면 CloudKit Console에서 스키마를 Production에 배포해야 한다.

### 실제 iCloud로 다시 검증해야 할 때

v1.2에서는 한 Mac에서 저장소 2개를 실제 iCloud에 붙여 두 기기를 재현했다. 지금은 실제 기록이 같은 iCloud 영역에 있으므로
그 방법을 쓰지 않는다. 검증용 저장소(`-DaylogStoreName`)는 항상 로컬 전용으로 열리고, iCloud의 데이터를 지우는 디버그 명령은 제거했다.
실제 iCloud 검증이 다시 필요하면 검증 전용 컨테이너를 따로 만들어야 한다(컨테이너는 계정에서 삭제할 수 없으므로 승인 후에만).

## 루틴 그룹 (v1.3)

### 구조

- `RoutineGroup`과 `RoutineItem`은 관계가 아니라 `RoutineItem.groupID` 값으로 연결한다.
- `groupID`가 nil인 항목(v1.2까지 만든 항목)은 **고정된 ID**(`RoutineGroup.defaultID`)의 "기본 루틴" 그룹에 속한 것으로 읽는다.
  기존 항목·체크·이력 레코드는 고쳐 쓰지 않는다. "기본 루틴" 그룹 레코드는 그런 항목이 있을 때만 만든다.
- ID가 고정이라 두 Mac이 각자 "기본 루틴"을 만들어도 같은 그룹이다. 같은 ID의 그룹이 둘이면 나중에 수정된 쪽 하나만 쓴다(지우지 않는다).
- 그룹 보관: 항목 자체는 그대로 두고 "유효 상태"만 보관으로 본다(`RoutineState.isArchived = 항목 보관 || 그룹 보관`). 복원하면 그대로 돌아온다.

### 과거 보존

- `DayCheck`와 `RoutineRevision`에 그날/그 시점의 그룹 ID·이름·색·순서를 복사해 둔다(`GroupSnapshot`).
- 그룹을 바꾸면(이름·색·순서·보관) 그 그룹에 속한 항목마다 이력을 남긴다. 그래서 기록이 없던 과거 날짜를 나중에 열어도
  당시의 그룹 모습으로 스냅샷이 만들어진다.
- 그룹 정보 없이 저장된 v1.2까지의 체크·이력은 `GroupSnapshot.legacy`("기본 루틴", 초록)로 읽는다.
- 오늘 기록만 현재 그룹 정의로 동기화한다(`RoutineService.syncTodayRecord`).

### 달성률

- 하루 전체: 항목 수 기준(완료 항목 수 / 전체 항목 수). 그룹 평균이 아니다. 그룹을 추가해도 값이 바뀌지 않는다.
- 그룹별(오늘): `AppStore.checkSections`. 그룹별(30일): `StatsSource.groupTallies` — 기록이 있는 날은 그날의 스냅샷,
  없는 날은 당시 이력의 그룹으로 집계하고, 표시는 현재 그룹의 이름·색으로 한다.

### 색

저장소에는 `GroupColor`의 식별자 문자열만 들어간다. 실제 색(라이트/다크)은 `GroupColor.rgb(isDark:)`가 정하고,
모르는 식별자는 초록으로 보인다. 색만으로 구분하지 않도록 그룹 이름의 첫 글자 배지와 숫자를 함께 표시한다.

## 식사 기록 조회 (v1.3)

- 새 데이터를 만들지 않고 `DayRecord`를 읽는다(`MealHistoryService`).
- **식사 기록일**: 아침·점심·저녁·간식 중 하나라도 내용이 있는 날. 메모만 있는 날은 세지 않지만 목록과 검색에는 나온다.
- **이번 달 기록률**: 분모는 "이번 달 1일"과 "앱을 쓰기 시작한 날" 중 늦은 날부터 오늘까지.
  쓰기 시작한 날 = 첫 루틴을 만든 날과 무엇이든 처음 입력한 날 중 이른 쪽.
- 날짜 범위로만 저장소를 조회하고 한 번의 호출이 읽는 양을 제한한다(`scanLimit`). 전체 기간은 이어 읽기로 넘긴다.
  검색은 입력이 0.25초 멈춘 뒤 한 번 실행한다.
- 같은 날짜의 기록이 둘이면 대표 기록 하나만 보고, 한 번만 센다.

## 삭제 (v1.3.1)

보관과 삭제는 다른 기능이다.

| | 보관 | 삭제 |
|---|---|---|
| 목록 | 빠짐 | 빠짐 |
| 보관함 | 보이고 복원 가능 | 보이지 않음(화면에서 되돌릴 수 없음) |
| 지난 기록·변경 이력·통계 | 그대로 | 그대로("삭제됨" 표시와 함께 통계에 계속 나온다) |
| 저장 | `isArchived = true` | `deletedAt = 시각`. 레코드는 지우지 않는다 |

- 실제 상태는 `RoutineState(routine:group:)` 한 곳에서 정한다: 항목이 보관·삭제됐거나 그룹이 보관·삭제됐으면 "빠진 상태"다.
  그래서 삭제도 보관과 같은 경로(`applyChange` → 그날부터의 `RoutineRevision`, 오늘 기록 동기화)를 탄다.
  오늘 이미 완료한 항목은 오늘 기록에 남고, 완료하지 않은 항목은 오늘 목록에서도 빠진다.
- 그룹 삭제는 한 트랜잭션에서 그룹과 그 안의 항목(보관된 것 포함)에 모두 `deletedAt`을 적는다. 확인창이 항목 수를 알려 준다.
- 동기화: `deletedAt`은 일반 속성이라 CloudKit으로 그대로 전달된다. 같은 ID의 사본이 여럿이면 삭제된 쪽이 이긴다
  (다른 기기의 오래된 사본이 삭제를 되살리지 않게). 물리 삭제가 없으므로 "한쪽이 지운 것을 다른 쪽이 쓰는" 충돌은 생기지 않는다.
- 속성 이름은 `isRemoved`(계산 속성)다. `isDeleted`는 SwiftData가 이미 쓰는 이름이라 피했다.

## 기간 통계와 화면 구조 (v1.3.1)

- `StatsService.period(_:today:)`가 고른 기간(7일·30일·90일·전체)의 `PeriodStats`를 만든다: 날짜별 결과, 평균, 달성한 날/유효한 날,
  그룹·항목 달성률(내림차순), 히트맵용 날짜들(기간과 최근 90일 중 긴 쪽, 최대 53주).
  연속 달성일은 기간과 무관하게 전체 이력 기준(`DashboardStats`)이고, 화면에 그렇게 적는다.
- 히트맵 배치(`HeatmapLayout`)와 칸의 단계(`HeatLevel`)는 뷰 밖의 순수 함수라 테스트한다. 색만으로 구분하지 않도록
  휴식일은 테두리만 그리고, 칸마다 문장으로 된 접근성 이름과 도움말이 있다.
- 항목 편집은 시트(`RoutineEditSheet`)에서 초안(`RoutineDraft`)만 고치다가 [저장]에서 `AppStore.apply(_:to:)` 한 번으로 반영한다.
  [취소]는 아무것도 저장하지 않는다. 목록 화면의 이름·요일 인라인 편집은 없앴다(실수로 바뀌는 일을 막기 위해).
- 루틴 관리 화면의 시트·확인창 상태는 `RoutineEditorState` 하나가 들고, 그룹 카드와 항목 행이 환경으로 받아 쓴다.
- 디자인 규칙은 `Theme`에 모은다: 포인트 색은 민트, 지표별 색(오늘=민트, 7일 평균=파랑, 연속=코랄, 최장=노랑), 식사=코랄,
  끼니별 색·아이콘(`MealKind`), 그룹은 사용자가 고른 색. 큰 숫자는 밝은 배경에서 읽히도록 한 단계 진한 `GroupColor.ink`를 쓴다.
  공통 부품은 `Card`, `CardHeader`, `StatTile`, `EmptyHint`, `StatusBadge`, `ProgressBar`, `ProgressRing`.
- 버튼을 `.accessibilityElement(children: .ignore)`로 감싸면 "누르기" 동작이 사라진다. 버튼에는 이름만 직접 붙이고,
  탭 제스처로 만든 칸에는 `.accessibilityAction`을 함께 단다(히트맵에서 실제로 겪은 문제).

## 체크 상태와 화면 갱신 (v1.3.2)

**v1.3.1의 오류**: 완료한 항목을 다시 눌러도 해제되지 않았다(반대로, 눌러도 체크 표시가 안 생기는 경우도 같은 원인).

**원인**: 대시보드가 체크 상태를 `record.checkList`가 돌려주는 `DayCheck` 객체에서 직접 읽고 그 객체를 관찰했다.
SwiftData는 저장이나 조회가 지나가면 같은 체크를 **다른 객체**로 다시 만들어 줄 수 있다(아무도 붙잡고 있지 않은 모델 객체는
해제된다). 외부 변경 처리(`handleExternalChanges`: 앱 활성화, iCloud 변경 알림 때 실행)가 한 번 지나가면 화면이 관찰하던
객체와 `setDone`이 고치는 객체가 달라져서, 값은 저장되고 통계도 바뀌는데 체크 행에는 알림이 가지 않았다.
화면은 예전 값을 든 채 "이미 그 값"을 다시 써 보냈기 때문에 몇 번을 눌러도 그대로였다.
(추적 결과: 외부 변경 처리 뒤 `withObservationTracking`의 알림이 오지 않고, 객체 식별자가 달랐다.
`CheckToggleTests.screenIsNotifiedAfterExternalChanges`가 이 상황을 재현한다.)

**규칙**
- 화면은 저장소가 붙잡고 있지 않은 모델 객체를 읽거나 관찰하지 않는다. 체크 목록은 `AppStore.checkSections`
  (값 사본, 저장 속성)만 읽는다. `AppStore.checks`(모델 객체)는 값을 바꿀 때만 쓴다.
- 값이 바뀔 수 있는 모든 지점(`reloadStats`, `show`)에서 `refreshChecks()`가 사본을 다시 만든다.
  `setDone`은 값이 같거나 저장에 실패해도 사본을 저장된 값에 맞춘다(화면이 어긋났더라도 한 번 누르면 맞춰진다).
- 통계는 전과 같이 `StatsService` 한 곳에서 계산한다. 체크할 때마다 대시보드 통계·캘린더가 다시 계산되고,
  통계 화면은 `dataVersion`이 바뀌면 다시 조회한다.

**두 Mac에서 같은 체크를 바꿀 때**
- iCloud는 같은 체크를 두 기기가 다르게 바꾸면 나중에 동기화한 쪽으로 덮어쓴다. 한동안 꺼져 있던 Mac이 뒤늦게 올린
  옛 완료 표시가 방금 한 해제를 되돌릴 수 있다.
- 그래서 사용자가 체크를 바꿀 때마다 기기별 편집 기록(`FieldEdit`, 칸 이름 `check:<루틴 ID>`, 값 `1`/`0`)을 남긴다.
  (날짜, 루틴, 기기)마다 하나이고 고쳐 쓴다. 텍스트 칸과 같은 표를 쓰므로 **저장 형식은 바뀌지 않았고**,
  v1.3.1 이하는 모르는 칸 이름이라 이 기록을 무시한다.
- 두 기기 이상의 기록이 있는 체크는 `SyncReconciler.resolveCheckEdits`가 정한다(`CheckEdit.resolve`):
  상대의 변경을 보고 나서 한 변경이 이긴다. 서로 못 본 채 한 변경이면 시각이 늦은 쪽, 시각도 같으면 기기 ID 순.
  도착 순서와 무관하고, 몇 번을 실행해도 결과가 같다.
- 한 기기만 바꾼 체크는 그 기기의 값이 그대로 동기화된다. 편집 기록이 없는 사본(다른 Mac이 따로 만든 같은 날짜의 기록,
  v1.3.1 이하에서 한 체크)을 처음 합칠 때는 전과 같이 완료를 잃지 않는 쪽으로 한 번만 가져오고(`MergeLedger`),
  그 뒤 사용자가 해제하면 되살아나지 않는다.
- 두 Mac 모두 v1.3.2 이상이어야 이 판정이 온전하다. 한쪽이 예전 버전이면 그쪽의 변경에는 편집 기록이 없어
  "나중에 동기화한 쪽이 이긴다"는 iCloud의 동작으로 돌아간다.

## 외관 설정 (v1.3.2)

- 설정 > 외관에서 시스템 설정 / 라이트 / 다크를 고른다(`AppearanceMode`). 기본은 시스템 설정.
- 이 Mac의 UserDefaults(`appearanceMode`)에만 저장한다. `AppSettings`(동기화되는 설정)에는 넣지 않았으므로
  스키마는 그대로이고, Mac마다 다른 외관을 쓸 수 있다.
- 적용은 `NSApplication.appearance`로 한다(시스템 설정이면 nil). 창뿐 아니라 시트·팝오버·알림창·메뉴까지 한 번에 바뀌고,
  nil로 되돌리면 Mac의 외관 변경을 따라간다. `preferredColorScheme`은 창의 내용에만 걸려서 쓰지 않았다.
- 실행할 때 창이 뜨기 전에 적용하고(`AppLaunch.make`), 설정에서 바꾸면 즉시 적용한다.
- 색은 전부 `Theme`/`GroupColor`의 동적 색이라 외관이 바뀌면 같이 바뀐다.

## 브랜드 아이콘과 사이드바 (v1.3.3)

- 아이콘은 시안 이미지를 확대하지 않고, 시안에서 잰 경계와 색으로 벡터를 다시 그려 만든다(`Tools/GenerateIcons.swift`).
  크기마다 따로 그리므로 16px에서도 또렷하다. 에셋을 고치려면 스크립트를 고쳐 다시 실행한다.
- 에셋(`Daylog/Assets.xcassets`)
  - `BrandIcon.imageset`: `DaylogIconLight.png` + `DaylogIconDark.png`(다크 외관 변형). 1024×1024, 여백 없는 둥근 사각형.
    앱 안(사이드바 머리말, 설정의 앱 정보)에서 쓰고, 앱의 외관에 따라 자동으로 바뀐다.
  - `AppIcon.appiconset`: macOS 아이콘 격자(바깥 여백·그림자 포함)에 맞춘 **라이트** 아이콘. Finder와 Dock의 기본 아이콘.
  - `DockIconDark.imageset`: 같은 격자의 다크 아이콘.
- macOS의 에셋 카탈로그는 앱 아이콘의 다크 변형을 iOS·iPadOS에서만 지원한다(Apple 문서 "Configuring your app icon").
  macOS에서 외관별 앱 아이콘을 번들에 넣는 공식 방법은 Icon Composer 파일(macOS 26+)인데, 이번에는 쓰지 않았다.
  대신 실행 중에는 `NSApplication.applicationIconImage`로 Dock 아이콘을 앱의 외관에 맞춘다(`DockIcon`, `AppDelegate`가
  `effectiveAppearance`를 관찰). 앱을 끄면 Dock·Finder에는 라이트 아이콘이 보인다.
- 사이드바는 `Views/Sidebar/SidebarView.swift`: `SidebarBrandHeader`(아이콘 42pt + 이름 + 슬로건, 좁으면 슬로건부터 뺀다),
  메뉴 6개(v1.4부터. 색은 아이콘과 선택 표시에만: 오늘 민트, 루틴 파랑, 식사 기록 코랄, 통계 보라, 캘린더 주황, 설정 회색), 아래쪽 한 줄 문구.

## 플랫폼 구조: macOS · iPhone · iPad (v1.4)

타깃은 둘이고 소스 폴더는 하나다.

| 타깃 | 플랫폼 | 번들 ID | iCloud 컨테이너 |
|---|---|---|---|
| `Daylog` | macOS 14+ | `com.mungyubin.daylog` | `iCloud.com.mungyubin.daylog` |
| `DaylogiOS` | iOS·iPadOS 17+ (유니버설) | `com.mungyubin.daylog.ios` | 같은 컨테이너 |

- **공유 방식**: `Daylog/` 폴더를 두 타깃이 그대로 함께 컴파일한다. 모델·서비스·`AppStore`·화면이 모두 같다.
  플랫폼마다 다른 코드는 `#if os(macOS)`로 그 자리에서 가르고, 타깃별 파일 목록은 두지 않는다(파일을 추가할 때 빠뜨릴 일이 없다).
  패키지로 나누지 않은 이유: 나눌 만큼 크지 않고, 지금 구조에서 가장 적게 바꾸는 방법이다.
- **플랫폼 차이가 모이는 곳**: `App/Platform.swift`(앱 활성화·종료 알림 이름, 시계가 뛰었을 수 있는 시점, 기기 이름, 라이트/다크 색 만들기),
  `Theme/AppearanceMode.swift`(macOS는 `NSApplication.appearance`, iOS는 화면 뿌리의 `preferredColorScheme`), `App/DaylogApp.swift`(창·앱 델리게이트),
  `Services/CloudSync.swift`(권한 읽기: macOS는 코드 서명, iOS는 프로비저닝 프로파일. 시뮬레이터는 로컬 전용).
  창 크기·Dock 아이콘·메뉴 막대·첫 응답자 처리는 macOS에만 있다. 저장소 잠금(`StoreLock`)과 백업은 두 플랫폼이 같은 코드를 쓴다.
- **스키마와 동기화는 그대로다.** 모델을 바꾸지 않았고 컨테이너도 새로 만들지 않았다. iOS 앱은 같은 `ModelContainer` 설정으로 같은 개인 데이터베이스를 쓴다.
  기기마다 `deviceID`가 따로라서 필드별 편집 기록(`FieldEdit`)과 체크 병합 규칙이 Mac끼리와 똑같이 적용된다.

### 메뉴와 탐색

메뉴는 여섯 개: 오늘, 루틴, 식사 기록, 통계, 캘린더, 설정(`AppStore.Section`).

| 화면 | 탐색 | 고르는 기준 |
|---|---|---|
| macOS | `NavigationSplitView` 사이드바 | 항상 |
| iPad(넓은 창) | 고정 사이드바 + 상세 | `horizontalSizeClass == .regular` |
| iPhone, iPad의 좁은 창 | 아래 탭 5개(오늘·루틴·식사·통계·설정) | `horizontalSizeClass == .compact` |

- 기기 종류나 고정 크기가 아니라 **창 너비**로 고른다. iPad의 Split View·Stage Manager에서 창이 좁아지면 탭으로 바뀐다.
- 아래 탭에는 캘린더가 없다. 좁은 화면에서는 통계 화면 맨 아래에 달력이 붙고, 날짜를 누르면 그날의 기록으로 간다.
- iPad의 사이드바는 `NavigationSplitView`가 아니라 고정 너비 열이다. 세로 방향에서도 숨지 않게 하려는 것이고, 좁아지면 어차피 탭으로 바뀌므로 접는 단추가 필요 없다.
- 각 화면 안의 열 수(1열·2열·4열)는 `GeometryReader`로 잰 내용 너비로 정한다. 그래서 iPad 가로 화면은 같은 너비의 Mac 창과 같은 배치가 된다.

### 좁은 화면의 오늘 (`TodayCompactView`)

진행률 고리 → 다음 루틴 → 체크 목록 → 식사 요약. 통계 카드와 차트는 통계 탭에 있다.

- 진행률 카드는 "시작 전(첫 루틴을 만들기 전)", "휴식(예정된 루틴이 없는 날)", "미기록(예정은 있었는데 체크 없음)"을 글자로 구분한다.
- "다음 루틴"은 `NextCheck.pick`(순수 함수)이 고른다: 시간이 정해진 남은 항목 중 지금 이후 가장 이른 것, 없으면 가장 먼저 밀린 것. 표시만 하고 알림은 없다.
- iCloud를 쓰는데 아직 한 번도 가져오지 못했으면(`CloudSyncMonitor.isWaitingForFirstImport`) "아직 등록된 루틴이 없어요" 대신 확인 중이라고 알린다.
  다른 기기에서 쓰던 사람에게 빈 화면을 새 사용자의 화면처럼 보여 주지 않기 위해서다. 예시 기록은 만들지 않는다.

### 루틴 관리와 편집 (v1.4)

- 목록에는 이름·요일·시간만 둔다. 색상 팔레트와 요일 버튼은 편집 화면에만 있고, 달성 기준값은 설정 화면에만 있다.
- 그룹 접기 상태는 기기마다 따로 저장한다(`collapsedRoutineGroupIDs`). 대시보드의 접기(`collapsedGroupIDs`)와는 별개다.
- 순서 변경은 끌어 놓기(항목은 손잡이, 그룹은 이름)와 더 보기 메뉴의 위/아래 이동 두 가지다.
- 편집 화면은 초안(`RoutineDraft`)만 고치다가 [저장]에서 한 번에 반영한다. [취소]·닫기·아래로 쓸어 닫기는 모두 버린다.
  빠른 선택(매일·평일·주말)과 요일 버튼은 같은 값을 읽어서 늘 일치한다(`WeekdaySelector`).
- 예정 시간은 예전처럼 `timeLabel` 글자로 저장한다("07:30"). 편집은 시스템 시간 선택기로 하고, `TimeLabel`이 글자와 시각을 오간다.
  예전에 자유롭게 적은 글자("아침 먹고")는 그대로 보여 주고, 원할 때만 시각으로 바꾼다. 스키마는 바꾸지 않았다.

### 식사 기록 · 캘린더 화면

- 둘 다 새 저장 구조 없이 `DayRecord`와 기존 카드(`MealCard`, `RoutineCard`, `MonthCalendarCard`, `MealHistoryView`)를 다시 쓴다.
  보고 있는 날짜(`AppStore.selectedDay`)를 화면들이 공유하므로, 캘린더에서 고른 날짜의 식사를 식사 화면에서 이어서 볼 수 있다.
- 미래 날짜는 고를 수 없다(`AppStore.select`). 달력의 상태는 색과 함께 기호(●/○/–)와 퍼센트로도 표시한다.
- 통계 화면은 탭을 없애고 루틴 통계 아래에 식사 요약을 붙였다. 지난 식사를 찾고 고치는 일은 식사 기록 화면이 맡는다.

### 검증 범위와 한계 (2026-10-11)

- macOS: 격리된 검증 빌드로 화면을 확인했다.
- iPhone·iPad: 시뮬레이터에서 확인했다. 시뮬레이터는 iCloud 없이 로컬 전용이라 **iOS의 CloudKit 동기화는 검증하지 못했다.**
- iPad 가로 화면, Split View, Stage Manager 크기 조절은 직접 확인하지 못했다(이 Mac의 개발 환경에는 시뮬레이터 화면을 회전시키거나 창을 나누는 수단이 없었다).
  넓은 배치는 같은 너비의 macOS 창에서, 좁은 배치는 iPhone에서 같은 코드로 확인했다.
- Xcode로 기기에 넣은 iOS 앱은 Development 환경을 쓴다. DMG(Production)로 설치한 Mac과 맞추려면 TestFlight/App Store 배포(Production)가 필요하다.
  Production 스키마에는 이미 같은 레코드 형식이 있어서 스키마를 다시 배포할 필요는 없을 것으로 보지만, 실제 기기에서 확인한 것은 아니다.

## 알림 · 위젯 · 메뉴 막대 (v1.5)

앱을 열지 않고도 오늘의 루틴을 보고 체크하는 세 가지 길. 모델과 CloudKit 구조는 바꾸지 않았다.

### 구조

```
DaylogShared/   앱(macOS·iOS)과 위젯이 함께 쓰는 순수 코드: Day, Weekdays, TimeLabel, Achievement, GroupColor,
                NextRoutine(다음 루틴 고르기), WidgetSnapshot(위젯이 그리는 값), WidgetBridge(앱 그룹 파일)
DaylogWidgets/  위젯 확장(iOS·iPadOS): TodayProvider, TodayWidgetView(작게·중간·크게)
DaylogShared/ToggleRoutineIntent.swift 앱·확장이 함께 빌드하는 체크 요청
Daylog/App/WidgetIntentExecution.swift 앱 타깃에만 있는 ForegroundContinuableIntent 채택
Daylog/App/AppRuntime.swift            창이 없어도 도는 일(날짜·외부 변경, 알림 예약, 위젯 데이터, 알림 버튼)
Daylog/Services/Companion/             알림 계획(순수 함수), 알림 센터 감싸개, 기기별 알림 설정
Daylog/Views/MenuBar/MenuBarView.swift macOS 메뉴 막대의 빠른 체크
```

- `AppStore.todaySections`: 보고 있는 날짜와 상관없는 "실제 오늘"의 체크. 메뉴 막대·위젯·알림이 이 값을 쓴다.
- `AppStore.setDone(routineID:on:_:at:)`: 대시보드·메뉴 막대·알림의 [완료]가 날짜를 지정해 체크를 저장한다.
  Phase 2.1 위젯은 실패 복구와 확인 처리를 위해 `applyWidgetCheck`를 사용하며 같은 `FieldEditService`·`DayRecordService`를 재사용한다.
  미래 날짜의 체크는 받지 않는다.
- `AppStore.onReload`: 저장된 내용이 바뀌어 화면 값을 다시 계산할 때마다 불린다. `AppRuntime`이 0.4초 모아서 알림 예약과 위젯 데이터를 맞춘다.
  루틴 추가·삭제·보관·이름·요일·시간 변경, 체크, iCloud에서 들어온 변경, 날짜 변경이 모두 이 길을 탄다.
- 날짜 변경·외부 변경·저장 시점의 구독을 `RootView`에서 `AppRuntime`으로 옮겼다. macOS에서 창을 닫아도 메뉴 막대가 남기 때문이다.

### 알림 (로컬, UserNotifications)

- **일회성 알림을 날짜별로** 예약한다(`RoutineNotificationPlanner`). 요일 반복 알림은 "오늘 이미 완료한 루틴은 오늘만 건너뛴다"를
  표현하지 못해서(완료해도 울리거나 반복 전체를 지워야 한다) 쓰지 않았다.
  Phase 2.1부터 **오늘 포함 365일을 후보로 계산하고, 휴가·완료·지난 시각을 제외한 가까운 60개**만 예약한다.
  매일 한 번이면 약 60일, 매일 여러 번이면 더 짧고 주 1회면 약 1년까지 후보를 채울 수 있다. 365일치 전달을 보장하는 뜻은 아니다.
- 60개는 보수적인 앱 정책이다. Apple의 [기존 UILocalNotification 문서](https://developer.apple.com/documentation/uikit/uilocalnotification)는
  가까운 64개를 유지한다고 설명하지만, 이를 현재 모든 UserNotifications 플랫폼의 동일한 보장으로 단정하지 않는다.
  실제 예약은 `UNNotificationRequest`를 쓰며 실패한 요청은 다음 조정에서 다시 시도한다.
- 휴가 추가·수정·해제, 외부 변경 수신, 앱 활성화·날짜·시간대 변경 때 예정 목록을 다시 계산한다.
  휴가 날짜는 예약 후보에서 빠지고, 해제하면 아직 지나지 않은 시각만 돌아온다. 과거에 전달된 알림은 휴가 지정으로 소급 제거하지 않는다.
- 예약이 소진되면 다음 앱 실행까지 자동으로 보충되지 않는다. 알림 전달 자체는 앱이 꺼져도 시스템이 맡지만,
  [백그라운드 실행 시점은 시스템이 결정한다](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app).
  무기한 예약 갱신이나 다른 기기에서 지정한 휴가의 즉시 반영은 보장하지 않는다.
  [로컬 알림 예약·취소](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)의 실제 대기 요청과 비교해 갱신한다.
- 식별자는 `routine.<routineID>.<날짜>`. 같은 날 같은 루틴은 몇 번을 맞춰도 하나다. 예약을 맞출 때는 지금 대기 중인 것과 비교해
  없어진 것만 지우고, 없거나 내용(이름·그룹·시간)이 달라진 것만 다시 건다.
- 지난 시각은 예약하지 않는다. 그래서 이미 울린 알림이 같은 날 다시 울리지 않고, 체크를 취소해도 시간이 남았을 때만 되살아난다.
- 완료하면 그날의 예약을 지우고, 알림 센터에 남아 있던 그 알림도 치운다.
- 시간이 없거나 시각으로 읽히지 않는 루틴("아침 먹고")은 알리지 않는다.
- 설정은 기기마다 따로다(UserDefaults `routineNotificationsEnabled`, `mutedRoutineNotificationIDs`). 기본은 꺼짐이고, **켜는 순간에만 권한을 묻는다.**
  루틴별 설정은 "끈 루틴"의 ID만 적어서, 새로 만든 루틴은 켜진 상태로 시작한다.
- 버튼: [완료]는 앱을 앞으로 띄우지 않고 그 날짜의 그 루틴을 완료로 만든다(이미 완료면 변화 없음). [나중에]는 알림만 닫는다(미루기 알림을 만들지 않는다).
  알림 자체를 누르면 그 날짜의 오늘 화면으로 간다. 앱이 꺼져 있으면 시스템이 앱을 백그라운드로 띄워 처리한다.
- 보장하지 않는 것: 기기가 꺼져 있거나 잠자는 중의 정시 알림, iCloud로 들어온 루틴 변경이 앱을 열기 전에 알림에 반영되는 것
  (iOS는 백그라운드 실행을 보장하지 않는다. 앱이 활성화될 때 반드시 다시 맞춘다).

### 위젯 (iOS·iPadOS, WidgetKit + App Intents, Phase 2.1)

**영속 저장은 앱 프로세스의 기존 SwiftData 컨텍스트에서 수행한다.** 위젯 확장은 SwiftData를 열지 않고,
App Group으로 SQLite를 옮기지도 않는다. 기존 저장소 위치·마이그레이션·`StoreLock`·CloudKit 연결을 유지한다.

- `ToggleRoutineIntent`는 앱과 확장이 함께 빌드한다. 앱 타깃에만 있는 `WidgetIntentExecution.swift`가
  `ForegroundContinuableIntent`를 채택해 앱 프로세스 실행을 지정한다. iOS 26 이상에는 `.foreground(.dynamic)`,
  iOS 27 이상에는 `.main` 실행 대상도 명시한다. 앱 화면을 앞으로 열도록 요청하지 않는다.
  Apple은 이 프로토콜을 채택한 위젯 인텐트가 [앱 프로세스에서 실행됨](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)을 명시한다.
  최신 API와 이전 OS 호환 방식은 [ForegroundContinuableIntent 문서](https://developer.apple.com/documentation/appintents/foregroundcontinuableintent)에 따른다.
- 실행 순서: 명시적인 목표 상태를 내구성 대기열에 기록 → 앱의 `AppRuntime.commitWidgetChecks()` →
  `AppStore.applyWidgetCheck()`가 `FieldEdit`와 체크를 저장 → 저장된 값으로 스냅샷 게시 → 해당 요청만 확인 처리(acknowledge).
  **즉시 저장 시점은 앱 프로세스에서 `context.save()`가 성공한 때**다. CloudKit 업로드 완료 시점은 이 시점과 다르며 시스템 정책을 따른다.
- 기존 식사 입력 등 대기 중인 편집을 먼저 저장한 다음 체크를 반영한다. 체크 저장 실패는 해당 트랜잭션만 되돌린다.
  목표 상태는 "뒤집기" 이벤트가 아니므로 반복 실행해도 같고, 더 최신 편집을 오래된 요청이 덮지 않는다.
  새 요청은 실제 오늘만 받는다. 과거에 받아 둔 요청은 지연 처리할 수 있고 미래 요청은 반영하지 않는다.

| 파일 | 쓰는 쪽 | 내용 |
|---|---|---|
| `widget-snapshot.json` | 앱 | 오늘부터 7일의 그룹·루틴·저장된 완료 여부·휴가 여부 |
| `widget-pending.json` | 인텐트 / 앱 확인 처리 | 날짜·루틴·명시적인 목표 상태·시각을 가진 저장 대기 요청 |

- 앱 런타임을 사용할 수 없거나 저장·스냅샷 게시가 실패하면 요청을 대기열에 남긴다. 다음 앱 실행·활성화 때 다시 처리한다.
  읽기만으로 요청을 소비하지 않으며, 이전 버전이 남긴 임시 대기열 파일도 복구한다. 짧은 파일 잠금 안에서 순서를 정하고 원자적으로 쓰며,
  확인 처리 동안 새로 추가된 요청은 유지한다. 잠금을 SwiftData 작업이나 비동기 대기까지 붙잡지 않는다.
- 위젯의 달성률과 확정 체크 상태는 저장된 스냅샷에서 읽는다. 대기 요청은 별도 저장 대기 상태로 표시하고,
  저장되지 않은 체크를 확정된 실적으로 계산하지 않는다. 연속 체크·취소는 대기 중인 목표 상태를 기준으로 다음 목표를 정한다.
- 오늘이 휴가면 달성률 대신 휴가 상태를 표시한다. 저장된 루틴 체크는 보존하며 대기 요청도 휴가를 해제하거나 기록을 지우지 않는다.
- 스냅샷 내용이 달라졌을 때 위젯 갱신을 요청하고, 인텐트 처리 후 해당 위젯의 타임라인을 갱신한다.
  타임라인에는 오늘 남은 예정 시각과 앞으로의 자정을 넣는다. 실제 화면 갱신 시점은 WidgetKit 정책을 따른다.
  앱을 7일 넘게 열지 않아 스냅샷이 없으면 "Daylog를 열어 주세요"를 보여 준다.
- 작게(오늘 상태·다음 루틴), 중간(그룹별 진행률), 크게(직접 체크 목록)를 유지한다.
  앱 미실행·재부팅 상황의 시스템 인텐트 라우팅과 기기 서명·App Group 접근은 실제 실행 검증이 별도로 필요하다.

### 메뉴 막대 (macOS, MenuBarExtra)

- 같은 프로세스의 같은 `AppStore`를 쓴다. 따로 띄우는 프로세스가 없으므로 저장소 잠금 규칙이 그대로다.
- 표시 여부는 이 Mac에만 저장한다(UserDefaults `showsMenuBarExtra`, 기본 켜짐).
  켜져 있으면 창을 닫아도 앱이 남고(`applicationShouldTerminateAfterLastWindowClosed`), 꺼져 있으면 예전처럼 창을 닫을 때 끝난다. 종료하면 아이콘도 사라진다.
- 스크롤 영역은 팝오버 안에서 제 높이를 정하지 못해 목록이 사라진다. 줄 수로 어림한 높이를 준다(`MenuBarView.listHeight`).

### v1.5 기존 검증 범위와 한계 (2026-10-11)

- 단위 테스트: 알림 계획·예약 맞추기·권한·버튼, 위젯 값·대기열 반영·파일, 메뉴 막대가 쓰는 오늘의 체크.
- iPhone 시뮬레이터: 알림 권한 요청, 예약, 실제 전달, 앱이 꺼진 상태에서 [완료] → 체크 반영, 위젯 작게·중간·크게, 큰 위젯에서 체크·취소, 앱을 열어 반영, 다크 모드.
  - 누른 직후 홈 화면의 위젯 그림이 한 박자 늦게 바뀌는 일이 있었다(타임라인은 바로 새로 계산됐고, 화면이 다시 그려질 때 맞는 값이 보였다).
    이 Mac의 시뮬레이터 환경 문제인지 실제 기기에서도 그런지는 확인하지 못했다.
- macOS(격리된 검증 빌드): 메뉴 막대 열기, 체크·취소, 대시보드 반영, 창을 닫아도 유지, 다시 열기, 표시 끄기/켜기, 종료 시 사라짐.
- **확인하지 못한 것**: macOS의 실제 알림 전달과 버튼(검증 빌드에 시스템 알림 권한을 주지 않았다), 실제 iPhone·iPad에서의 알림·위젯,
  iPad의 위젯, 앱 그룹이 들어간 기기 서명(개발자 계정에 앱 그룹 등록이 필요하다), 위젯 체크의 iCloud 동기화.
- 시뮬레이터에서 알림 버튼·위젯을 검증할 때는 `-DaylogStoreName`을 쓰지 않는다. 시스템이 앱을 백그라운드로 띄울 때는 실행 인자가 없어서 기본 저장소가 열린다
  (시뮬레이터의 기본 저장소는 iCloud 없이 그 시뮬레이터 안에만 있다).

## 휴가 모드 (Phase 2.1)

### 저장 및 기기 간 병합

- `VacationPeriod`는 `id`, `start`, `end`, `memo`를 가진 값 타입이다. 별도 SwiftData 모델이 아니다.
  `VacationService`가 기존 `FieldEdit`의 `dateKey = "vacation"`, `field = "vacation:<UUID>"`에 버전이 있는 JSON 전체 기간을 저장한다.
  JSON에는 시작·종료 날짜 키, 메모, 삭제 표시가 함께 들어가므로 서로 다른 기기의 날짜 절반끼리 섞이지 않는다.
- 기존 `FieldEdit` 레코드·속성이 그대로 CloudKit으로 전달된다. **모델 스키마 변경, 마이그레이션, Production 스키마 배포가 없다.**
  예전 클라이언트는 모르는 칸 이름을 무시해 기록은 유지하지만 휴가 UI·통계 제외·알림 중지는 적용하지 못한다.
  휴가 정책을 모든 기기에서 적용하려면 각 기기를 Phase 2.1로 업데이트해야 한다.
- `FieldEditService`의 기기별 편집과 `seenState` 인과 관계를 재사용한다. 상대 변경을 보고 고친 편집이 우선하며,
  서로 못 본 동시 수정은 시각·기기 ID로 전체 기간 하나를 결정한다. 동시 삭제와 수정은 삭제 표시가 우선한다.
  해제할 때 레코드를 지우지 않으므로 늦게 도착한 다른 기기의 옛 편집이 휴가를 되살리지 않는다.
- 겹친 기간은 독립적인 ID로 유지하며 날짜 판정은 합집합이다. 하나를 해제해도 다른 기간이 덮는 날짜는 휴가다.
  하루·과거·미래 기간과 메모를 지원하고 종료일이 시작일보다 빠르면 저장하지 않는다.
- 저장 실패 시 수정한 자기 기기의 편집 값·시각·인과 정보만 복원하고, 그 작업에서 새로 만든 미저장 객체만 취소한다.
  다른 미저장 식사 입력이나 기존 영속 레코드를 전체 rollback으로 잃지 않는다.
  AppStore는 먼저 입력 초안을 저장하며 그 저장이 실패하면 휴가 변경을 시작하지 않는다.

### 통계와 화면

- `StatsSource`가 휴가를 미래·시작 전·휴식·미기록보다 먼저 판정한다. `DayOutcome.status == .vacation`은 비율이 nil이며
  일별·주간·기간별 평균, 항목별·그룹별 집계의 분자와 분모 모두에서 제외한다. 유효한 날짜가 없으면 평균은 nil이다.
- 현재·최장 연속 달성일은 휴가를 건너뛴다. 휴가 자체가 일수를 늘리거나 연속 기록을 끊지 않는다.
  차트의 날짜와 히트맵 칸은 유지하고 휴가 상태로 표현한다. 캘린더·대시보드·위젯에서도 0% 대신 휴가를 표시한다.
- `DayRecord`·`DayCheck`·식사 기록·루틴 정의·요일·시간은 휴가 지정으로 바뀌지 않는다. 휴가 중에도 기록할 수 있고,
  휴가를 해제하면 기존 기록이 통계에 다시 반영된다.
- 설정의 휴가 관리와 캘린더 날짜 선택에서 같은 AppStore API를 사용한다. 저장·해제·외부 변경 수신 후
  `reloadStats()`가 휴가 목록·통계·월별 결과를 갱신하고 `onReload`를 통해 알림 계획과 위젯도 맞춘다.

### Phase 2.1 검증 현황 (2026-10-11)

- 변경 범위 테스트: 휴가·위젯·알림 계획 42개, 알림 예약·액션·위젯 디스크 재열기 21개 통과.
  미래 달 탐색을 추가하면서 발견한 기존 달력 정책 회귀를 수정하고 날짜 변경·휴가 18개도 통과했다.
  기존 API는 미래 이동을 막고, 휴가 캘린더만 명시적으로 미래 달 탐색을 허용한다. 미래 기록은 생성하지 않는다.
- 최종 전체 회귀: 273개 / 43개 suite 성공(검증 데이터·fixture 생성 전용 2건은 기본 설정대로 건너뜀).
  macOS Debug·Release, iOS Simulator Debug·Release(앱 및 위젯, 앱 그룹 로컬 서명) 최종 빌드 성공.
- iPhone Air / iOS 26.5 시뮬레이터: 앱 그룹 권한을 포함한 로컬 서명 빌드로 검증.
  - 앱 종료 후 큰 위젯 체크 → 앱 화면을 열지 않은 채 SQLite `DayCheck` 완료 1개, 대기열 0개 확인.
  - 이어서 취소 → 완료 0개, 대기열 0개. 시뮬레이터 shutdown/boot 뒤에도 날짜 기록 1개·체크 1개·완료 0개.
  - 앱 재실행 화면의 0/1과 일치. 위젯도 100%/체크에서 0%/미완료로 갱신된다(시스템 화면 갱신 지연은 있음).
  - 휴가 관리 추가·해제, 오늘 휴가 안내, 큰 위젯의 "오늘은 휴가" 표시 확인.
  - 실제 UNUserNotificationCenter 예약 조회: 60개 → 1년 휴가 등록 후 0개 → 휴가 해제 후 60개 복원.
- iPad Pro 11-inch (M5) / iPadOS 26.5 시뮬레이터: 휴가 관리 목록, 다일 휴가 캘린더 표시, 기존 완료 체크 유지 확인.
- macOS 별도 검증 번들(`com.daylog.phase21.verify`)·로컬 저장소: 캘린더에서 하루 휴가 추가 → 휴가·집계할 기록 없음,
  체크·식사 유지 → 해제 후 달성률 100% 복원 확인. 실사용 앱이나 저장소에는 접근·수정하지 않았다.
- 미검증: 실제 기기의 알림 전달·앱 그룹 프로비저닝·위젯, iPad 위젯 레이아웃, iOS 17~25 및 iOS 27 런타임,
  CloudKit Production 기기 간 동기화, macOS 실제 알림 전달. 작은/중간 위젯은 공통 데이터 테스트·빌드 검증이며 이번 실행에서 별도 조작하지 않았다.
  앞 절의 v1.5 검증 결과는 이전 버전의 증거다. 시뮬레이터 결과를 실기기 검증으로 간주하지 않는다.

## 배포 (DMG, Developer ID)

- `Tools/release.sh`: 테스트 → 아카이브 → Developer ID 서명 → 공증 → 스테이플 → DMG → 검증. `--publish`/`--publish-only`로 GitHub Release에 올린다.
  인증서는 Apple이 보관하는 "Cloud Managed Developer ID Application"을 Xcode 계정으로 쓴다(저장소에 인증서·키·암호 없음).
  DMG 파일 자체의 서명·공증에는 이 Mac 키체인의 Developer ID 인증서와 `notarytool` 자격 증명이 더 필요하다(없으면 앱만 공증된다).
- **환경이 둘이다.** Xcode로 직접 빌드한 앱(개발용 서명, `Tools/install.sh`)은 CloudKit **Development**를,
  Developer ID로 배포한 앱은 **Production**을 쓴다. 프로비저닝 프로파일이 그렇게 정해서 고를 수 없다(내보내기에서 Development를 지정하면 거부된다).
  같은 컨테이너(`iCloud.com.mungyubin.daylog`)지만 서로 다른 데이터라, 두 종류의 앱끼리는 동기화되지 않는다.
- Production은 스키마를 CloudKit Console에서 배포해야 기록을 만들 수 있다(2026-10-10 사용자가 배포했다고 확인, 앱에서의 확인은 아직).
- **환경을 바꾸면 기존 기록은 저절로 올라가지 않는다.** 저장소에는 "이미 보냈다"는 동기화 이력이 환경별로 남아 있다.
  2026-10-10 Mac mini에서 확인: 배포판(Production)으로 기존 저장소를 연 뒤 iCloud 요청은 변경 가져오기뿐이었고, 보내기(ModifyRecords)는 0건이었다.
- 그래서 v1.3.5부터 (`StoreReseed`, `CloudEnvironmentPlan`)
  - 저장소 정보 파일에 마지막으로 연결한 환경을 적는다. 설정 화면에도 "iCloud 환경"으로 보인다.
  - 적혀 있는 환경과 다른 환경의 앱으로 열면 **열지 않고 멈춘다**(두 환경의 기록이 섞이지 않게). 기록은 건드리지 않는다.
  - `open -n /Applications/Daylog.app --args -DaylogReuploadAll YES`로 한 번 실행하면: 자동 정리되지 않는 백업을 만들고 →
    모든 기록을 동기화 이력 없는 새 저장소 파일로 옮기고(식별자와 값 그대로) → 실제 열을 하나하나 비교해 같을 때에만 파일을 바꾸고 →
    iCloud에 연결한다. 이력이 없으니 iCloud에 처음 연결하는 저장소처럼 전부 다시 보낸다. 같은 환경에는 한 번만 한다.
  - 어느 단계든 실패하면 백업으로 되돌리고 오류 화면에 백업 위치를 보여 준다.
  - 새로 설치한 Mac에서는 필요 없다(요청하지 않으면 아무 일도 하지 않는다).
- 옮기기 전 백업: 앱을 끈 뒤 Debug 빌드를 `-DaylogDebugBackup keep-<이름>`으로 실행하면 저장소를 열기 전에 백업을 만들고,
  `verifyBackup:<이름>`이 임시 위치에 복원해 지금 저장소와 행·열 단위로 같은지 확인한다(내용은 출력하지 않는다).
  이름에 `-keep-`이 든 백업은 자동 정리에서 빠진다. 2026-10-10의 백업: `Backups/Daylog-keep-pre-production-20261010-200813`.

## 검증 전용 빌드

실제 앱·실제 기록·iCloud와 완전히 분리된 빌드. 번들 ID가 달라 컨테이너도 따로이고, iCloud 권한이 없다.

```bash
ARGS=(-project Daylog.xcodeproj -scheme Daylog -derivedDataPath build-verify PRODUCT_BUNDLE_IDENTIFIER=com.daylog.verify \
      CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= CODE_SIGN_ENTITLEMENTS=Config/Verify.entitlements)
TEST_RUNNER_DAYLOG_SEED=2026-10-10 xcodebuild "${ARGS[@]}" test -only-testing:DaylogTests/VerificationSeed   # 45일치 검증 데이터
open -n build-verify/Build/Products/Debug/Daylog.app --args -DaylogStoreName verify -DaylogDebugToday 2026-10-10 -DaylogDebugAppearance dark
```

## 빌드와 테스트

```bash
xcodebuild -project Daylog.xcodeproj -scheme Daylog -configuration Debug -derivedDataPath build -allowProvisioningUpdates build
xcodebuild -project Daylog.xcodeproj -scheme Daylog -derivedDataPath build -allowProvisioningUpdates test
open build/Build/Products/Debug/Daylog.app
```

실제 기록은 `~/Library/Containers/com.mungyubin.daylog/Data/Library/Application Support/Daylog/Daylog.store`에 저장된다.

## 개발용 검증 도구 (Debug 빌드 전용, Release에는 컴파일되지 않음)

| 실행 인자 / 설정 | 용도 |
|---|---|
| `--args -DaylogStoreName verify` | 실제 저장소 대신 `verify.store`를 사용한다 |
| `--args -DaylogDebugAppearance light` 또는 `dark` | 시스템 설정과 다른 모드로 화면을 본다 |
| `defaults write com.mungyubin.daylog DaylogDebugToday 2026-10-11` | 앱을 다시 활성화하면 자정이 지난 것처럼 동작한다. 끝나면 `defaults delete com.mungyubin.daylog DaylogDebugToday` |

| `--args -DaylogDebugScript "section:calendar"` | 그 화면을 연 채로 시작한다(dashboard, routines, meals, statistics, calendar, settings). iOS 시뮬레이터에서는 `xcrun simctl launch <기기> com.mungyubin.daylog.ios -DaylogStoreName verify -DaylogDebugScript "…"` |
| `--args -DaylogDebugScript "counts;quit"` | 기록의 개수, 저장소 형식, 백업별 개수·무결성, iCloud 상태를 표준 출력에 적는다(내용은 적지 않음) |
| `--args -DaylogDebugScript "compareBackup:before-v4;quit"` | 이름에 그 글자가 든 최신 백업과 지금의 저장소를 행·열 단위로 비교해 표·열 이름과 개수만 적는다 |

실제 저장소의 형식을 올릴 때는 실제 앱을 PID로 종료해 종료를 확인한 뒤, 위 두 명령을 Debug 빌드로 실행해
(`open -n -W --stdout <로그> …`) 변환 전 백업과 값이 같은지 확인하고 Release를 실행한다. 두 빌드를 동시에 띄우지 않는다
(`StoreLock`이 막는다).

화면 검증용 기록(45일치)은 `DaylogTests/VerificationSeed.swift`가 실제 서비스 코드로 `verify.store`에 만든다.
평소 테스트 실행에서는 건너뛴다. 실제 앱과 섞이지 않게 아래의 "검증 전용 빌드"에서 실행한다.

```bash
TEST_RUNNER_DAYLOG_SEED=2026-10-10 xcodebuild -project Daylog.xcodeproj -scheme Daylog \
    -derivedDataPath build test -only-testing:DaylogTests/VerificationSeed
open -n build/Build/Products/Debug/Daylog.app --args -DaylogStoreName verify
```

## Phase 3 데이터 이동과 기기 설정

- `RoutineTransferFormat`은 CSV/버전 JSON을 검증하고 `RoutineTransferService`는 미리보기와 최신 카탈로그·날짜를 비교한다. 명시적 확인 뒤 신규 ID에만 `applyChange`를 적용하고 한 번 저장한다. 오류 시 해당 작업을 되돌린다. 이름 기반 중복은 건너뛰고 서로 다른 설정은 덮어쓰지 않는다.
- `DataExportService`는 모델을 저장하거나 병합하지 않는다. 루틴 파일은 안전하게 재가져올 수 있는 활성 정의만 제공한다. 이름이 모호하거나 포맷으로 보존할 수 없는 정의는 오류를 표시한다. 전체 JSON은 v4의 7개 엔티티 물리 행·관계·휴가/충돌 이력을 보존하지만 복원 API는 없다. [파일 형식](docs/ROUTINE_FILES.md) 참고.
- `DevicePreferences`의 UserDefaults는 식사 표시, 카드 순서·숨김, 온보딩 완료만 담는다. SwiftData/CloudKit에 새 필드는 추가하지 않는다. 식사 숨김은 기록 삭제와 무관하고 필수 루틴 카드는 숨길 수 없다.
- `DashboardCards`가 좁은/넓은 화면에 같은 순서를 적용한다. `RootView`에서 식사 메뉴 숨김과 안전한 선택을 처리한다. 온보딩은 자동 seed 없이 확인한 입력만 기존 서비스를 통해 추가한다.
- 기간 통계는 직전 동일 길이 기간을 같이 읽어 비교한다. 휴가/휴식 등 집계 대상이 없으면 nil, 미기록 예정일은 기존 분모 규칙을 유지하면서 UI에서 실제 0%와 구분한다.
- macOS만 Sparkle를 링크한다. `UpdateConfiguration`이 번들 내 활성화·승인된 HTTPS feed·32바이트 공개 키를 요구하며, 현재 updater는 비활성이다. Developer ID·CloudKit 서명 설정과 실제 릴리스는 변경하지 않았다. 파일 선택을 위한 사용자 선택 파일 read/write sandbox 권한만 추가했다. [업데이트 활성화 절차](docs/UPDATES.md) 참고.

## 시트와 키보드, iPad 창 모드 (Phase 4-A)

실제 화면 점검에서 나온 규칙. 구현은 `Components/SheetChrome.swift`에 있다.

- **시트의 제목은 `sheetTitle`로 단다.** macOS에서 시트 안의 `navigationTitle`은 바깥 창의 제목을 바꾸고 시트를 닫아도 남는다.
- **키보드를 내리는 [완료]는 `keyboardDoneBar`로 단다.** `toolbar(placement: .keyboard)`는 시트를 한 번 띄우면 사라졌다. 시트는 따로 붙여야 한다.
- **iPad 창 모드의 창 조절 단추**는 탐색 막대가 없는 화면의 왼쪽 위 내용을 가린다. 뿌리 화면의 `clearingWindowControls`가 창 모드일 때만 위쪽을 비운다.
- 위젯 체크 직후 위젯 그림이 늦게 바뀌는 문제는 시뮬레이터에서만 확인했고 미해결이다([진행 기록](docs/PROGRESS.md)의 Phase 4-A).
