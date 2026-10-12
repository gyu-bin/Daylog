# Daylog 진행 기록

최종 갱신: 2026-10-12(대시보드 2열·카드 드래그 추가). 다음 세션은 이 문서 → PHASE3.md → git status/diff 순서로 확인한다.

## 기준과 커밋

- 작업 브랜치 main. 시작 상태 clean, 기준 HEAD `64cb21023cd535b0e2c34ef9c52a3f332754e468` (`feat: persist widget checks immediately and add vacation mode`).
- 이전 커밋 `408947a`는 알림·위젯·메뉴 막대, `f0d74de`는 iOS 유니버설 앱·루틴 편집 개선.
- Phase 3 코드와 이 최종 검증 기록은 같은 main 커밋에 포함한다. 해당 구현 SHA는 `git log -1 --format=%H -- docs/PROGRESS.md`로 확인한다. 다음 세션은 `git status`와 `git log -1`로 이후 변경 및 원격 상태도 확인한다.
- SwiftData v4·CloudKit 모델/환경은 유지했다. 실제 사용자 저장소에 테스트 데이터를 쓰지 않았다.

## Phase 3 기능별 상태

| 기능 | 구현 상태 | 검증 및 남은 작업 |
|---|---|---|
| 개발 계획·명세 | 완료 | DEVELOPMENT_PLAN.md, PHASE3.md, 본 진행 기록. 형식/운영 문서 추가 |
| A CSV·JSON 가져오기 | 완료 | 5MB/1,000행, 검증·미리보기·확인·최신 상태 재검증·원자적 저장. Mac 파일선택→중복1/생성2 확인→저장 및 잘못된 시간 차단 UI 확인 |
| B 데이터 내보내기 | 완료 | 활성 CSV/루틴 JSON, 7개 엔티티 전체 JSON. 읽기전용/모든 모델 필드/관계/휴가·충돌 이력 테스트. Mac 파일저장 결과 확인 |
| C 식사 ON/OFF | 완료 | 기기별 UserDefaults, 모든 메뉴/식사 UI 숨김. Mac 입력→OFF→ON→재실행 내용 보존, iPhone 탭 숨김 확인 |
| D 대시보드 | 완료 | 순서·숨김·복원·오늘 루틴 필수. Mac 조작/배치 확인, iPhone·iPad 화면 확인 |
| E Sparkle 2 | 기반 완료·활성화 보류 | macOS만 Sparkle 2.10.0 고정 연결, 메뉴와 준비 중 안내 확인. 공개 키/설치 통신 권한/게시/실제 업데이트 승인 후 진행 |
| F 체크·통계 UX | 완료 | VoiceOver 속성·iOS 피드백·Reduce Motion 처리, 7/30/90일 직전 기간 비교, 미기록 구분. 계산 테스트와 Mac/iPad UI 확인 |
| G 온보딩 | 완료 | 3단계·skip·다시 보기·명시적 생성. Mac 생성 흐름, iPhone skip, iPad 기존 루틴 유지 흐름 확인 |

## 검증 결과

기능별 테스트를 먼저 실행했다. 최종 전체 회귀를 한 번 실행해 **310 tests / 49 suites**가 통과했다. fixture 생성용 2개 테스트는 원래 설정에 따라 건너뛰었다. 이전 Phase 2.1의 결과와 별개다.

| 검증 | 결과 | 증거 |
|---|---|---|
| 업데이트 구성·통계 비교·기간·휴가 | 28 tests / 4 suites 통과 | `/tmp/daylog-phase3-targeted.log` |
| 기기 설정·온보딩 | 10 tests / 2 suites 통과 | `/tmp/daylog-phase3-preferences.log` |
| 온보딩 보관 이름 충돌 수정 후 | 5 tests / 1 suite 통과 | `/tmp/daylog-phase3-onboarding-final.log` |
| 가져오기·내보내기 최종 | 18 tests / 2 suites 통과 | `/tmp/daylog-phase3-transfer.log` |
| 전체 회귀 1회 | 310 tests / 49 suites 통과 | `/tmp/daylog-phase3-regression.log` |
| macOS Debug | 최종 전체 회귀 빌드 통과 | 위 테스트 로그 |
| macOS Release | 최종 수정 포함 통과 | `/tmp/daylog-phase3-mac-release-final.log` |
| iOS Simulator Debug | 최종 수정 포함 통과 | `/tmp/daylog-phase3-ios-debug-final.log` |
| iOS Simulator Release | 최종 수정 포함 통과 | `/tmp/daylog-phase3-ios-release-final.log` |
| diff/프로젝트 설정 | 공백 오류 없음, plist 문법 정상 | `git diff --check`, `plutil -lint` |

테스트와 빌드는 검증용 Mac bundle `com.daylog.phase3.verify` 및 ad-hoc 서명으로 수행했다. 실제 Developer ID 공증 배포 빌드와 다르다. iOS는 시뮬레이터 빌드이며 실기기 Release 서명은 검증하지 않았다.

## 실제 UI 확인 범위

- Mac 별도 로컬 저장소 `phase3ui`: 온보딩 3단계로 그룹·루틴 생성, 체크 상태와 접근성 행동 설명, 식사 입력/표시 OFF/ON, 카드 숨김·이동·기본 복원, 앱 재실행 후 체크·식사 유지.
- Mac 파일 이동: CSV 선택→미리보기(중복1, 신규2, 기존 그룹1/새 그룹1)→명시적 확인→저장. `25:99` 오류 행 저장 비활성. 전체 JSON 파일 `/tmp/daylog-phase3-ui-backup.json`에서 루틴3·그룹2·체크2·식사 문자열과 기존 완료 체크·잘못된 행 미생성을 확인했다.
- Mac 메뉴 `Daylog → 업데이트 확인…`: 준비 중 안내, 실제 업데이트 시작 없음.
- iPhone Air / iOS 27.0 시뮬레이터: 첫 안내·건너뛰기·빈 대시보드·설정·식사 OFF 후 4개 탭 표시. Mac 설정과 독립.
- iPad Air 11-inch (M4) / iPadOS 26.5 시뮬레이터: 안내 도중 기존 루틴 1개 인식, 현재 루틴으로 계속→오늘 화면, 기존 체크100% 유지, 세로 대시보드와 통계의 빈 이전 기간 안내.
- 실제 VoiceOver 낭독·Reduce Motion 시스템 설정을 켠 런타임 동작·실기기 촉각은 미검증. 접근성 트리의 루틴명/상태/행동 설명은 확인했다.

## 검토에서 수정한 문제

1. 보관된 동일 이름 루틴을 온보딩 성공으로 잘못 안내하던 경로: 명확한 오류 안내와 회귀 테스트 추가.
2. 같은 그룹/이름의 서로 다른 루틴 ID가 내보내기 후 하나로 줄어들 수 있는 경로: 정의 일치 여부와 관계없이 루틴 파일 내보내기 차단, 전체 JSON 안내·두 ID 보존 테스트 추가.

## Phase 4-A 품질 점검 (2026-10-12)

기준 HEAD `4aa2716`. 새 기능 없이 세 플랫폼에서 실제 화면을 조작해 점검하고, 재현한 문제만 고쳤다. SwiftData·CloudKit 모델과 저장 경로는 바꾸지 않았다.

### 검증 환경

- macOS: 검증 번들 `com.daylog.verify`(ad-hoc, iCloud 권한 없음), 저장소 `audit4a`(새 저장소)·`verify`(45일 표본). 실제 앱·실제 저장소에는 접근하지 않았다.
- iPhone 17 / iPhone 17 Pro (iOS 27.0), iPad Air 11 (iPadOS 26.5), iPad Pro 11 (iPadOS 27.0) 시뮬레이터. 시뮬레이터 빌드는 iCloud에 연결하지 않는다(`CloudSyncConfiguration`).
- 저장 여부는 화면과 함께 시뮬레이터의 SQLite(`ZDAYCHECK`, `ZDAYRECORD`)·앱 그룹 파일을 읽어 확인했다.

### 실제로 조작해 확인한 것

| 플랫폼 | 확인 |
|---|---|
| macOS | 첫 실행 안내로 그룹·루틴 생성, 새 그룹, 항목 추가, 편집(평일·07:00·이름 변경) 저장, 체크·취소, 식사 입력, 지난 날짜로 이동, 카드 순서 변경·숨김, 식사 표시 끄기/켜기(메뉴에서 사라졌다 돌아옴), 캘린더에서 하루 휴가 추가 → 통계 "집계할 날이 없어요" → 해제 후 33% 복원, 가져오기·내보내기 시트, 다크 모드(오늘·통계·루틴) |
| iPhone | 첫 실행 안내(건너뛰기 아닌 경로 포함), 체크·취소, "다음 루틴"의 [완료], 편집 시트(주말·시간 켜기), 식사 입력, 통계, 카드 숨김·이동 → 오늘 화면 반영, **CSV 가져오기 전 과정**(미리보기 추가 2·중복 1 → 확인 → 저장 → 같은 파일 다시: 추가 0·중복 3), **CSV 내보내기**(파일 내용 확인), 알림 권한 거부 안내 / 허용 기기에서 60개 예약, 휴가 추가·해제, 위젯 작게·크게, 위젯 직접 체크·취소(앱 종료 상태), 입력 중 강제 종료 후 식사 글자 유지, 다크 모드 |
| iPad | 세로 전체 화면(사이드바)의 오늘·루틴·식사·캘린더·통계·설정, **창 모드에서 좁은 창(아래 탭)과 넓은 창(사이드바) 전환**, 전체 화면 복귀 |

### 발견한 문제

