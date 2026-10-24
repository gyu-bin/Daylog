# RoutiMori 피오 최종 Production Pass — 2026-10-24

## 최종 판정: PARTIAL

실제 원화 제작·일반 렌더러 연결·네이티브 재생·성능 수정까지 진행했다. 클라우드14종의 눈/손·태블릿 리그와 기본 피오 낮 휴가의 좁은 눈 표현을 일반 Release 코드 경로에 연결했다. 휴가 전체 독립 손·음료·양쪽 로프 고정점, 홈10동작 전체의 Release 승격, 실제 구매부터 재실행까지의 종단 흐름은 완료하지 않았다. 사람의 최종 미적 승인과 Apple Sandbox는 별도다.

## 이번에 실제 구현한 것

1. 클라우드14종의 기존 채택 레이어를 production catalog로 비파괴 복사하고 receiving/trouble 일반 렌더러에 연결했다. 눈과 lid, 양손·태블릿 공통 hold joint가 움직인다. 선글라스 의상은 눈이 가려지는 의도적 예외다. 성공 장면은 기존 완성형 원화와 제한된 bounce를 유지한다.
2. 착용 상태는 기존 coordinator의 이미 결정된 의상·권한을 재사용한다. 권한 조회 중 숨김, 미보유 의상의 fallback을 유지한다. 제품 ID·StoreKit·구매 상태를 수정하지 않았다.
3. 휴가용 실제 생성 PNG3개를 제작했다. 음료2후보는 halo·크기·위치 불일치로 거절했다. 기본 낮 눈 복원 후보의 검수된2영역만 기존 전경 위에 사용하고 고해상도 열린 눈2장을 연결했다. 기본 밤과 유료13종은 기존 정상 전경 sway를 유지한다.
4. Mac cloud/vacation native host의 사용하지 않는 강한 NSClipView 조상 배열이 만든 참조 순환을 제거했다. 변경 전 실제 subtree 해제 검사 실패를 재현했고, 변경 후 해제 검사를 통과했다.
5. 동일 바이트의 cloud 이미지146개 이름을44개 canonical texture로 공유했다. 원화·좌표·등록은 그대로다. native decoded RGBA 동일성 검사를 별도 프로세스에서 통과했다.
6. 실제 화면 캡처·presentation 프레임·라이프사이클·성능 검사를 추가했다. 기존77개 중2개는 이미 존재하던26개 휴가 원화 등록과 다른 오래된 fixture 기대값을 바로잡았다. 앱 coordinator는 바꾸지 않았다.

## Phase별 상태

| 범위 | 상태 | 근거·한계 |
|---|---|---|
| 기준선·보호 | PASS | 시작 Git 상태/patch,761SHA 보존 기준선 확보 |
| 클라우드14종 production 연결 | PASS(범위 한정) | 일반 경로의1254×1254등록·presentation·정지·권한 adapter 검증. ready의 완전 독립 축하는 PARTIAL |
| 휴가 신규 원화 | PARTIAL | 기본 낮 눈만 채택. 새 음료2후보 FAIL·미적용 |
| 홈·장면 상태 | PARTIAL | 기존 홈 idle/tap 검사와14종 직접 렌더링. 구매→옷장→홈→cloud→휴가→재실행 전체 E2E는 NOT_TESTED |
| 14종×4장면 | PARTIAL | VISUAL-REVIEW의 표시/모션을 구분한56조합 매트릭스 |
| 전 기기 | PARTIAL | Mac 실제 창·iPhone17·작은 iPhone SE3·iPad mini 각12개 실제 앱 뷰 캡처. VoiceOver·회전·Split View 미실시 |
| 성능 | PARTIAL |10/20/50회·전후 동조건7검사. 장기 실기기 endurance 미실시 |
| 회귀 | PARTIAL | 기존77/77 및 관련 집중검사 통과. 모든 이전 실행 횟수를 고유 테스트로 합산하지 않음 |
| Release 패키지 | PASS(빌드) | Mac/iOS Simulator Release 빌드·production 리소스165개 누락0. 서명된 Release 실행 미실시 |

## Release 적용 범위

기본, 벚꽃, 여름휴가, 가을, 겨울, 할로윈, 크리스마스, 한복, 카페, 학생, 운동, 비 오는 날, 잠옷, 우주복: receiving/trouble production 등록14/14. 기존 Basic V1 fallback 유지. 세부 모션·의상별 검수는 VISUAL-REVIEW.md.

