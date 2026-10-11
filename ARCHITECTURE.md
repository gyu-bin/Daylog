# Daylog 설계

macOS 14+ / SwiftUI / SwiftData / Swift Charts / CloudKit. 외부 의존성·자체 서버 없음.

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