| # | 심각도 | 문제 | 상태 |
|---|---|---|---|
| 1 | High(실기기에서도 나면) | 위젯에서 체크한 직후 위젯 그림이 예전 상태로 남는다. 다음에 누르면 "직전" 상태가 그려진다 | **미해결** — 아래 참고 |
| 2 | Medium | macOS에서 시트(가져오기·내보내기, 휴가 추가·수정·관리)를 열면 창 제목이 시트 제목으로 바뀌고 닫아도 그대로 남는다 | 수정 |
| 3 | Medium | iPhone에서 시트를 한 번 띄우면(첫 실행 안내 포함) 키보드 위의 [완료]가 사라진다. 식사 메모처럼 Return이 줄바꿈인 칸에서 키보드를 내릴 단추가 없다. 시트 안에는 처음부터 없었다 | 수정 |
| 4 | Medium | iPhone 첫 실행 안내에서 키보드가 올라오면 "입력한 루틴 만들기"가 가려지고 Return으로도 만들 수 없다 | 수정 |
| 5 | Medium | iPad 창 모드(iPadOS 26 이상)에서 창 조절 단추가 화면 왼쪽 위의 제목·아이콘을 가린다 | 수정 |
| 6 | Low | iPhone 통계의 항목별 표: 이름이 "물 한 잔…"으로 잘리고 "100%"가 두 줄로 꺾인다 | 수정 |
| 7 | Low | 루틴 편집의 "알림은 울리지 않아요" 안내가 알림 기능이 생긴 뒤에도 남아 있다 | 수정 |
| 8 | Low | 가져오기 미리보기가 요일을 "1, 2, 3"으로 보여 준다(다른 화면은 평일·월·수·금) | 수정 |
| 9 | Low | 큰 위젯의 휴가·안내 문구가 맨 아래에 몰려 위가 비어 보인다. 편집 시트의 시간 스위치가 그룹 색이 아니라 초록이다 | 수정 |

**1번(위젯 그림) 상세** — iPhone 17 / iOS 27.0 시뮬레이터, 앱 종료 상태에서 큰 위젯의 항목을 눌렀다.

- 저장은 즉시 맞다: 누른 뒤 4초 안에 SQLite `ZDAYCHECK.ZISDONE`이 바뀌고 대기열(`widget-pending.json`)이 비며 스냅샷 파일에 새 값이 있다.
- 타임라인도 다시 계산된다(로그 `reload: succeeded with 10 entries`).
- 그런데 화면의 위젯은 그대로다(95초 뒤에도). 같은 항목을 다시 누르면 직전 상태가 그려지고, 외관 전환·앱 재설치·홈 화면 재진입 뒤에는 맞는 값이 그려진다.
- 추정: 상호작용 뒤에 위젯 렌더러가 다시 그릴 실행 시간을 받지 못한다(가시성 변경 때는 로그에 `Acquired runtime assertion`이 있고 상호작용 때는 없다). 우리 코드의 저장·스냅샷 순서 문제는 아닌 것으로 본다. **실기기에서 확인하지 못했다.**
- 손대지 않은 이유: 원인이 시스템 쪽으로 보이고, 화면만 먼저 바꾸는 방식(Toggle의 낙관적 표시)은 "저장이 확정되지 않은 값을 확정처럼 보이지 않는다"는 Phase 2.1 원칙과 부딪친다. 실기기에서 재현되면 그때 결정한다.

### 수정 내용

- `Components/SheetChrome.swift`(신규)
  - `sheetTitle`: macOS에서는 `navigationTitle` 대신 시트 위쪽에 제목을 직접 그린다(창 제목을 건드리지 않는다). iOS는 그대로 `navigationTitle`.
  - `keyboardDoneBar`: 키보드 알림으로 [완료] 막대를 띄운다. `toolbar(.keyboard)`를 대체하고, 뿌리 화면과 각 시트(루틴 편집·휴가 편집·첫 실행 안내)에 붙였다.
  - `clearingWindowControls`: iPad·iPadOS 26 이상·창이 화면보다 작을 때만 위쪽에 26pt를 비운다. `containerCornerOffset`과 `safeAreaPadding`은 스크롤·탭 화면 안쪽에 듣지 않아 바깥 여백으로 처리했다.
- `OnboardingView`: 루틴 이름 칸에서 Return(완료)으로 생성, 만들기 단추를 테두리 있는 단추로.
- `RateCards`: 좁은 화면에서는 그룹 칸을 빼고 색 점만 남김, 퍼센트 줄바꿈 방지.
- `DataTransferView.scheduleLabel`, `RoutineEditSheet` 문구·스위치 색, `WidgetNotice` 배치.
- 테스트 `QualityAuditTests` 4개 추가(창 모드 여백 판정, 화면 키보드 판정, 미리보기 요일 문구).

### 수정 후 확인

- 2: macOS에서 가져오기·내보내기와 휴가 추가 시트를 열고 닫은 뒤 창 제목이 "Daylog"로 남는 것을 확인.
- 3·4: iPhone 17 Pro에서 식사 메모·루틴 편집 메모·첫 실행 안내에 [완료]가 뜨고, 시트를 띄운 뒤에도 유지. 안내에서 Return으로 루틴 생성 → 3단계로 이동.
- 5: iPad Pro 11에서 좁은 창·넓은 창·전체 화면 세 경우를 확인(전체 화면에서는 여백 없음).
- 6·9: iPhone 통계 표와 큰 위젯의 휴가 표시를 화면으로 확인. 8은 테스트로만 확인(수정 뒤 미리보기 화면을 다시 열지 않았다).

### 결과

| 검증 | 결과 |
|---|---|
| 관련 테스트(QualityAudit·Onboarding·RoutineTransfer·DevicePreferences) | 30 tests / 4 suites 통과 |
| 전체 회귀 1회 | **314 tests / 50 suites 통과**(fixture 생성용 2개는 설정대로 건너뜀) |
| macOS Debug(테스트 빌드)·Release | 통과(검증 번들, ad-hoc) |
| iOS Simulator Debug·Release | 통과(앱+위젯) |

### 이번 점검에서 확인하지 못한 것

- **macOS 메뉴 막대 체크·취소**: 팝오버는 실제 클릭이 필요하고 그러려면 화면 전체 제어 승인이 필요한데 사용자가 자리에 없었다. v1.5에서 클릭으로 확인한 뒤 이 화면의 변경은 휴가 표시와 접근성 이름뿐이고 `MenuBarTests`는 통과한다.
- **macOS의 파일 선택 이후 단계**(CSV·JSON 가져오기, 중복 방지, 내보내기 저장): 파일 선택 창이 다른 프로세스라 배경 제어로 파일을 고를 수 없었다. 같은 코드의 전 과정은 iPhone에서 확인했고, Mac은 Phase 3에서 확인한 기록이 있다.
- macOS: 루틴·그룹 삭제, 끌어서 순서 바꾸기, 지난 날짜에 적은 식사가 다시 열었을 때 남는지(입력까지만 함), 실제 알림 전달.
- iPad: **가로 방향**(이 Mac에는 시뮬레이터를 회전시킬 수단이 없다. 넓은 배치는 창 모드의 넓은 창과 macOS에서 확인), 편집 시트·식사 입력·파일 가져오기의 직접 조작(iPad Air 시뮬레이터는 터치 권한이 없어 화면만 봄), iPad 위젯.
- iPhone: 중간 위젯, JSON 가져오기·전체 JSON 내보내기, 알림의 실제 전달(이번에는 권한·예약 개수만. 전달과 [완료]는 v1.5에서 확인).
- 실기기, iOS 17~26, VoiceOver·Dynamic Type, CloudKit 동기화.

### 다음에 검증할 때 알아 둘 것

- **검증 번들의 테스트는 빌드 폴더를 Desktop 밖에 둔다.** `-derivedDataPath build-verify`(프로젝트가 `~/Desktop` 아래)로 `xcodebuild test`를 돌리면 샌드박스된 테스트 호스트가 Desktop 접근 확인(TCC)을 기다리며 시작 단계에서 멈춘다("The test runner hung before establishing connection"). `open`으로 띄우는 화면 검증은 같은 폴더로도 된다.
- iPad 창 모드는 창 오른쪽 아래 모서리를 끌어 크기를 바꿀 수 있다(시뮬레이터 터치로 가능). 회전은 안 된다.
- 시뮬레이터에 따라 화면 키보드가 뜨지 않는다(하드웨어 키보드 연결 상태). 키보드 관련 확인은 화면 키보드가 뜨는 기기에서 한다.
- 목록을 쓸어 넘긴 직후의 탭은 스크롤을 멈추는 데 쓰여 단추가 눌리지 않는다. 3초쯤 기다린다.

## 대시보드 2열·카드 드래그·사이드바·메뉴 막대 아이콘 (2026-10-12)

기준 HEAD `21436ef`. SwiftData·CloudKit 모델은 바꾸지 않았다. 배치 설정은 전부 기기별 UserDefaults다.

### 바뀐 것

- **대시보드 2열**: 왼쪽 = 다음 루틴·휴가 설정·오늘의 루틴, 오른쪽 = 식사 기록·오늘의 달성 현황·최근 7일 기록·내일 오전 할 일.
  카드 높이는 내용만큼이고 열끼리 맞추지 않는다. 내용 너비 880pt 미만이면 같은 순서의 한 열.
  - 새 카드: `AchievementCard`(달성률 고리 + 그룹별 완료/전체), `WeekOverviewCard`(요일별 고리 + 이번 주 평균, 예전 표 `RecentDaysCard`를 대체),
    `TomorrowTaskCard`(루틴 카드에서 분리), 휴가 카드는 루틴 카드와 묶여 있던 것을 독립 카드로.
  - 주요 지표 4칸(`summary`)·월간 캘린더·달성률 추이·루틴별 달성률은 남아 있고 기본으로 숨긴다. 주요 지표를 켜면 두 열 위에 가로로 놓인다.
