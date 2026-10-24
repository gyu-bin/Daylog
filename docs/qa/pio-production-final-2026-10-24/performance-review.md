# 네이티브 수명·성능 검토 — 2026-10-24

## 구현한 검증 (실행 결과는 별도 기록)

`DaylogStoreKitTests/PioProductionFinalLifecycleTests.swift` 신규 파일을 추가했다. 네이티브 소유권 회귀 검사에서 실제 순환 참조를 재현한 뒤 `PioCloudSceneHost.swift`, `RoutimoriVacationScene.swift`의 Mac 전용 불필요한 강한 조상 참조 배열을 제거했다. 기존 원화, 구매 관리자 또는 기존 테스트 assertion은 변경하지 않았다.

프로젝트의 PBXFileSystemSynchronizedRootGroup 연결을 확인했다. 이 디렉터리는 Mac `DaylogTests`와 iOS `DaylogStoreKitTests`에 모두 포함되므로 프로젝트 파일 수정은 필요하지 않다.

모든 신규 테스트는 `-PioProductionFinalLifecycleReview` 인자를 명시했을 때만 실행한다. 별도 의상 강제 착용, 구매 권한 변경, 사용자 기본설정 쓰기를 하지 않는다. 여러 의상을 그리는 것은 네이티브 리그 검토이며, 구매한 의상을 실제 앱에 착용하는 전체 사용자 흐름과 구분한다.

| 고유 메서드 | 범위 | 증거 파일명 |
|---|---|---|
| testTenVisibleCloudAttachDetachCycles | 기본 클라우드 실제 표시→150ms 재생→이탈/해제10회 | final-cloud-10-cycles.json |
| testTwentyVisibleCloudAttachDetachCycles | 동일 조건20회 | final-cloud-20-cycles.json |
| testFiftyVisibleCloudAttachDetachCycles | 동일 조건50회 | final-cloud-50-cycles.json |
| testMacIntactScrollSubtreeReleasesNativeHost | Mac 실제 스크롤 문서를 자식부터 분리하지 않고 외부 트리 전체를 해제 | final-mac-intact-scroll-subtree.json |
| testMacVacationSwiftUIScrollSubtreeReleasesNativeView | 실제 휴가 SwiftUI/private native 뷰를 가진 스크롤 트리 전체 해제 | final-mac-vacation-swiftui-subtree.json |
| testMacPlainSwiftUIScrollSubtreeOwnershipControl | 같은 SwiftUI 호스팅/스크롤 fixture의 일반 Text 대조군 | XCTest 결과 |
| testFourteenOutfitsThreeVisibleSequentialPasses | 14의상 순차 재생3회전, 선택된 원화 revision 기록 | final-cloud-fourteen-three-passes.json |
| testPairedVisibleActiveStoppedProcessObservations | 빈 창2초·첫 로딩2초·활성/정지5초씩3쌍·해제2초 | final-cloud-paired-active-stopped.json |
| testHomeReferenceFourteenOutfitsTwoVisiblePasses | 일반 홈 fallback 리그14의상×2회전 | final-home-reference-fourteen-two-passes.json |
| testVacationFourteenDayNightTwoVisiblePasses | 기존 휴가 리그14의상×낮/밤×2회전 | final-vacation-fourteen-day-night-two-passes.json |

각 검사는 XCTest JSON attachment를 남긴다. 실제 창 표시 상태 및 Core Animation presentation layer 존재를 확인한다. 화면 이탈 직후 **명시적 halt 이전** 애니메이션0, 이후 weak host/rig 해제를 확인한다. AppKit autorelease 참조의 해제 범위를 명시해 순간적인 임시 참조를 누수로 오인하지 않는다.

CPU는 `getrusage(RUSAGE_SELF)` user+system 시간 차 / 단조 시계 구간으로 측정한다. 100%는 CPU1코어에 해당한다. 활성/정지의 순서는 활성→정지, 정지→활성, 활성→정지로 번갈아 기록한다. RSS는 `mach_task_basic_info`이며 API 오류를0사용량으로 처리하지 않고 assertion한다.

150ms 재생과1초 표본 간격은 정해진 관측 구간이다. 타임아웃이나 실패를 없애기 위해 늘린 sleep이 아니다. 임의 RSS 기준으로 PASS를 선언하지 않는다. 첫 로딩/반복/정지/해제 결과를 구분하며, 이미지 캐시·그래픽 리소스·메모리 할당기 잔류는 실제 소유 객체 누수와 다를 수 있다.

## 코드 검토

