# Daylog 진행 기록

최종 갱신: 2026-10-12(Phase 4-A 품질 점검 추가). 다음 세션은 이 문서 → PHASE3.md → git status/diff 순서로 확인한다.

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