- **배치 저장**(`DevicePreferences`): 전체 순서 `device.dashboard.order` + 왼쪽 열 카드 `device.dashboard.left` + 숨긴 카드 `device.dashboard.hidden` + 형식 번호 `device.dashboard.layoutVersion = 2`.
  형식 번호가 없는 예전 저장값(한 열 배치)은 **새 기본 배치로 한 번 되돌린다.** 식사 표시·안내 완료 같은 다른 설정은 그대로다.
  iPhone은 진행률이 맨 위인 순서가 기본이다(예전 iPhone 오늘 화면과 같다).
- **대시보드 편집**(macOS·넓은 iPad): 날짜 옆의 격자 단추로 켠다. 카드마다 편집 막대(손잡이·이름·⋯ 메뉴)가 붙고 카드 내용은 눌리지 않는다.
  - 끌어서 놓기: 손잡이를 끌어 다른 카드 위에 놓으면 그 앞(그 열)으로, 열 맨 아래의 빈 자리에 놓으면 그 열 끝으로. 놓을 자리는 띠와 테두리로 보인다.
  - 메뉴: 위로/아래로 이동(같은 열 안), 다른 열로 이동, 숨기기. 편집 막대의 "숨긴 카드" 칩으로 되살리기, 기본 배치 복원, 완료(Return·Esc).
  - 오늘 루틴은 숨길 수 없고 옮길 수는 있다. 식사 표시가 꺼져 있으면 식사 카드는 편집 중에도 나오지 않는다.
  - iPhone은 설정의 "오늘 화면 구성"을 그대로 쓴다. 넓은 화면의 설정에는 카드별 왼쪽/오른쪽 선택이 추가됐다.
- **사이드바**: 주요 메뉴(오늘·루틴·식사 기록·통계·캘린더)와 맨 아래에 고정한 설정. 창이 낮으면 메뉴 쪽만 스크롤된다. 아래쪽 문구는 뺐다.
- **메뉴 막대 아이콘**: 잎사귀와 해를 그린 전용 벡터 템플릿(`Assets/MenuBarIcon`, SVG). 팝오버의 종료 단추 이름을 "Daylog 종료"로.
- **실행 시 창이 안 뜨던 문제**: 창을 닫아 둔 채(메뉴 막대만 남긴 채) 종료하면 다음 실행 때 창 복원이 "창 없음"을 복원해 창이 뜨지 않았다.
  실행 0.5초 뒤에도 창이 없으면 Dock을 눌렀을 때와 같은 "다시 열기"를 스스로 요청한다(`AppDelegate.requestReopen`).

### 실제 화면 확인 (macOS 검증 번들, 표본 저장소)

- 넓은 창 2열이 시안과 같은 구성으로 뜸(라이트·다크). 창 너비 900으로 줄이면 1열, 다시 넓히면 2열.
- 편집 모드: **실제 마우스로** 휴가 카드를 왼쪽 열에서 오른쪽 열의 식사 카드 위로 끌어 놓음 → 오른쪽 열 맨 위로 이동. ⋯ 메뉴의 "왼쪽 열로 이동"으로 되돌림.
  기본 배치 복원, 완료, 숨긴 카드 칩으로 주요 지표 되살리기 확인.
- 앱을 종료했다 다시 실행해도 배치 유지(주요 지표가 보이는 상태 그대로). 설정에서 카드 숨기기 → 오늘 화면 반영.
- 식사 표시 끄기 → 식사 메뉴와 식사 카드가 사라지고 오른쪽 열은 달성 현황·7일·내일 할 일. 다시 켜면 복원.
- 사이드바 설정이 맨 아래에 고정.
- 메뉴 막대 아이콘: 어두운 메뉴 막대(1배율 화면)에서 잎사귀·해가 분리돼 보이는 것을 메뉴 막대 부분만 캡처해 확인.
- 창 없이 종료된 상태에서 실행 → 창이 뜨는 것 확인(수정 전에는 창 0개).
- iPhone 17 Pro 시뮬레이터: 진행률 → 다음 루틴 → 휴가 → 루틴 순서 유지(기본 배치 복원 뒤). iPad Pro 11 세로: 사이드바 + 한 열, 편집 단추 표시.

### 결과

| 검증 | 결과 |
|---|---|
| 관련 테스트(DevicePreferences·QualityAudit·MenuBar) | 통과 |
| 전체 회귀 1회 | **319 tests / 50 suites 통과** |
| macOS Debug·Release, iOS Simulator Debug·Release | 통과 |

### 확인하지 못한 것

- **macOS 알림의 실제 전달과 [완료]**: 검증 번들의 알림 권한이 "꺼져 있어요"라 예약 0개였다. 권한을 한 번도 정하지 않은 두 번째 번들(`com.daylog.verify2`)은
  요청 뒤에도 "아직 허용하지 않았어요"였다(시스템 권한 배너는 사용자가 직접 허용해야 한다). 켤 때만 권한을 묻는 것과 요일·시간 예약은 단위 테스트와 iOS 시뮬레이터(Phase 4-A, 60개 예약)로만 확인했다.
- **메뉴 막대 팝오버의 체크·취소·앱 열기**를 새 아이콘으로 다시 눌러 보지 못했다(화면 제어 중 사용자가 중단). v1.5에서 클릭으로 확인한 동작이고 이번에 바꾼 것은 아이콘과 종료 단추 이름뿐이다.
- 메뉴 막대 아이콘의 밝은 메뉴 막대·Retina 화면 모습(템플릿 이미지라 색은 시스템이 맞춘다).
- 같은 열 안에서의 끌어 놓기 순서 변경, 열 맨 아래 빈 자리에 놓기, ⋯ 메뉴의 위/아래 이동·숨기기(메뉴에 항목이 뜨는 것까지만 봄), 끄는 도중의 자리 미리보기 모습.
- iPad에서의 터치 드래그, iPad 가로 2열, 휴가 설정 후 새 달성 현황 카드의 휴가 표시.
- README를 새로 쓰고 스크린샷을 2열 대시보드 기준으로 다시 찍었다(2026-10-12, 검증용 앱의 예시 데이터). 메뉴 막대 팝오버와 대시보드 편집 화면은 스크린샷에 없다.

## 디자인 정리 1차: 휴가·날짜 선택기·시트 공통 틀·메뉴 막대 아이콘 (2026-10-12)

기준과 화면별 상태는 [DESIGN_REFINEMENT.md](DESIGN_REFINEMENT.md)에 있다. 요약:

- 휴가 추가·수정·관리 시트를 내용 높이로 줄이고, 전용 기간 달력(`DayRangeCalendar`)을 넣었다. 시작일→종료일 순서로 고르고 종료일이 시작일보다 빠른 상태는 생기지 않는다.
- 모든 시트가 같은 틀(`SheetScaffold`)을 쓰도록 했다. 루틴 편집 시트도 옮겼다.
- 메뉴 막대 아이콘을 잎사귀 하나로 바꿨다(A안).
- 실제 화면으로 확인: macOS 라이트·다크, iPhone 17 Pro 시뮬레이터. 전후 캡처는 `docs/design-refinement/`.
- 확인 못 한 것: 휴가 해제 확인창 클릭, 달력 키보드 조작, 팝오버 여백, iPad.

## 디자인 정리 2차: 가져오기 시트·iPhone 시트 높이·설정 정리 (2026-10-12)

[DESIGN_REFINEMENT.md](DESIGN_REFINEMENT.md) 7~9절. 요약:

- 가져오기·내보내기 시트를 공통 틀로 옮기고 미리보기를 읽기 쉽게 했다(로직 변경 없음).
- iPhone 시트는 내용 높이만큼만 올라오고, iPad는 폼 시트를 쓴다.
- 설정을 보이는 것 → 루틴 규칙 → 기기 → 데이터 → 앱 정보 순으로 묶고 설명을 줄였다.
- 휴가 해제 확인창을 실제로 눌러 통계 복원을 확인했다. 달력 경계·윤년·VoiceOver 레이블 테스트를 추가했다.
- 미검증: iPad 가로·창 모드, 달력 키보드 조작, 파일 패널이 필요한 흐름.

## 제품 UX 점검: 휴가 카드 상태, 캘린더 시작 요일 (2026-10-12)

[PRODUCT_UX_AUDIT.md](PRODUCT_UX_AUDIT.md)에 흐름별 점검과 발견한 문제(U-1~U-8)가 있다. 요약:

- 휴가 카드가 등록된 휴가에 따라 "휴가 설정 / 다음 휴가(D-day) / 휴가 중(남은 날)"으로 바뀐다(`VacationStatus`). 설정의 휴가 줄도 같은 규칙으로 요약한다.
- 설정 → 캘린더 → 한 주의 시작(월/일, 기기별). 월간 캘린더·휴가 달력·식사 달력·활동 히트맵에 적용. 통계 집계 기간은 그대로.
- 새 창마다 첫 입력칸의 전체 선택 포커스를 푼다. 캘린더에 "앞으로의 날짜를 누르면 휴가 등록" 안내를 넣었다.
- 미검증: 메뉴 막대·알림·위젯 흐름, iPad, 창을 다시 열 때의 포커스.

## TestFlight 준비 (2026-10-12)

