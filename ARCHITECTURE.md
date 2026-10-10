# Daylog 설계

macOS 14+ / SwiftUI / SwiftData / Swift Charts / CloudKit. 외부 의존성·자체 서버 없음.

## 엔티티

| 엔티티 | 핵심 필드 | 생성 | 수정 | 삭제 |
|---|---|---|---|---|
| `RoutineItem` | id, title, note, timeLabel, weekdays, order, isArchived, updatedAt | 사용자 | 사용자 | 없음(보관만) |
| `RoutineRevision` | routineID, effectiveFromKey, 당시 title·timeLabel·weekdays·isArchived·order, updatedAt | 루틴 변경 시 자동 | 같은 날(또는 더 늦은 날짜의 이력이 있으면 그 이력) 재변경 시 덮어씀 | 없음 |
| `DayRecord` | dateKey, checks, 식사 4종, mealMemo, tomorrowTask, activityAt, syncID, mergeState | 날짜를 처음 열 때 | 사용자, 병합 | 없음 |
| `DayCheck` | routineID, title, timeLabel, note, order, isDone, isHidden, syncID | 기록 생성·오늘 동기화·병합 | 오늘만 동기화 | 없음(대상에서 빠지면 숨김) |
| `FieldEdit` | dateKey, field, deviceID, value, editedAt, seenState | 텍스트 칸을 고쳐 저장할 때 | 그 기기만 | 없음 |
| `AppSettings` | achieveThreshold, firstRoutineDate, updatedAt, syncID | 최초 필요 시 | 사용자, 병합 | 없음 |

v1.2부터 앱은 어떤 기록도 지우지 않는다. 동기화 환경에서는 "한 기기가 지운 것을 다른 기기가 아직 쓰고 있는" 경우를
되돌릴 방법이 없기 때문이다.

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
| v1.2 형식 | `DaylogSchemaV2`. 고유 제약 제거, 모든 속성 기본값, `checks` optional, 새 속성·`FieldEdit` 추가 |
| 옮기는 방법 | 경량 마이그레이션(`DaylogMigrationPlan`) |
| 열기 전 | 형식이 바뀌거나 iCloud에 처음 연결할 때 `Backups/<이름>-<사유>-<시각>/`에 백업을 만들고 무결성과 기록 수를 검증 |
| 순서 | 백업 → iCloud 없이 로컬에서만 옮김 → 기록 수 대조·동기화 식별자 채움 → 그다음 iCloud 연결 |
| 실패 시 | 백업으로 되돌리고 오류 화면에 백업 위치 표시. 빈 저장소로 대체하지 않음 |

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

### 동기화 검증 도구 (Debug 전용)

`DebugScript`: 한 Mac에서 저장소 2개를 두 기기처럼 띄워 실제 iCloud로 검증한다.
팀 서명된 앱의 저장소는 다른 프로세스가 읽을 수 없어서 앱이 직접 상태를 출력한다.

```bash
APP=build/Build/Products/Debug/Daylog.app
# 기기 A: 오프라인(iCloud 없이) 수정 → 다시 연결
open -n -W --stdout /tmp/a.log "$APP" --args -DaylogStoreName syncA -DaylogCloud NO  -DaylogDebugScript "text:dinner=A;dump:A;quit"
open -n -W --stdout /tmp/a.log "$APP" --args -DaylogStoreName syncA -DaylogCloud YES -DaylogDebugScript "waitExport:90;dump:A;quit"
# 끝나면 iCloud와 로컬의 검증 데이터를 지운다(실제 기록이 있는 상태에서는 실행하지 말 것: iCloud의 기록을 모두 지운다)
open -n -W --stdout /tmp/z.log "$APP" --args -DaylogStoreName syncTmp -DaylogCloud NO -DaylogDebugScript "deleteCloudZone;purgeLocalStore;quit"
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

화면 검증용 기록(45일치)은 `DaylogTests/VerificationSeed.swift`가 실제 서비스 코드로 `verify.store`에 만든다.
평소 테스트 실행에서는 건너뛴다.

```bash
TEST_RUNNER_DAYLOG_SEED=2026-10-10 xcodebuild -project Daylog.xcodeproj -scheme Daylog \
    -derivedDataPath build test -only-testing:DaylogTests/VerificationSeed
open -n build/Build/Products/Debug/Daylog.app --args -DaylogStoreName verify
```
