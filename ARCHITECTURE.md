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