- iOS 앱에 수출 규정 선언(`ITSAppUsesNonExemptEncryption = NO`)을 넣었다. 자체 암호화 코드가 없다.
- Xcode 자동 서명(`-allowProvisioningUpdates`, 사용자 승인)으로 App ID `com.mungyubin.daylog.ios`·`.widgets`, App Group, 프로파일을 받아 기기용 Release 아카이브와 App Store 배포 서명 IPA를 만들었다(업로드 안 함).
- IPA 확인: Apple Distribution 서명, iCloud 컨테이너 `iCloud.com.mungyubin.daylog` / 환경 Production, aps-environment production, App Group 포함(위젯도). 버전 1.5.1 (1).
- 2026-10-12 12:01 App Store Connect에 1.5.1 (1) 업로드 성공(Delivery UUID `760df8ac-527d-4ac5-bebe-8b6ac5a1aa4b`). 처리 상태와 내부 테스트 그룹 설정은 App Store Connect에서 확인한다(이 Mac에는 API 키가 없어 명령으로 조회하지 못한다).
- iOS 앱과 위젯의 버전을 Mac과 따로 둔다: iOS **1.0.0**, Mac 1.5.1(`MARKETING_VERSION`을 타깃별로). 2026-10-12 12:07에 iOS 1.0.0 (1)을 다시 올렸다(Delivery UUID `35a3f70b-1869-40ff-91ef-ceae20b44d63`). 먼저 올린 1.5.1 (1)은 쓰지 않으며 App Store Connect에서 만료 처리한다.
- 같은 버전에서 다시 올릴 때는 빌드 번호(`CURRENT_PROJECT_VERSION`)를 올려야 한다. 같은 버전·빌드 번호는 거절된다. 이 값은 지금 프로젝트 전체가 함께 쓴다.
- 실기기의 iCloud 동기화·알림·위젯은 TestFlight 설치 후 검증한다.

```bash
# 아카이브
xcodebuild -project Daylog.xcodeproj -scheme DaylogiOS -configuration Release -derivedDataPath build/testflight/derived \
  -destination 'generic/platform=iOS' -archivePath build/testflight/DaylogiOS.xcarchive -allowProvisioningUpdates archive
# 업로드: ExportOptions의 method = app-store-connect, destination = upload
xcodebuild -exportArchive -archivePath build/testflight/DaylogiOS.xcarchive -exportPath build/testflight/upload \
  -exportOptionsPlist build/testflight/ExportOptions.plist -allowProvisioningUpdates
```

## iOS 동기화가 앱을 다시 켜야만 되던 문제 (2026-10-12)

- 증상(실기기, TestFlight 1.0.0 빌드 1): iPhone·iPad에서 다른 기기의 변경이 실행 중에는 들어오지 않고, 앱을 종료했다 켜면 들어온다. iPad의 "백그라운드 앱 새로 고침" 목록에 Daylog가 없다.
- 원인: 올라간 앱의 Info.plist에 `UIBackgroundModes`가 없었다. 프로젝트에는 `INFOPLIST_KEY_UIBackgroundModes = remote-notification`이 있었지만, Xcode가 만들어 주는 Info.plist는 이 키를 넣지 않는다. 그래서 CloudKit의 조용한 푸시로 가져오기가 시작되지 않았다(Mac은 이 선언이 필요 없어 정상이었다).
- 수정: `Config/DaylogiOS-Info.plist`에 `UIBackgroundModes = [remote-notification]`을 직접 적고 iOS 타깃의 `INFOPLIST_FILE`로 지정. 빌드 번호 2. 아카이브한 앱의 Info.plist에서 값이 들어간 것을 확인했다.
- 실기기에서 실제로 고쳐졌는지는 빌드 2를 TestFlight로 설치해 확인해야 한다. Mac에서 식사를 지워도 iPad에 반영되지 않던 것도 같은 원인으로 보지만, 빌드 2에서 다시 확인한다.
- 교훈: 빌드 설정을 믿지 말고 만들어진 앱의 Info.plist를 본다.

## 디자인 정리 3차: 대시보드·설정 밀도, 온보딩 흐름 (2026-10-12)

[DESIGN_REFINEMENT.md](DESIGN_REFINEMENT.md) 10~11절. 요약:

- 오늘의 루틴 카드에서 그룹별 "항목 추가" 줄을 머리말의 [+]로 접었다. 휴가 카드는 상태·기간·남은 날만.
- 설정의 카드 목록을 넓은 창에서는 "대시보드 구성 [편집]"(오늘 화면 편집 모드로 이동)으로, iPhone에서는 접힌 목록으로.
- 온보딩 2단계는 만들든 넘기든 3단계로. "안내 닫기"를 전체 건너뛰기로 구분.
- iOS TestFlight에는 아직 올리지 않았다(빌드 2 = 동기화 수정 + 이번 변경, 사용자 요청으로 대기).

## 디자인 정리 4차: 사이드바·휴가 메뉴·머리말·설정 2단 (2026-10-12)

[DESIGN_REFINEMENT.md](DESIGN_REFINEMENT.md) 12~13절. 휴가 메뉴(`AppStore.Section.vacation`, `VacationView`)가 생겼고, 설정은 갈래 목록 + 상세(`SettingsCategory`)가 됐다. iPhone 설정은 탭 안에서 `NavigationStack`을 쓰면 화면이 비어 직접 전환한다. iOS TestFlight 빌드 2는 아직 올리지 않았다.

## 디자인 정리 5~6차: 설정의 iCloud·기기 목록, 조건부 휴가, iPhone 홈 (2026-10-12)

[DESIGN_REFINEMENT.md](DESIGN_REFINEMENT.md) 14~15절. 기기 목록은 `DeviceService`가 `FieldEdit`의 `device:` 칸에 적는다(스키마 변경 없음, 실제 앱에서만 켠다 — `AppStore.tracksDevice`). 전체 기록 JSON 내보내기에는 이 줄도 들어간다. iOS TestFlight 빌드 2는 아직 올리지 않았다.

## Mac 앱 갱신과 TestFlight 빌드 2 (2026-10-12)

- 커밋 `b83c1e4`를 Mac 앱에 적용(`Tools/update.sh`)하고, iOS 1.0.0 (2)를 TestFlight에 올렸다(13:50, Delivery UUID `f6478cb3-261c-4dcc-9288-5dee09cc638c`).
- 빌드 2에 들어간 것: 원격 알림 백그라운드 모드 선언(실행 중 동기화), 설정 2단·iCloud 상태·기기 목록, 휴가 메뉴와 조건부 휴가 띠, iPhone 홈 개편, 캘린더 격자 ID 수정.
- 올린 IPA에서 확인: `UIBackgroundModes = remote-notification`, iCloud Production, aps production, App Group.
- 실기기에서 확인할 것: 앱을 끄지 않아도 다른 기기의 변경이 들어오는지, iPad의 백그라운드 앱 새로 고침 목록에 Daylog가 나오는지, 설정 → iCloud의 기기 목록에 세 기기가 보이는지.
- 다음에 올릴 때는 빌드 번호 3.

## 디자인 정리 7차: iPhone 홈 편집·머리말·휴가 위치 (2026-10-12)

[DESIGN_REFINEMENT.md](DESIGN_REFINEMENT.md) 16절. iPhone에서도 대시보드를 직접 편집한다(끌기·메뉴·숨김·복원). 휴가 카드는 iPhone에서 일반 카드이고 새 기본 위치는 맨 아래. iOS 빌드 번호 3.

- 커밋 `ee8b82b`를 Mac 앱에 적용했고, iOS 1.0.0 (3)을 TestFlight에 올렸다(14:08, Delivery UUID `6374b8de-37f2-4620-894d-fcebee2d9734`). 다음에 올릴 때는 빌드 번호 4.
- 실기기 확인(사용자): 빌드 2에서 iPhone ↔ Mac 동기화가 실행 중에도 정상 동작.

## Mac 갱신 때 GitHub DMG 자동 게시 (2026-10-12)

- GitHub Release `v1.5.1`을 올렸다(공증한 앱이 든 DMG, DMG 자체는 서명·공증 안 됨).
- `Tools/update.sh`가 이 Mac의 앱을 바꾼 뒤 `Tools/release.sh --skip-tests --publish --allow-unsigned-dmg`로 DMG까지 올린다. 끄려면 `--no-publish`.
- 같은 버전의 릴리스가 있으면 태그는 그대로 두고 DMG만 바꾼다. 어느 커밋으로 만든 DMG인지는 릴리스 설명 끝의 "빌드 기준 커밋" 줄에 적고, 체크섬도 함께 고친다.
- 올리지 않는 경우: 커밋하지 않은 변경, push하지 않은 커밋, 올라가 있는 DMG 이후로 앱 소스(`Daylog`, `DaylogShared`, `DaylogWidgets`, `Config`, `Daylog.xcodeproj`)가 그대로일 때.
- 자동 게시에서는 전체 테스트를 돌리지 않는다. 버전을 올린 새 릴리스의 설명은 기본 문구라 따로 채운다.

## 휴가 중 루틴, 설정의 업데이트 줄, iOS 메뉴 색, 주요 지표 카드 (2026-10-12)

배포하지 않았다(Mac 앱·TestFlight·GitHub DMG 그대로). 캡처는 `docs/vacation-routines/`(jpg).

### 휴가 중 루틴

