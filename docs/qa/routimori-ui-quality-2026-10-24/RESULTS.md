# RESULTS — RoutiMori 전 화면 UI 품질·접근성 안정화 (2026-10-24)

**최종 판정: PARTIAL**

주요 화면을 작은 iPhone·iPhone 17·iPad(세로·가로·실제 회전)·Mac(최소·보통·넓은 창)에서 실제로 띄워 확인했고, 찾은 P0 6건과 P1 15건을 고쳐 같은 조건에서 다시 확인했다.
PASS가 아닌 이유:

- 실제 VoiceOver 탐색, Reduce Motion 실제 화면, Mac 키보드 탐색·팝오버·최소화, 큰 iPhone, iPad Split View는 실행하지 못했다(NOT_TESTED).
- P1 1건(iPad 사이드바 글자 고정)이 남았다.

## 변경 요약

- **큰 글자(AX) 배치:** 한 줄에 고정해 두던 곳을 들어가지 않으면 세로로 쌓는 배치로 바꿨다(`ViewThatFits`, Dynamic Type 조건 분기).
  - 대상: 홈 머리말, 진행률 카드, 다음 루틴 카드, 루틴 관리·휴가·템플릿 머리말, 설정 세부 머리말, 온보딩 머리말·단추, 옷장 배지, 달성률 표
- **넘침 원인 제거:**
  - 달력 범례는 줄인 그림(scaleEffect)이 아니라 줄바꿈으로 바꾸고, 달 이름의 가로 고정을 풀었다.
  - 넓은 홈 머리말의 가로 고정을 풀었다.
  - 통계 요약 칸은 큰 글자에서 격자 대신 세로 쌓기로 바꿨다.
  - 공용 `FlowLayout`은 한 줄보다 넓은 항목을 줄 너비로 다시 잰다.
- **글자 크기를 따르지 않던 고정 크기:**
  - 화면 제목·넓은 홈 인사말: `@ScaledMetric`. 기본 크기는 그대로 24pt이다.
  - 요일 단추: 글자 높이에 맞춘다.
  - 다음 루틴 아이콘 상자: 글자 크기를 따른다.
- **잘림 해제:** 큰 글자에서는 줄 수 제한을 풀었다(설정 요약, 루틴 이름·메모, 기간, 그룹 이름). 날짜 칸은 날짜를 위 줄에 온전히 적는다.
- **접근성:** 장식 꺾쇠 6곳을 VoiceOver에서 숨겼다.
- **테스트 환경 결함:**
  - `PioStoreKitIsolationTests`: 환경 변수가 없으면 사유를 남기고 건너뛴다. 건너뛴 실행의 tearDown은 아무것도 하지 않아, 프로세스가 죽던 크래시가 사라졌다. 구매 로직은 바꾸지 않았다.
  - 크리스마스 독립 눈: 예전 기대값을 현재 사양으로 갱신했다(`PioVacationFinalArtworkTests`, `PioVacationProductionTests`).
- **새 회귀 검사:** `UIDynamicTypeLayoutTests`(iOS)를 추가했다. 화면 조각 25종과 넓은 홈 조각 2종이 글자 크기 5단계에서 화면 폭을 넘는지 잰다.
- **QA 산출물 관리:**
  - `.gitignore`에 `*.xcresult/`, `__pycache__/`, `*.pyc`만 추가했다. 이 규칙에 걸리는 추적 파일은 0개이다.
  - 반복 캡처는 프로젝트 밖 `~/Library/Caches/DaylogQA.noindex/`에서 만들고, 대표 55장만 `evidence/`에 줄여 넣었다(7.3MB). 중간 캡처(49MB)는 검증 뒤 지웠다.

## 결함 수

| 구분 | 발견 | 수정 | 남음 |
|---|---|---|---|
| P0 | 7 (작업 중 내가 만든 크래시 1건 포함) | 7 | 0 |
| P1 | 16 | 15 | 1 (iPad 사이드바 글자 고정, R2) |
| P2 | 8 | 1 | 7 (UI-AUDIT R1·R3~R8) |

상세: [UI-AUDIT.md](UI-AUDIT.md)

## 테스트 환경 결함 처리

| 테스트 | 원인 | 처리 |
|---|---|---|
| `PioVacationFinalArtworkTests` (Mac) | 테스트는 "기본 외 의상은 독립 눈 없음"을 기대. 그런데 10/24 최종 점검(`pio-character-final-pass-2026-10-24/RESULTS.md`)에서 크리스마스 낮 전용 눈이 사양으로 추가됨. Release 경로(기본값 켜짐, Release 카탈로그 에셋)에도 연결되어 있고, 전용 검증 테스트가 있음 | 앱 회귀가 아니므로 기대값 갱신: 크리스마스는 눈 있음, 나머지는 없음 → PASS |
| `PioVacationProductionTests.testBasicDayEyeResourcesAndLifecycle` (iOS) | 같은 원인 | 같은 기준으로 갱신 → PASS |
| `PioStoreKitIsolationTests` | 환경 변수 없이 setUp이 건너뛰어도 tearDown이 `!` 강제 해제로 테스트 프로세스 종료 | 빈 값으로 읽고, 필수 변수가 없으면 사유와 함께 XCTSkip, 건너뛴 실행의 tearDown은 바로 반환. 하네스(`Tools/pio-storekit/isolate.py`)가 변수를 주면 이전과 똑같이 실행됨. 건너뜀은 통과 수에 넣지 않음 |

## 빌드·테스트 결과