`release-package-validation.json`은 두 Release Assets.car에서 production catalog 전체165개 등록 존재와 DEBUG overhaul/layered 리소스 제외를 확인한다. 번들 ID는 Mac `com.mungyubin.daylog`, iOS `com.mungyubin.daylog.ios`로 기존 값이다. 운영 앱은 설치·교체하지 않았다. 네이티브 실험은 DEBUG test host에서 candidate/Overhaul 플래그 없이 일반 렌더러를 호출한 것이며, 이를 서명된 Release 런타임 검증으로 표현하지 않는다.

## 실제 검증과 결함 수정

- 중복 제거 실제 고유 테스트123개를 실행했다(XCTest37 + Swift Testing86). 여러 실행/플랫폼의 최신 관측을 합친 고유 수이며 단일123개 전체 suite 실행으로 표현하지 않는다. SKIP-only opt-in3개는 제외했다. iPhone17 최종9/9, 작은 iPhone SE3 화면검사1/1, iPad mini 화면검사1/1 PASS. 최신 기기별 관측에 남은 테스트 FAIL 없음. 실행 PASS와 시각적 완성도는 구분한다.
- 기존 단위·회귀77/77 PASS. 초기75/77 실패는 기존 휴가 등록을 반영하지 않은2fixture였고 기대값 수정 후 같은 집합 재검증했다.
- Mac 실제14종 cloud/home/vacation presentation5검사 PASS. 독립 리뷰에서168PNG를 직접 열어 확인했다. 최종 iPhone17·SE·iPad의 실제 앱 뷰36장도 각각 직접 검수했다. 캡처 범위에서 새 잘림·접합 결함은 관측하지 않았지만 AX5 스크롤/VoiceOver와 전체 동작 범위는 PARTIAL이다.
- Basic 낮 눈 Mac4검사, iPhone2검사 PASS. native open/closed/stopped/night 프레임을 직접 검수했다.
- Mac 성능 변경 전7/7, 변경 후7/7 PASS. 별도 alias/창·production 회귀6/6 PASS.
- 테스트 식별자 중복 제거 수·각 실행 결과·초기 실패와 수정 결과는 `test-inventory.md` / `.json`이 기준이다. 이전 보고의44는 플랫폼/재실행을 포함한 실행 횟수이므로77과 단순 합산하지 않는다.
- 초기 눈 sampler의 Mac Y좌표, blank CALayer clone, SwiftUI 테스트 host 유지, 창 노출 전 fixture 검사, 고정 시간만으로 눈이 열렸다고 가정한 iPhone 검사, AnyView 재사용 중 이전 cloud 상태 촬영을 발견했다. 실패 로그와 이미지는 보존했고 필요한 fixture와 좌표만 수정했다. 실제 애니메이션 타이밍을 바꾸거나 assertion을 삭제하지 않았다.
- 신규 검증 코드는 현재 SDK의 읽기 전용 ReduceMotion 환경값/CGImage cast 제약으로 중간 컴파일 실패가 있었다. 실패 로그와 최종 빌드를 구분했다.

초기 iPhone17·SE·iPad 동시 시도는 Simulator service hub 지연으로 테스트 메서드 실행 전 중단했다. 앱 실패로 세지 않았다. 이후 순차 실행한 세 최종 run은 모두 PASS다. 초기 iPhone 우주복 reopened 검사도 실제 presentation 상태 조건으로 수정 후14종 배치 전체 PASS. 캡처는 새 host와 실제 cloud glyph 상태 확인 후 다시 생성해 receiving/ready/trouble의 최종 상태를 확인했다.

## 성능과 접근성

동일한7개 native Mac 검사·새 프로세스·같은 순서에서 cloud14종 RSS peak는967.23→388.28MiB(59.86%감소). 이는 단회 전후 측정이며 실제 기기 전체 예산이나 CPU 개선을 보증하지 않는다. CPU표본의 신뢰구간이 겹쳐 개선 PASS를 주장하지 않는다. 각 측정 host/rig가 해제되고 detach 후 track0임을 확인했다.

Reduce Motion은 리그 설정·트랙 정지 검사로 확인했다. 실제 OS 설정 전환, VoiceOver 읽기/조작, 고대비, AX5에서 모든 버튼까지 스크롤 도달은 NOT_TESTED다. AX5 실제 캡처의 첫 viewport 아래 콘텐츠가 있다는 사실을 곧바로 앱 잘림 결함으로 단정하지 않는다.