- 휴가마다 "전체 휴식"(기본) 또는 "선택한 루틴만 유지"를 고른다(휴가 추가·수정 시트의 `VacationRoutinePicker`).
- 저장: 기존 휴가 줄(`FieldEdit`, `dateKey = "vacation"`)의 값에 `kept`(루틴 ID 배열) 칸을 더했다. **SwiftData·CloudKit 스키마 변경 없음.** 전체 휴식이면 칸을 쓰지 않아 이전 형식과 글자까지 같고, 형식 버전도 1 그대로다.
- 이전에 등록한 휴가는 전체 휴식으로 읽는다. 기존 줄을 변환하거나 다시 쓰지 않는다.
- 표시 규칙은 `VacationRoutinePolicy`(평소 / 전체 휴식 / 유지) 한 곳에 있다. `AppStore.checkSections`·`todaySections`·`upcomingDays`가 이 규칙으로 걸러진 목록을 내므로 오늘 화면, 메뉴 막대, 위젯 스냅샷, 알림 예약이 같은 목록을 쓴다. 저장된 체크(`DayRecord.checkList`)는 건드리지 않는다.
- 겹치는 휴가: 그날을 포함하는 기간 가운데 어느 하나라도 유지하기로 한 루틴은 유지한다(합집합).
- 유지하기로 한 루틴을 보관·삭제하면 그 루틴만 나오지 않는다(다른 루틴이 대신 나오지 않는다). 그날 해당하는 유지 루틴이 없으면 안내 한 줄만 보인다.
- 통계: 휴가 날짜는 전과 같이 달성률에서 빠진다(유지 루틴을 체크해도). 체크는 저장되고, 휴가를 해제하면 통계에 반영된다. 달성 현황·진행률·지표 칸·메뉴 막대·위젯은 0%가 아니라 "휴가"와 "유지 루틴 n개 중 m개"를 보여 준다.
- 알림: 전체 휴식인 날은 예약하지 않고, 유지하는 날은 그 루틴만 예약한다(기기에서 끈 루틴은 그대로 울리지 않는다).
- 휴가인 날에는 오늘 화면의 항목 추가([+])를 열지 않는다(새 항목이 숨겨지므로).
- **구버전 호환**: 이미 배포된 앱(Mac 1.5.1, iOS 1.0.0 빌드 3)은 새 칸을 모르지만 휴가 자체는 그대로 읽는다(전체 휴식으로 보이고 루틴은 평소처럼 표시). 구버전에서 그 휴가를 수정·저장하면 `kept`가 빠진 값이 새로 적혀 선택이 사라진다(전체 휴식이 된다). 세 기기를 모두 새 버전으로 올리면 해소된다.

### macOS 업데이트(설정 → 정보)

- 버전 아래에 "업데이트" 줄을 넣었다(`UpdateSettingsRow`). 준비 전에는 "준비 중" 안내와 [릴리스 페이지 열기], 준비되면 메뉴와 같은 [업데이트 확인…](같은 `DaylogUpdater.checkForUpdates()`).
- Sparkle 대리자(`UpdaterEvents`)가 확인 결과를 최신 / 새 버전 / 실패로 모아 설정에 한 줄로 남긴다(`UpdateCheckOutcome`). 새 버전·변경 사항·설치 승인·오류 창은 Sparkle 표준 창이 맡는다.
- **활성화하지 않았다.** `DaylogUpdatesEnabled=false`, 공개 키 없음, appcast 미게시 그대로. 필요한 승인과 버전 정책은 [UPDATES.md](UPDATES.md).

### iPhone·iPad 메뉴 색

- 아래 탭: 메뉴 색(`AppStore.Section.tint`)을 입힌 아이콘을 넘긴다(`TabIcon`). 고른 탭은 채운 아이콘·진한 색, 나머지는 선 아이콘·옅은 색. 시스템 `TabView`와 탭 막대는 그대로다.
- iPad 사이드바: 고르지 않은 메뉴의 아이콘도 메뉴 색(옅게). macOS 사이드바는 전과 같다(고른 메뉴만 색, 나머지는 회색).
- 색 값은 바꾸지 않았다. 식사와 캘린더가 같은 주황, 설정은 파랑이다.

### iPhone 주요 지표 카드

- 원인: 지표 칸의 숫자(`fixedSize`)와 요일 막대가 칸 너비보다 넓어 격자가 화면 밖으로 늘어났고, 그 너비가 오늘 화면 전체를 밀어냈다.
- 좁은 화면용 칸(`StatTile.isCompact`): 여백·숫자를 줄이고 숫자는 넘치면 줄어든다. 제목·설명은 두 줄까지. 요일 막대는 좁게.
- `StatCardsGrid`: iPhone 두 열이 기본이고, 큰 글씨나 좁은 창이면 한 열(`compactColumns`). macOS와 넓은 iPad의 칸은 그대로다.
- "최근 7일" 날짜가 큰 글씨에서 두 줄로 나뉘던 것도 줄여서 한 줄에 맞췄다.

### 검증

- 단위 테스트 368개 통과(휴가 정책·호환성·알림·위젯·통계 14개, 업데이트 결과 2개, 지표 열 수 1개 추가).
- 화면(시뮬레이터·검증 번들): iPhone 17 Pro에서 휴가 등록 → 전체 휴식(루틴 숨김) → 시트에서 루틴 선택 → 저장 → 선택 루틴만 표시 → 체크 → 위젯 스냅샷 파일 확인 → 해제 후 평소 목록·달성률 복원. macOS 검증 번들에서 전체 휴식·선택 유지·휴가 메뉴·설정의 업데이트 줄. iPad 사이드바 색. iPhone SE(375pt)·iPhone 17 Pro·가장 큰 기본 글자 크기·다크에서 지표 카드.
- 하지 못한 것: 실기기, 실제 알림 도착과 위젯 그림(예약 계획과 스냅샷 파일까지만 확인), macOS 메뉴 막대 팝오버 화면, 기기 간 동기화로 선택이 넘어가는지(같은 `FieldEdit` 경로라는 것까지만), 구버전 앱에서 새 휴가를 실제로 열어 보는 것(형식 호환은 테스트), Sparkle의 실제 확인·설치·실패(꺼져 있어 실행되지 않음), [릴리스 페이지 열기] 누르기, iPad 다크·좁은 창, 손쉬운 사용 글자 크기(AX1 이상).

## 배포: Mac 갱신, TestFlight 빌드 4, GitHub DMG 교체 (2026-10-12)

커밋 `3c48d20`(휴가 중 루틴, 설정의 업데이트 줄, iOS 메뉴 색, 주요 지표 카드, iOS 빌드 번호 4)을 세 곳에 올렸다.

- Mac: `Tools/update.sh`로 `/Applications/Daylog.app` 교체(1.5.1, Developer ID, iCloud Production), 실행 확인.
- GitHub: 같은 실행에서 공증한 DMG로 `v1.5.1` 릴리스의 파일을 교체(SHA-256 `93752d1b…e31cf`, 빌드 기준 커밋 `3c48d20`). "교체 → 공증 → DMG 교체"가 한 번에 이어진 첫 실행이다. 릴리스 설명에 휴가 중 루틴과 설정의 업데이트 줄을 더했다.
- TestFlight: iOS 1.0.0 (4) 업로드(15:08, Delivery UUID `22ff584f-cb65-41d4-93da-0ba8849b98ba`). 올린 IPA에서 iCloud Production, aps production, `UIBackgroundModes = remote-notification`, 빌드 4 확인. 다음에 올릴 때는 빌드 번호 5.
- 세 기기가 모두 새 버전이 되기 전에는 구버전에서 휴가를 수정하면 선택한 루틴이 지워진다(전체 휴식이 된다).

## macOS 앱 안의 업데이트(Sparkle) 완성 — 켜기 전 단계 (2026-10-12)

자세한 내용과 절차는 [UPDATES.md](UPDATES.md). **배포판에서는 아직 꺼져 있다**(배포용 서명 키를 만들고 첫 릴리스를 올리는 데 승인이 필요하다). 실제 앱·GitHub 릴리스·키체인은 건드리지 않았다.

- 앱: 설정 → 정보에 [업데이트 확인…], "자동으로 업데이트 확인" 스위치, 상태·마지막 확인 시각. 메뉴와 같은 동작. 하루 간격 자동 확인(`SUEnableAutomaticChecks`), 설치는 늘 사용자 승인.
- 샌드박스 권한: Sparkle 설치 도구와 통신하는 mach-lookup 예외(`-spks`, `-spki`)를 `Config/Daylog.entitlements`·`Verify.entitlements`에 추가. iCloud 권한은 그대로.
- `UpdateConfiguration`: 배포 피드(GitHub latest의 appcast)만 받고, 시험·검증 번들에서만 `http://127.0.0.1/appcast.xml`을 허용한다.
- 스크립트: `Tools/appcast.sh`(appcast 생성과 DMG 대조 검사), `Tools/bump-version.sh`(Mac 버전·빌드 번호), `Tools/release.sh`(Sparkle이 켜져 있으면 appcast 생성, 중복 버전 거부, 초안 → 확인 → 공개 → 공개 주소 확인), `Tools/update.sh`(켜진 뒤에는 게시한 버전을 바꾸지 않음), `Tools/update-test.sh`(격리 설치 시험).
- 격리 시험(번들 `com.daylog.updatetest`, 이 Mac의 피드, 시험 전용 키): 9.0.0 → 9.0.1 설치, EdDSA 검증 통과, 기록 보존, 그리고 같은 버전·서명 불일치·404·네트워크 없음에서 설치되지 않는 것까지 확인. 화면을 눌러서 하는 흐름(설치 버튼, 자동으로 다시 열림, 내려받는 중 취소)은 하지 못했다.
- 현재: 설치된 앱 1.5.1 (1)은 업데이트가 꺼진 빌드라 첫 전환은 수동 설치가 필요하다. 로그인 키체인에 Sparkle 키 없음.
- 검증용 스크립트 명령 추가: `onboardingDone`, `forgetUpdateCheck`, 실행 인자 `-DaylogDebugSettings <갈래>`(Debug 빌드 전용).

## Mac 1.5.2 (2): 앱 안의 업데이트 활성화와 첫 appcast 게시 (2026-10-12)