| 항목 | 결과 |
|---|---|
| macOS 빌드 (`Tools/dev.sh build`, Debug 검증) | 성공 (최종 코드) |
| iOS 시뮬레이터 빌드 (`Tools/dev.sh ios`) | 성공 (최종 코드) |
| Mac 단위 테스트 전체 (`DaylogTests`, XCTest+Swift Testing) | 844개: 통과 754 / 실패 2 / 건너뜀 88 |
| └ 실패 2건 | `PioHomeProductionTests`의 타이밍 테스트 2개. 전체 실행에서만 실패하고 단독 실행에서는 8/8 통과. 이번 변경은 피오 홈 애니메이션을 건드리지 않았다. 원인은 전체 실행 부하로 보이며, 기존 불안정 테스트로 분류함 |
| iOS 테스트 대상 전체 (`DaylogStoreKitTests`, iPhone 17) | 90개: 통과 21 / 실패 5 / 건너뜀 64 |
| └ 실패 5건 → 수정 뒤 4건 | StoreKit 기존 실패 4건(구매 취소·전체 구매·중단 구매·환불)은 이번 작업으로 해결됐다고 주장하지 않음. 나머지 1건(휴가 크리스마스 눈 기대값)은 갱신 후 재실행 PASS |
| 새 레이아웃 폭 검사 2개 (`UIDynamicTypeLayoutTests`, iPhone SE) | PASS (넘침 0건). 넓은 홈 수정을 되돌리면 4건 실패해 실제로 잡는 것을 확인 |
| 앱 재실행 | 화면마다 앱을 종료·재실행해 캡처(수십 회). 흐름 A의 완료 기록이 재실행 뒤에도 유지됨 |

통과 수에는 건너뜀(SKIP)을 넣지 않았다. iOS 테스트의 건너뜀 64개는 대부분 옵션을 켜야 도는 원화·StoreKit 검증용 테스트이다.

## 실제 사용자 흐름

| 흐름 | 결과 |
|---|---|
| A 홈·루틴 | PASS: 실행 → 전날 이동 → 오늘 → 다음 루틴 [완료] → 진행률 2/6 → 3/6 → 재실행 후 유지. 루틴 편집 시트 열기·스크롤·취소 확인. 실제 저장 편집은 하지 않음 |
| B 피오 | 부분: 옷장(기본 피오 착용 상태) → 홈 → 휴가(낮·밤) → 재실행. 이 시험 저장소에는 유료 의상 권한이 없어 다른 의상 입히기는 NOT_TESTED(구매 권한·StoreKit 미변경) |
| C 작은 화면 AX5 | PASS: SE AX5에서 5개 탭·설정 세부·시트 2종·온보딩·첫 동기화 탐색, 스크롤, 시트 닫기·복귀 |
| D iPad | PASS: 세로 → 주요 화면 → 실제 가로 회전 → 시트 → 세로 복귀(시트·입력 유지) |
| E Mac | 부분: 창 크기 3단계에서 8개 메뉴 진입. 팝오버·최소화·복원·사이드바 접기는 NOT_TESTED |

## 수정 파일

앱:
- `Daylog/Views/Dashboard/TodayCompactView.swift`
- `Daylog/Views/Dashboard/DashboardView.swift` (`DateNavigator`, `DashboardHeader`)
- `Daylog/Views/Dashboard/MonthCalendarCard.swift`
- `Daylog/Views/Routine/RoutineManagementView.swift`
- `Daylog/Views/Routine/RoutineListRow.swift`
- `Daylog/Views/Routine/WeekdaySelector.swift`
- `Daylog/Views/Statistics/StatisticsView.swift` (`PageTitle`)
- `Daylog/Views/Statistics/RoutineStatisticsView.swift`
- `Daylog/Views/Statistics/RateCards.swift`
- `Daylog/Views/Settings/SettingsView.swift`
- `Daylog/Views/Templates/TemplateLibraryView.swift`
- `Daylog/Views/Vacation/VacationView.swift`
- `Daylog/Views/Vacation/VacationDayCard.swift`
- `Daylog/Views/Vacation/VacationManagementView.swift`
- `Daylog/Views/Wardrobe/PioWardrobeView.swift`
- `Daylog/Views/Onboarding/OnboardingView.swift`
- `Daylog/Views/Onboarding/RoutimoriSyncScene.swift`
- `Daylog/Components/ProgressViews.swift` (`FlowLayout`)
- `Daylog/Components/Card.swift`

테스트:
- `DaylogStoreKitTests/UIDynamicTypeLayoutTests.swift` (새 파일)
- `DaylogStoreKitTests/PioStoreKitIsolationTests.swift`
- `DaylogStoreKitTests/PioVacationProductionTests.swift`
- `DaylogTests/PioVacationFinalArtworkTests.swift`

기타:
- `.gitignore`

손대지 않은 것:
- 브랜드, 번들 ID, 상품 ID, StoreKit 구매·복원 로직
- 데이터베이스·사용자 기록
- 피오 원화·휴가 원본·클라우드 리그·피오 애니메이션
- 다른 세션이 작업 중이던 `pio-character-final-pass-2026-10-24` 폴더

커밋·푸시·배포는 하지 않았다.

## 교훈

- 큰 글자 결함의 대부분은 "가로로 고정된(`fixedSize`·고정 프레임) 조각이 화면 전체를 민다"였다. 한 조각이 넘치면 같은 화면의 모든 카드가 잘려 보여서, 원인이 화면 맨 아래 카드(달력)인 경우도 있었다. 폭 측정 테스트가 원인을 바로 짚었다.
- 빌드 성공만으로는 부족했다. 장식 아이콘 숨김 한 줄이 실제 실행에서 홈 크래시를 냈고, 앱을 직접 띄워 보고서야 알았다.