- 홈 `PioHeaderCompanion`: `visible && onScreen && scenePhase == .active && !reduceMotion`에 따라 활성 여부를 계산한다. 의상 권한 검증 중은 렌더와 반응을 억제한다. 화면 이탈 시 interaction task 취소, 의상 변경 시 기존 반응 초기화. 완료 task는 weak self이며 deinit에서도 취소한다.
- 클라우드 `RoutimoriSyncScene`: 화면/scenePhase/Reduce Motion과 네이티브 보임 여부가 모두 적용된다. Native representable 콜백은 weak stage, dismantle 시 halt한다. 리그가 갖는 반복은 Core Animation이며 별도의 매 프레임 SwiftUI Task를 생성하지 않는다.
- 휴가 `RoutimoriVacationScene`: 같은 scenePhase/Reduce Motion/화면 이탈 정책과 네이티브 조상 클리핑 검사를 적용한다. 의상별 완성 foreground가 바뀔 때 host를 재생성한다. 원화의 부족을 수명 테스트 PASS로 덮지 않는다.
- `RoutimoriVacationRig.ambient`는 리그 생성마다 낮/밤 backdrop에 각각 CIContext를 생성한다. 이는 실제 첫 로딩 비용과 리소스 잔류에 포함된다. **그 사실만으로 누수나 CPU 병목으로 단정하지 않는다.** 새 반복검사에서 첫 회전과 둘째 회전의 비용을 따로 남긴다.
- Mac NSClipView 관측 배열은 강한 참조였다. `NSClipView → document host → observed clip` 소유권 순환을 실제 네이티브 검사로 확인했다. 문서 host 자체를 먼저 분리하는 기존20회 검사는 배열이 지워져 이 경로를 재현하지 못했다. 이번에는 바깥 스크롤 트리를 통째로 제거해 strong 참조를 모두 버렸으나 host와 clip이 남았다. stage와 scroll 자체는 해제됐으므로 임시 stage Task가 아닌 ancestor retention이다.

## 확인된 결함과 최소 수정

`mac-first-tests.log`47–50행: `testMacIntactScrollSubtreeReleasesNativeHost` FAIL, weak host와 clip의 해제 assertion2개 실패. 해당 실패 로그와 xcresult를 그대로 보존한다. 테스트는 실패 관측·assertion 뒤에만 문서를 명시적으로 분리해 검사 자체가 남긴 순환을 청소했다.

수정은 Mac 클라우드의 `observed: [NSClipView]`와 Mac 휴가의 `observedClipViews: [NSClipView]` 및 append/removeAll을 제거한 것이다. 이 배열은 관측 대상의 순회나 해제에 전혀 쓰이지 않았다. 기존 selector NotificationCenter 관측 등록/해제는 그대로 유지해 clipping/scroll/visibility 콜백 동작을 바꾸지 않았다. 관측을 위해 조상 객체를 강하게 보유할 필요가 없다.

첫 수정 후 `mac-corrected-tests.log`에서 기존 cloud intact subtree 검사는 PASS했다. 새 휴가 SwiftUI 검사에서는 clip/scroll은 해제됐으나 NSHostingView/native 뷰가 남았다. 이는 앞선 ancestor cycle과 다른 서명이다. 아직 휴가 앱 코드의 추가 누수로 단정하지 않았다. fixture가 생성·레이아웃·ObjC subviews 재귀 검사 도중 autorelease 임시 참조를 남길 수 있어 명시적 autorelease 범위를 추가하고, 동일 호스팅 구조의 일반 Text 대조군을 추가했다. 기존 assertion과3초 해제 조건 timeout은 유지했다. 이 fixture 수정의 결과는 재실행 증거로 판단한다.

`mac-art-lifetime-tests.log` 재검사: cloud intact subtree PASS, 실제 휴가 SwiftUI intact subtree **PASS**. 추가 앱 수정 없이 autorelease fixture 범위만 바로잡아 NSHostingView/native도 해제됐다. 일반 Text 대조군의 해제 assertion은 실패하지 않았으나 최초 `hostWindow.actuallyVisible` assertion이 실패했다. Text 대조군에는 앞선 두 fixture와 달리 창 보임 이벤트 대기가 없었다. NSWindow orderFront의 occlusion 통지는 동기 완료 계약이 아니므로, 동일한 첫 보임 조건을 명시하고 창 실제 보임·hosting.window 동일성·비어 있지 않은 visibleRect를 모두 검사하도록 고쳤다. 기존 수명/보임 assertion은 유지한다. 마지막 일반 Text 대조군 재실행은 `mac-art-final-tests.log`에서 PASS했다. 이 실행은 XCTest 11/11 및 Swift Testing 9/9 PASS이며, 실제 alias 최적화 후 native window visibility 회귀도 별도 `mac-alias-regression-tests.log`에서 PASS했다.

동일 소유권 그래프를 가진 휴가도 수정하고, 실제 `RoutimoriVacationScene`을 NSHostingView/NSScrollView에 표시한 뒤 바깥 트리를 버리는 회귀 검사를 추가했다. SwiftUI dismantle은 예약될 수 있어 조건 기반 XCTNSPredicateExpectation으로 실제 해제를 기다린다. 임의 sleep 또는 RSS assertion으로 대체하지 않는다.

## 실행 및 해석 제한

소스 `swiftc -frontend -parse`, 관련 diff whitespace 검사 PASS. 첫 네이티브 실행에서 위 순환을 재현했다. 수정 후 네이티브 실행은 부모 작업에서 다른 렌더 검사와 직렬로 진행한다. 결과 attachment/xcresult가 확보될 때만 개별 실행 상태를 갱신한다.

이 검사는 Debug XCTest 호스트의 리그 동작과 수명이다. 앱 cold launch, 실제 권한 전환, 실제 OS background, 휴대기기 배터리/GPU, WindowServer, Instruments allocation stack, 전체 앱의 장기 메모리 안정성 검증이 아니다. 홈 reference 검사는 DEBUG14종 independent overhaul의 모든10동작 검증을 대신하지 않는다. 휴가 검사는 기존 whole-foreground sway이며 새 눈/손/음료 또는 양끝 고정 줄 완성 검증이 아니다.

실제 VoiceOver 조작, OS Reduce Motion 전환 및 실제 앱 foreground/background 흐름은 UI 작업의 별도 증거가 필요하다. 이 테스트는 해당 항목을 PASS로 보고하지 않는다.