사용자 승인(키 생성, 활성화, 버전 올리기, 게시, 이 Mac 교체)에 따라 진행했다. iPhone·iPad(TestFlight 1.0.0 (4))는 건드리지 않았다.

- 서명 키: Sparkle EdDSA 키를 로그인 키체인에 만들었다. 공개 키만 `Config/Daylog-Info.plist`에 넣었다. 로컬 백업은 저장소 밖 `~/Library/Application Support/DaylogRelease/`(600)에 있고 키체인의 키와 같은 서명을 낸다. **기기 밖 백업은 아직 없다**(사용자가 옮겨야 한다). 방법과 복구는 [UPDATES.md](UPDATES.md) "서명 키".
- 버전: Mac 1.5.2 (2), 커밋 `a7d3377`. 릴리스 노트 `docs/releases/v1.5.2.md`.
- 빌드: 커밋 `23b540b`에서 Developer ID 서명 → 공증·스테이플 → Gatekeeper 통과. Sparkle 안의 도구들(Installer·Downloader·Autoupdate·Updater)도 같은 팀 서명. iCloud Production, 번들 ID·팀 그대로.
- GitHub: `v1.5.2`를 새로 게시(DMG `Daylog-v1.5.2-macOS.dmg`, SHA-256 `e0f45129…8d1244`, 그리고 `appcast.xml`). `v1.5.1`의 자산은 그대로다.
- 공개 주소 확인: 내려받은 DMG의 체크섬·크기가 같고, appcast의 EdDSA 서명이 그 DMG에 맞고, 안의 앱이 공증 통과·1.5.2 (2). 피드 주소(`…/releases/latest/download/appcast.xml`)가 새 appcast와 같다.
- 이 Mac: `Tools/update.sh`로 `/Applications/Daylog.app`을 1.5.2 (2)로 교체, 실행·서명·iCloud Production 확인. 직전 앱은 `build/update/previous.app`, 교체 전 사본은 `build/update/backup-1.5.1-before-sparkle.app`.
- 겪은 문제 둘(모두 스크립트, 고침):
  1. 게시 전 검사에서 Sparkle 도구의 서명을 `codesign | grep -q`로 봐서 정상인데도 실패로 판정했다(pipefail). 출력을 받아 두고 보게 고쳤다. 첫 공증 빌드는 게시 전에 멈췄고 다시 빌드했다.
  2. 게시 직후 피드 주소가 2분쯤 이전 릴리스(404)를 가리켰다. 게시 직전에 그 주소로 이전 appcast를 받아 본 것이 GitHub에 잠깐 기억됐기 때문이다. 이전 appcast는 `gh release download`로 받고, 피드 확인은 더 오래 기다리게 고쳤다. 릴리스 자체는 정상 게시됐다.
- 남은 확인: 운영 경로의 [업데이트 확인] → [설치] → 자동으로 다시 열림은 1.5.3을 올릴 때 한다. 다른 Mac은 1.5.2를 한 번 수동 설치해야 한다.

## iPhone·iPad 스플래시 애니메이션 (2026-10-12)

배포하지 않았다(TestFlight·Mac 그대로). macOS에는 스플래시가 없다. 캡처와 짧은 녹화는 `docs/splash/`.

- 구성: `Daylog/Views/Splash/SplashTimeline.swift`(장면 순서·시간, 한 번만 트는 규칙)와 `SplashView.swift`(iOS 전용 SwiftUI). `RootView`가 실제 화면 위에 덮어 보여 주고, 끝나면 걷는다. 외부 라이브러리·타이머 없음(장면마다 한 번의 `withAnimation`).
- 장면(약 1.08초): 한가운데 작은 잎사귀 → 커지며 원이 퍼짐(0.02초~) → 잎사귀가 올라가고 "Daylog"와 "하루를, 조금 더 가볍게"가 나타남(0.24초~) → 가볍게 흔들리다 멈춤(0.58초~) → 걷히며 실제 화면(0.86~1.08초).
- Launch Screen: 정적인 화면으로 두었다. `Config/DaylogiOS-Info.plist`의 `UILaunchScreen`이 스플래시와 같은 배경색(`SplashBackground`)에 같은 잎사귀(`SplashLeaf`, 64pt)를 한가운데에 둔다. 스플래시의 첫 장면이 이 그림과 같아서 넘어올 때 튀거나 번쩍이지 않는다(자동 생성 설정 `INFOPLIST_KEY_UILaunchScreen_Generation`은 뺐다).
- 색은 앱의 테마 설정이 아니라 시스템의 라이트/다크를 따른다(Launch Screen이 시스템 모드로 그려지므로). 시스템은 다크인데 앱 테마가 라이트여도 어두운 스플래시에서 밝은 홈으로 걷힌다.
- 앱 준비: 저장소는 화면이 뜨기 전에 이미 열려 있어(`AppLaunch.make`) 스플래시가 초기화를 기다리게 하지 않는다. 밑의 화면은 처음부터 그려져 있고, iCloud 첫 가져오기 같은 기존 로딩 표시는 홈에서 그대로 보인다. 기록·설정은 건드리지 않는다.
- 한 번만: 프로세스가 시작한 뒤 첫 화면에서만 튼다(`SplashPolicy.claim`). 백그라운드에서 돌아올 때, iPad의 두 번째 창에서는 틀지 않는다. 화면이 보이기 시작하면(비활성 단계부터) 바로 시작하고, 백그라운드로만 실행돼 1.5초 안에 보이지 않으면 애니메이션 없이 걷는다.
- 시작 안내: 스플래시가 떠 있는 동안에는 올리지 않고, 걷히기 시작할 때 이어서 올라온다.
- 동작 줄이기: 커지거나 움직이지 않는다. 글자만 나타났다가 화면째로 걷힌다(약 0.72초).
- 접근성: 스플래시는 접근성 요소에서 뺐다. 밑의 화면은 처음부터 VoiceOver로 읽힌다.
- 검증용: `-DaylogDebugSplashHold <start|grown|logo|settled>`(한 장면에서 멈춤), `-DaylogDebugSplash off`(스플래시 없이 실행). Debug 빌드 전용.

### 검증(시뮬레이터, 녹화를 프레임으로 풀어 확인)

- iPhone 17 Pro 라이트·다크: Launch Screen의 잎사귀 위치가 스플래시 첫 장면과 같고, 흰색·검은색 화면이 끼지 않는다. 스플래시 시작부터 홈이 다 보일 때까지 약 0.95~1.0초.
- 기존 사용자(기록이 있는 저장소): 스플래시 → 홈, 기록과 카드 설정 그대로. 강제 종료 후 재실행마다 재생.
- 신규 설치(iPhone 17): 스플래시 → 시작 안내.
- 백그라운드 복귀: 같은 프로세스로 돌아오고 재생되지 않는다.
- 동작 줄이기(시뮬레이터 설정): 확대·이동 없이 페이드만.
- 시스템 다크 + 앱 테마 라이트: 어두운 스플래시에서 밝은 홈으로.
- iPad Pro 11 세로: 가운데 정렬, 비율에 맞춰 조금 크게.
- 시작 시간: 스플래시를 끄고 잰 실행(Launch Screen 뒤 바로 홈)과 비교해, 홈이 보이는 시점이 약 0.8~0.9초 늦다(스플래시 길이만큼). 앱의 초기화 구간(Launch Screen이 서 있는 시간)은 양쪽이 같았다(시뮬레이터, Debug 빌드). 첫 화면이 만들어진 뒤 약 0.1초에 스플래시가 움직이기 시작한다.
- 하지 못한 것: 실기기, iPad·iPhone 가로(이 Mac의 시뮬레이터는 회전이 안 된다), 위젯을 눌러 실행(`daylog://`는 URL 스킴으로 등록돼 있지 않아 명령으로 열 수 없다), 알림의 [완료]로 화면 없이 실행된 경우, 저장소 열기가 오래 걸리는 상황(그동안은 Launch Screen이 보이고 그 뒤에 스플래시가 이어지는 구조), VoiceOver 실제 조작, Release 빌드에서의 시간.

## 모바일 2: 시작 안내의 알림 안내, 내비게이션 색, 카드 잘림 점검 (2026-10-12)

배포하지 않았다. 캡처는 `docs/onboarding/`. SwiftData·CloudKit 변경 없음(알림 설정은 전과 같이 이 기기의 `UserDefaults`).

### 시작 안내 3단계의 알림 안내 (iPhone·iPad)

- 3단계("준비됐어요") 아래에 "루틴 시간을 놓치지 마세요 / 설정한 시간에 Daylog가 알려드려요."와 [나중에] [알림 켜기]. macOS의 시작 안내는 그대로다.
- [알림 켜기]를 눌렀을 때만 시스템 권한을 묻는다(`RoutineNotifications.setEnabled(true)`, 설정의 스위치와 같은 경로). 허용되면 이 기기의 루틴 알림을 켜고 예약을 맞춘다. 루틴별로 꺼 둔 알림은 건드리지 않는다. 결과(허용: 시간이 정해진 루틴 n개 / 거부: 앱은 그대로 쓸 수 있음)를 보여 주고 [오늘 시작하기]로 오늘 화면에 간다.
- [나중에]: 권한을 묻지 않고 설정도 바꾸지 않은 채 오늘 화면으로 간다.
- 다시 묻지 않는 경우(`OnboardingNotificationOffer`): 이미 켜져 있으면 안내만, 시스템에서 거부돼 있으면 설정 앱 안내만, 상태를 모르면 아무것도 보여 주지 않는다. 이때는 [오늘 시작하기]만 나온다.
- 2단계에서 루틴을 만들지 않아도 3단계로 간다(전과 같다). "시작 안내 다시 보기"로 열어도 루틴·설정은 바뀌지 않는다.