## 이번 작업 파일

### 앱 코드·리소스
- `Daylog/Views/Onboarding/PioCloudCharacterRig.swift`: production 등록/appearance adapter, canonical texture loader
- `Daylog/Views/Onboarding/PioCloudSceneHost.swift`: Mac 조상 참조 순환 제거
- `Daylog/Views/Onboarding/RoutimoriSyncScene.swift`, `FirstSyncView.swift`: 일반 cloud 경로 연결
- `Daylog/Views/Dashboard/RoutimoriVacationScene.swift`: 기본 낮 눈 연결, Mac 참조 순환 제거
- `Daylog/Views/Dashboard/PioVacationIndependentEyes.swift`: 신규 좁은 눈 표현 리그
- `Daylog/PioCloudProduction.xcassets`:14등록·141복사PNG·alias manifest 추가(기존5PNG 보존)
- `Daylog/PioVacationProduction.xcassets`:3PNG 추가
- `output/pio-production-final-2026-10-24/vacation/`: 실제 생성 원본3개, 합격/거절 구분

### 테스트
- `DaylogTests/PioAppearanceTests.swift`: 기존26장 등록과 맞도록2fixture 수정
- `DaylogTests/PioVacationFinalArtworkTests.swift`
- `DaylogStoreKitTests/PioCloudProductionTests.swift`, `PioCloudCandidateReviewTests.swift`
- `DaylogStoreKitTests/PioCloudTextureAliasesTests.swift`, `PioVacationProductionTests.swift`
- `DaylogStoreKitTests/PioProductionFinalLifecycleTests.swift`, `PioProductionFinalVisualTests.swift`, `PioProductionFinalScreenTests.swift`

기존 사용자 미커밋 변경이 많은 프로젝트다. 위는 이번 개입의 명시적 목록이며 전체 git diff를 이번 변경으로 취급하지 않는다.

## 남은 차단·위험

1. 휴가 유료13종·밤 독립 눈, 손·팔·의상 속 몸통, 소품의 숨은 부분, 양쪽 해먹 고정점은 BLOCKED_ASSET/PARTIAL. 상세 제작명세·후보판정은 ARTWORK-RESULTS.md.
2. 현재 cloud hold는 두 손과 태블릿의 공통 joint다. 독립 손가락/자유로운 각 팔을 구현했다고 주장하지 않는다.
3. 홈10독립동작 전체와 cloud ready 독립 celebration의 production 승격은 미완료.
4. 실제 소유 의상으로 전체 장면 이동·즉시 종료/재실행·백그라운드 복귀 종단 검증은 이번에 실시하지 않았다. 기존 구매 회귀 테스트가 해당 사용자 흐름을 대체하지 않는다.
5. 실물 iPhone, 서명된 Release 실행, iPad 회전/Split View, 장기 성능, VoiceOver 실제 조작은 추가 필요.
6. StoreKit 알려진4실패(취소 오류 주입/중단 거래/환불 알림/unfinished잔존)는 별도 기존 문제로 유지한다. 이번 재실행·수정 없음. Sandbox NOT_TESTED.
7. 코드 리뷰에서 P0/P1 확인 없음. 현재 팩에는 없는 canonical 리소스 누락 상황의 원래 이름 fallback, UIKit 조상의 isHidden/alpha만 변경하는 경우의 visibility callback은 추가 하드닝/검증 후보이며 실제 앱 결함으로 재현하지 않았다.

## 검토 자료

- `REVIEW.html`: 실제 native 캡처와 후보 원화를 명시적으로 구분한 갤러리
- `VISUAL-REVIEW.md`:56조합·직접 검수 범위·캡처 결함
- `ARTWORK-RESULTS.md`:3신규 후보·채택영역·정확한6개BLOCKED계약 범위
- `PERFORMANCE.md`:실측 수치·환경·해제 증거
- `clips/cloud-basic-production-native-mac.mp4`:실제 presentation104프레임의 검토 영상
- `clips/iphone17-cloud-native-screen.mov`:초기 투명 component host의 진단 녹화. 완성된 cloud 전체화면/실물iPhone영상이 아님

보호761개 해시 변경0이며 기존 추가 자산935개도 변경·누락0이다(`preservation-after.json`, `previous-work-after.json`).26개 휴가 원본도 그 검증에 포함된다.

현재 결과는 시각 승인용 후보다. 커밋·푸시·배포·실제 결제·운영 데이터 변경은 하지 않았다.