### 내비게이션 색 (iPhone 탭, iPad 사이드바)

- iPhone·iPad의 메뉴 색(`AppStore.Section.navigationTint`): 오늘 민트, 루틴 파랑, 식사 코랄, 통계 보라, 캘린더 주황, 휴가 코랄, 설정 중립 회색. macOS는 전과 같다(식사 주황, 설정 파랑, 고르지 않은 메뉴는 회색).
- iPad 사이드바에서는 식사와 휴가가 같은 코랄이다(아이콘 모양으로 구분). iPhone 탭에는 휴가가 없다.
- 고친 것: 탭 막대에 건 메뉴 색이 화면 안의 단추·스위치·링크까지 물들이고 있었다(설정 탭에서는 스위치가 회색으로 보일 뻔했다). 탭 내용에는 앱의 강조색을 되돌려 걸었다. 탭 막대만 메뉴 색을 쓴다.
- 시스템 탭 막대의 한계: 고르지 않은 탭의 글자색은 시스템이 정한다(회색). 아이콘만 메뉴 색을 입힐 수 있었다. 탭 막대를 직접 그리지는 않았다.

### 대시보드 카드 잘림 점검 (iPhone)

- 숨겨 둔 카드를 포함해 11개를 모두 켜서 iPhone 17 Pro(402pt)와 iPhone SE(375pt)에서 봤다. 가로로 넘치는 카드는 없었다(주요 지표는 2×2, 앞선 작업에서 고친 대로).
- 찾아서 고친 것: "루틴별 달성률"의 퍼센트 칸이 좁아 "100%"가 두 줄로 나뉘었다 → 칸 너비를 글자 크기에 맞췄다. 같은 카드의 긴 루틴 이름은 터치 화면에서 두 줄까지 보여 준다(macOS는 한 줄 + 도움말 그대로).

### 검증(시뮬레이터에서 직접 조작)

- iPhone 17 신규 설치: 스플래시 → 시작 안내 → 2단계 "나중에 설정하기" → 3단계. [알림 켜기] → 시스템 창 → 허용 안 함 → 안내 → 오늘 화면. 다시 실행하면 시작 안내가 뜨지 않는다.
- 새로 설치해 [나중에]: 시스템 창 없이 오늘 화면. 이어서 설정 → 정보 → "시작 안내 다시 보기" → [알림 켜기] → 허용 → "시간이 정해진 루틴 1개" 안내 → 오늘 화면. 설정 → 알림에 켜짐·허용됨·예약 60개. 루틴 2개는 그대로.
- iPhone 탭: 라이트·다크, 선택·비선택, 설정 탭(회색) 선택 상태. 화면 안의 단추·스위치는 민트. 식사 표시를 끄면 탭이 네 개(오늘·루틴·통계·설정), 다시 켜면 다섯 개.
- iPad Pro 11: 사이드바 색과 설정 선택 상태, 시작 안내 3단계와 [나중에], 창을 좁혀 아래 탭으로 바뀌는 것과 좁은 창의 주요 지표 2×2.
- macOS 검증 번들: 사이드바·대시보드 그대로.
- 하지 못한 것: 실기기, iPad에서 [알림 켜기] 뒤의 시스템 창, 이미 거부된 상태에서 시작 안내를 다시 여는 화면(규칙은 단위 테스트), 큰 글씨에서의 3단계 화면, 실제 알림 도착.

## 모바일 OTA: iPhone·iPad 원격 UI 설정 (2026-10-12)

자세한 내용은 [MOBILE_OTA.md](MOBILE_OTA.md). **아무것도 게시하지 않았다**(Production·Development 주소 모두 비어 있고, 앱은 내장 기본값을 쓴다). TestFlight도 올리지 않았다. macOS는 그대로다.

- 원격 JSON(`RemoteConfig/mobile-ui.json`)으로 미리 만들어 둔 표시 설정만 바꾼다: 대시보드 기본 카드 배치·간격·여백, 허용된 강조 색, 카드 스타일 세 가지, 문구 여섯 개, 표시 두 가지. 코드·기록·동기화·개인 설정은 바꿀 수 없다.
- 주소: GitHub 릴리스 자산(Production `mobile-config`, Development `mobile-config-dev`). push만으로는 적용되지 않고 `Tools/mobile-config.sh publish --confirm <버전>`을 실행해야 바뀐다(승인 필요).
- 앱: `MobileUIConfigStore`가 실행·복귀 때(1시간 간격)와 [UI 설정 새로고침] 때 ETag로 확인한다. 크기·형식·앱 빌드·허용값을 검사하고, 마지막 유효 설정을 캐시에 둔다. 스스로 받은 설정은 다음 실행 때, 직접 새로고침한 설정은 바로 적용한다. 강조 색은 다시 열 때 바뀐다.
- 사용자 우선: 카드 배치를 직접 바꾼 기기는 원격 기본 배치가 건드리지 않는다(`DevicePreferences.isLayoutCustomized`, 새 키 `device.dashboard.customized`). 이전에 저장된 배치는 내장 기본값과 다르면 사용자 것으로 본다.
- 함께 고친 것: iPad 설정 화면에서 두 칸을 놓기에 좁으면(세로 방향, 줄인 창) 오른쪽 칸의 글자가 세로로 쪼개졌다 → 그 폭에서는 목록에서 들어가는 방식으로 바꿨다(macOS는 그대로 두 칸).
- 공용 코드의 변화: `Card`의 기본 안쪽 여백과 테두리를 환경값(`mobileUI`)에서 읽는다. macOS에서는 늘 내장값(18, 옅은 테두리)이라 모습이 같다.
- 검증: 단위 테스트 16개 추가(전체 395개 통과). 이 Mac의 시험 서버와 iPhone 17 Pro·iPad 시뮬레이터로 변경 → 즉시 반영 → 재실행 유지 → 오프라인 → 잘못된 파일 거부 → 되돌리기 → 사용자 배치 우선 → 다음 실행 때 적용을 확인했다. 캡처는 `docs/mobile-ota/`.
- 하지 못한 것: 실제 주소로 받기와 `publish`·`rollback` 실행(게시 전), 실기기, Release 빌드에서의 동작.

## 배포: TestFlight 빌드 5, 모바일 UI 설정 Production v1 (2026-10-12)

사용자 승인에 따라 진행했다. Mac 앱·GitHub의 앱 릴리스·Sparkle appcast는 건드리지 않았다.

- iOS 1.0.0 (5)를 TestFlight에 올렸다(21:02, Delivery UUID `423b08f1-3cb8-4554-b572-48dc5541988f`, 커밋 `689a020`). 올린 IPA에서 번들 ID `com.mungyubin.daylog.ios`, App Group, iCloud Production, aps production, `UIBackgroundModes`, 정적 Launch Screen을 확인했다. Release 바이너리에는 Production 설정 주소만 들어 있다. 다음에 올릴 때는 빌드 번호 6.
- 빌드 4 이후로 SwiftData 모델·스키마·동기화 코드·권한 파일은 바뀌지 않았다(`Daylog/Models`에서는 `DevicePreferences`만: 이 기기의 `UserDefaults`에 `device.dashboard.customized`가 추가됨).
- 빌드 5에 새로 들어간 것: 스플래시, 시작 안내의 알림 안내, 메뉴 색, 달성률 카드 수정, 원격 UI 설정, iPad 설정의 좁은 폭 배치.
- 모바일 UI 설정 Production `configVersion 1`을 게시했다(릴리스 `mobile-config`, 사전 출시). 내용은 내장 기본값과 같다. 공개 주소의 파일이 저장소 파일과 같고, Release 빌드가 실제 주소에서 받아 적용하며, 적용 전후 화면이 같은 것을 시뮬레이터에서 확인했다. 기록은 [MOBILE_OTA.md](MOBILE_OTA.md) "게시 기록".
- App Store Connect의 처리 상태는 API 키가 없어 확인하지 못했다(TestFlight 앱에서 빌드 5가 보이는지 확인 필요).
- 게시 뒤 고친 것(다음 빌드부터): 설정 줄의 "강조 색은 앱을 다시 열면 바뀌어요"가 색이 바뀌지 않았을 때도 나왔다 → 색이 실제로 달라졌을 때만 보이게 했다.

## 스플래시 시간을 원격 UI 설정으로 (2026-10-12)

- `splash.duration`(초, 기본 1.5, 0.5~2.0)을 원격 UI 설정에 추가했다. 스플래시는 앱을 켤 때 받아 둔 설정의 값으로 재생하므로 바뀐 값은 다음 실행부터 적용된다. 값이 없거나 범위를 벗어나면 1.5초.
- 기본 재생 시간이 약 1.1초에서 1.5초로 바뀌었다(장면 비율은 그대로).
- 저장소의 `RemoteConfig/mobile-ui.json`은 `configVersion 2`(값 1.5)가 됐다. 게시하지 않았다(게시된 것은 v1). TestFlight도 올리지 않았다(이 칸은 빌드 6부터 읽는다).
- 관련 테스트(SplashTests, MobileUIConfigTests)와 iOS 빌드만 확인했다. 설정 방법은 [MOBILE_OTA.md](MOBILE_OTA.md) "스플래시 시간 바꾸기".

## 배포: TestFlight 빌드 6 (2026-10-12)

- iOS 1.0.0 (6)을 TestFlight에 올렸다(커밋 `2277090`). 올린 IPA에서 번들 ID, App Group, iCloud Production, aps production, 빌드 6을 확인했다. 다음에 올릴 때는 빌드 번호 7.
- 빌드 5 이후 들어간 것: 스플래시 시간 설정(`splash.duration`, 기본 재생 시간 1.5초), 설정 줄의 강조 색 안내 수정.
- Mac 앱과 모바일 UI 설정(Production v1)은 그대로다. 저장소의 설정 파일 v2는 게시하지 않았다.

## 알림 안내를 한 번은 보게 (iPhone·iPad, 2026-10-12)

배포하지 않았다(TestFlight·OTA 게시 없음). macOS는 그대로다. SwiftData·CloudKit·루틴별 알림 설정은 건드리지 않았다.

- 문제: 알림 안내가 시작 안내 3단계에만 있어, 시작 안내를 닫아 버린 사람과 이전 버전부터 쓰던 사람은 보지 못했다.
- 따로 띄우는 안내(`NotificationGuideSheet`)를 추가했다. 3단계와 같은 본문(`NotificationGuideCard`)과 같은 동작(`NotificationGuideActions.enable`)을 쓴다: [알림 켜기]를 눌렀을 때만 권한을 묻고, [나중에]는 아무것도 바꾸지 않는다.
- 띄우는 규칙(`NotificationGuidePolicy`): 스플래시와 시작 안내가 끝난 뒤, 이 기기에서 안내를 본 적이 없고, 시스템 권한이 아직 미결정이고, Daylog에서 루틴 알림을 직접 켜거나 끈 적이 없을 때만 한 번. 이미 허용·거부했거나 직접 정한 사람은 묻지 않고 끝난 것으로 적는다.
- 3단계에서 안내를 본 사람에게는 따로 띄우지 않는다(중복 없음). 어떻게 닫든 다시 띄우지 않는다.
- 기기별 표시: `device.notificationGuideCompleted`(`UserDefaults`). 직접 정했는지는 `RoutineNotifications.hasExplicitChoice`(기존 `routineNotificationsEnabled` 키가 있는지).
- 이미 거부된 상태의 안내에는 [알림 설정 열기]를 넣었다(다시 물어도 시스템 창이 뜨지 않으므로).
- 원격 UI 설정의 `features.onboardingNotificationGuide`를 끄면 이 안내도 띄우지 않는다.
- 검증(시뮬레이터에서 직접 조작): iPhone 17 Pro에서 새로 설치 → "안내 닫기" → 안내 → [나중에] → 시스템 창 없이 홈, 재실행 때 반복 없음. 기존 사용자(안내 표시만 지움) → 스플래시 뒤 안내 → [알림 켜기] → 허용 → 예약 60개, 루틴·식사 기록 그대로. 이미 허용한 상태에서는 안내 생략. 새로 설치 → 안내 → 허용 안 함 → 안내 문구 → 홈, 재실행 때 반복 없음. iPad에서 새로 설치 → 시작 안내 3단계의 안내 → [나중에] → 홈, 따로 뜨는 안내 없음(재실행 포함).
- 관련 테스트(OnboardingNotificationTests 등)와 iOS 빌드만 확인했다. 하지 못한 것: 실기기, 이미 거부된 상태의 화면과 [알림 설정 열기], iPad에서 따로 뜨는 안내와 시스템 창, 휴가 데이터가 있는 저장소에서의 확인(루틴·식사만 봤다).

## 모바일 UI 설정 Production v2 게시 (2026-10-12)

- 사용자 요청("ota 올려줘")으로 `configVersion 2`를 게시했다. v1과의 차이는 `splash.duration: 1.5` 칸 하나이고, 빌드 6의 기본값과 같아 화면은 달라지지 않는다.
- 공개 주소의 파일이 저장소 파일과 같고(SHA-256 `0ecb56dc…25328`), 릴리스 `mobile-config`는 사전 출시 그대로, 최신 앱 릴리스는 `v1.5.2`, Mac의 appcast는 바뀌지 않았다.
- 이 게시는 설정 파일만 바꾼다. 알림 안내를 한 번 띄우는 변경(`0577fe2`) 같은 앱 코드는 TestFlight 빌드로만 전달되며, 아직 올리지 않았다(올라가 있는 것은 빌드 6).

## Phase 5-A: 루틴 건너뛰기·루틴별 최근 기록·macOS 사이드바 색 (2026-10-13)

배포하지 않았다(TestFlight·DMG·OTA 없음). 실제 앱과 실제 기록은 건드리지 않았다. 설계는 [ARCHITECTURE.md](../ARCHITECTURE.md) "루틴 건너뛰기와 루틴별 최근 기록".

- **건너뛰기**: 완료/미완료에 건너뛰기를 더했다. 체크 행의 ⋯ 메뉴와 컨텍스트 메뉴에서 [오늘 건너뛰기] / [건너뛰기 취소]. 체크 칸의 완료·취소 동작은 그대로이고, 건너뛴 항목을 체크하면 완료가 된다.
  완료한 항목을 건너뛰면 건너뛰기로 바뀌고, 건너뛰기를 취소하면 미완료가 된다. 메뉴 막대(macOS)와 큰 위젯도 같은 표시를 쓰고, 건너뛴 루틴은 다음 루틴·오늘 알림에서 빠진다.
- **데이터**: SwiftData·CloudKit 스키마 변경 없음, 마이그레이션 없음. 기존 체크 편집 기록(`FieldEdit`의 `check:` 칸)에 값 `"skip"`을 더했을 뿐이다.
  예전 앱(Mac 1.5.2 이하, iOS 빌드 6 이하)은 이 값을 미완료로 읽고, 거기서 체크·해제해도 기록이 깨지지 않는다(표시만 안 보인다).
- **통계**: 달성률·연속 달성일 계산은 그대로(건너뛰기 = 미달성). 통계 화면에 "루틴별 최근 기록" 카드를 더했다: 루틴마다 최근 14번(좁은 화면 7번)의 완료 / 건너뛰기 / 기록 없음 / 진행 중 / 휴가와 개수 요약.
- **사이드바**: macOS의 회색 아이콘에 메뉴 색을 입혔다. macOS·iPad 사이드바와 iPhone 탭이 같은 색을 쓴다(오늘 민트, 루틴 블루, 식사 코랄, 통계 퍼플, 캘린더 오렌지, 휴가 청록, 설정 중립 회색).
- 테스트: `RoutineSkipTests` 21개 추가(전환, 재실행, 지난 날짜, 예전 앱 호환, 기기 간 판정, 달성률·연속 달성, 최근 기록, 다음 루틴·알림·위젯 스냅샷).
  전체 회귀 421개(57개 스위트) 통과. macOS Debug·Release, iOS 시뮬레이터 Debug·Release 빌드 성공.
- 검증(검증 전용 빌드와 시뮬레이터에서 직접 조작. 캡처는 `docs/phase5a/`):
  - macOS(`com.daylog.verify`, 45일치 시험 데이터): 완료 → 건너뛰기, 지난 날짜 건너뛰기, 재실행 후 유지, 건너뛴 항목의 체크 칸을 눌러 완료 → 다시 눌러 미완료, 통계 카드, 사이드바 색, 라이트·다크.
  - iPhone 17 Pro: ⋯ → [오늘 건너뛰기], ⋯ → [건너뛰기 취소], 건너뛴 항목 체크, 재실행 후 유지, 다음 루틴 카드에서 빠짐, 통계 카드(다크).
  - iPad Pro 11: 사이드바 색, ⋯ → [오늘 건너뛰기], 통계 카드(다크).
- 하지 못한 것: macOS에서 ⋯ 메뉴와 오른쪽 클릭 메뉴를 실제로 누르기(배경 제어로는 메뉴와 마우스 올리기를 다룰 수 없다. 같은 동작을 스크립트와 iOS의 같은 코드로 확인했다),
  macOS 메뉴 막대 팝오버와 위젯에서의 건너뛰기 표시(스냅샷 값은 테스트로 확인), 알림이 실제로 울리지 않는지(예약 계획은 테스트로 확인), 실기기, VoiceOver 동작, 두 기기 사이의 실제 iCloud 동기화, 예전 버전 앱과 섞어 쓰는 실제 상황(판정 규칙은 테스트로 확인).

## 다음 작업

1. 로컬 main 및 원격 상태를 확인하고 기존 변경을 보존한다. A/B/C/D/F/G의 중복 개발은 하지 않는다.
2. 배포 담당 승인 후 docs/UPDATES.md에 따라 키·샌드박스 설치 통신 권한·appcast/DMG 게시·실제 업데이트 설치 검증을 수행한다.
3. 실기기 iPhone/iPad, 최소 지원 OS, 실제 VoiceOver·Reduce Motion과 다기기 CloudKit를 추가 검증한다. (iOS Files 가져오기·내보내기는 Phase 4-A에서 시뮬레이터로 확인했다.)
4. 실기기에서 위젯 체크 직후 위젯 그림이 바로 바뀌는지 확인한다(Phase 4-A의 1번 문제). 바뀌지 않으면 표시 방식을 다시 정한다.

## 범위 밖 및 보류

- 전체 JSON 복원, 카드 크기 조절·자유 배치는 제외.
- CloudKit Production·실기기 동기화, 실제 Sparkle 서명/변조 거부/설치, Developer ID archive/export·공증·GitHub Releases 게시 미수행.
- Sparkle 개인 키는 생성하지 않았으며 저장소에 없다. `DaylogUpdatesEnabled=false`, 공개 키 비어 있음. 기존 서명 인증서/팀/CloudKit entitlements는 변경하지 않았다. 파일 가져오기·내보내기에 필요한 사용자 선택 파일 read/write 권한만 추가했다.
- 테스트 로그는 /tmp에 있으므로 영구 보존되지 않는다. 핵심 결과와 재개 조건은 본 문서에 기록한다.
