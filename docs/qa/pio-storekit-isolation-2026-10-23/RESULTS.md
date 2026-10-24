# StoreKit 잔여 실패 격리 및 Sandbox 준비 — 2026-10-23

최종 판정: **PARTIAL**. 원래 StoreKit 11개를 다시 실행한 결과는 **7 PASS / 4 FAIL / 0 SKIP**이다. 추가 진단의 성공으로 기존 실패를 덮지 않았다. 네 잔여 실패 중 새 APP_BUG 또는 TEST_BUG로 원인이 입증된 항목은 없다. 세 항목은 앱 구매 관리자를 제외한 직접 SDK 경로에서도 관측되어 SDK_DEPENDENT로 분류하고, 환불 알림은 UNRESOLVED로 유지한다. SDK_DEPENDENT는 Apple 결함 확정 또는 PASS를 뜻하지 않는다.

앱 구매·권한 코드는 이번 작업에서 수정하지 않았다. 취소를 unknown으로 보고하는 주입 경로를 강제로 성공/취소 처리하거나, 테스트 드라이버의 issue 플래그로 실제 검증 거래를 무효화하는 우회는 추가하지 않았다.

## 1. 범위와 실행 환경

기존 integration 및 stabilization의 RESULTS/REVIEW 네 문서, 실제 로그와 현재 소스, 설치된 SDK 인터페이스를 대조했다. 이전 작업의 리스너 종료·즉시 선택 저장·중첩 공개 취소 분류·서명 오류 주입 순서 수정은 유지한다.

- Xcode **27.1 / 27A9275**, macOS **27.0.1 / 26A434**, iOS 및 Simulator SDK **27.1**.
- 실행 기기: 전용 iPhone 17 Simulator, iOS **27.0 / 24A434**, UUID `0426CD78-3807-4650-9776-B649780E2884`.
- 모든 자동 구매는 Xcode 로컬 `.storekit` 환경이다. 계정·실제 금전 결제·ASC 변경은 없다.
- A: 같은 앱 호스트의 최소 직접 SDK 테스트. `Product.purchase`, `Transaction.updates/currentEntitlements/unfinished`, `Transaction.finish`를 직접 호출하며 Pio 구매 관리자는 생성하지 않는다. 별도 독립 앱 바이너리 재현은 아니다.
- B: 실제 `PioPurchaseManager`와 `PioWardrobeStore`, UUID별 테스트 기본 설정. 실제 검증 경로를 사용한다.
- C: 실제 앱 옷장에서 Xcode/no-charge 구매 시트의 취소와 같은 프로세스 재시도를 직접 조작했다. 실제 UI 구매 확인 및 나머지 세 실패의 UI 재현은 NOT_TESTED다.
- SKTestSession 변경은 직렬 실행한다. seed는 reset → clear → 각 simulated error 해제 → KOR 설정 순서, 리스너는 종료를 기다린다. fresh-process finish 검사는 새 세션 생성/reset/clear보다 **먼저** 동일 거래를 읽는다.

환경은 [environment.json](environment.json), 각 명령과 전체 출력은 [matched-traces](matched-traces/)에 남겼다. 시간은 타임라인에 wallTime(Unix seconds)과 단조 증가 elapsed를 함께 기록했다. 로그에 계정 비밀번호나 서명 영수증 본문을 남기지 않았다.

## 2. 네 실패의 판정과 근거

| 실패 | 분류 | 확인한 사실 | 판정 한계 및 영향 |
| --- | --- | --- | --- |
| 취소 오류 주입 | **SDK_DEPENDENT / FAIL** | 설정값은 `.generic(.userCancelled)`인데 직접 purchase가 공개 `StoreKitError.unknown`을 던진다. manager도 failed로 끝나며 busy는 해제되고 유료 권한은 없다. | 실제 로컬 시트 취소는 별도 PASS. 주입 실패를 실제 사용자의 모든 취소 실패로 일반화할 수 없다. |
| 중단 거래 | **SDK_DEPENDENT / FAIL** | issue=true 상태에서 직접 SDK가 이미 verified update와 current entitlement를 반환한다. resolve 전에 interruption을 끈 대조에서도 동일하다. | 테스트가 의도한 ‘해결 전 미구매’와 실제 SDK 결과가 충돌한다. 실제 Sandbox의 중단·재개 동작은 미검증이다. |
| 환불 알림 누락 | **UNRESOLVED / FAIL** | 원래 연속 테스트에서는 live 알림이 없고, 새 직접/manager 진단과 네 readback 대조는 모두 알림을 받아 통과한다. | 특정 조회, wrapper, Task 또는 SDK가 원인이라는 인과관계가 입증되지 않았다. 알림 미수신 중 소유 표시가 남을 위험은 해결됐다고 볼 수 없다. |
| 마지막 unfinished 잔존 | **SDK_DEPENDENT / FAIL** | 직접 경로에서 finish를 await한 마지막 Cafe 거래가 새 OS 프로세스에서도 unfinished다. 원래 13종 경로에서는 마지막 space 거래가 잔존한다. | 우주복 ID만의 결함은 아니다. 서버 미완료인지 SDK/테스트 환경의 읽기 상태인지까지 확정하지 못했다. |

### 2.1 취소: 오류 주입과 실제 시트 조작을 분리

호출 순서: `setSimulatedError(.generic(.userCancelled), forAPI: .purchase)`를 await → `simulatedError(forAPI:)` readback 일치 → `Product.purchase()`.

- A 제품 `outfit.student`: `StoreKit.StoreKitError`, code **2**, 공개 값 **unknown**, underlying **nil**. 거래 생성 없음, updates 없음, currentEntitlements/unfinished 모두 빈 배열. finish 해당 없음.
- B도 실패 결과, busy=false, Basic만 소유한다. 주입된 공개 취소 오류가 API 경계에서 유지되지 않아 원래 cancelled assertion은 실패한다.
- C에서는 실제 Apple 시트의 **Xcode / testing only / no charge** 안내와 **₩2,500**을 확인하고 닫았다. 최종 typed 상태는 `completed(...cancelled)`, `owned=[basic]`, `equipped=basic`, `busy=false`다. 같은 프로세스에서 다시 구매 시트를 열 수 있었다.
- 두 번째 UI 세션에서 구매 확인을 시도했으나 UI 좌표 도구가 `windowNotFoundAtPosition`을 반환했고 Return도 확정하지 않았다. 시트는 취소하고 종료했다. **UI 구매 성공은 NOT_TESTED**다. interactive fixture의 XCTest 성공만으로 구매 성공을 주장하지 않는다.

증거: [직접 취소 타임라인](matched-traces/direct-cancel-seed-timeline.json), [manager 취소](matched-traces/manager-cancel-seed-timeline.json), [실제 UI 상태](ui-local/observed-final-state.json), [UI 관찰](ui-local/ui-observations.json), [재시도 및 도구 한계](ui-local-purchase/ui-observations.json).

### 2.2 중단: 테스트 드라이버 상태와 검증 영수증의 충돌

호출 순서: `interruptedPurchasesEnabled=true` → purchase → 해결 전 세 API 조회 → **false** 설정 → `resolveIssueForTransaction(identifier:)` → 원래와 같은 10초 알림 관측 → 해결 후 조회.

- A `outfit.rainy`, 거래 **196**: purchase가 unknown을 던지기 **전** verified update가 도착했다. 해결 전 driver는 state=failed(raw 2), issue=true, pending=false인데 currentEntitlements와 unfinished에 같은 verified 196이 있다.
- resolve는 정상 반환, driver issue=false/state=purchased(raw 1)로 바뀐다. 관측한 10초 동안 새 update는 없다. verified 196은 그대로다.
- A raw observer는 issue update를 일부러 finish하지 않는다. 따라서 이 시나리오의 unfinished 196을 ‘await finish 후 잔존’ 증거로 세지 않는다.
- B `outfit.rainy`, 거래 **200**: 같은 초기 verified update를 실제 manager가 받아 소유권에 반영하고 finish를 await한다. purchase 반환은 failed이고 busy=false다. 해결 전에도 verified current entitlement는 존재하며, resolve 이후 새 알림은 관측되지 않았다. 종료 시 raw listener 잔존 수는 0이다.
- interruption 플래그를 끄지 않은 것만이 원인이라는 가설은 새 대조로 설명되지 않는다. production 코드에 `SKTestTransaction.hasPurchaseIssue` 예외를 넣지 않았다.

증거: [A 전체 순서](matched-traces/direct-interrupt-seed-timeline.json), [B 전체 순서와 finish 시각](matched-traces/manager-interrupt-seed-timeline.json).

### 2.3 환불: 알림과 명시적 권한 재조회를 별도로 검증

호출 순서: verified 구매/finish → winter 착용(B) → `refundTransaction(identifier:)` → manual refresh **없이** 원래와 같은 10초 live 알림 조건 → 그 후 별도 currentEntitlements/manager refresh.

- A `outfit.winter`, **197**: revoked=true verified update 수신, currentEntitlements/unfinished 빈 배열, PASS.
- B `outfit.winter`, **201**: 최초 finish 반환 wallTime **1792756995.6526089**, refund 반환 **1792756995.667944**, raw revoked update **1792756995.674403**, 소유권 회수 **1792756995.677624**. 수동 refresh 전에 이미 Basic으로 복귀했다. 별도 명시적 refresh도 true, paid 재착용 거부, currentEntitlements 빈 배열이다.
- 원래 11개 연속 실행의 refund live 알림은 다시 FAIL이었다. 이전 단독 및 순서 대조 결과도 보존했다.
- 원래 fixture 흐름을 따른 후속 4개 대조는 구매 후 환불 전 조회만 `없음 / currentEntitlements / unfinished / 둘 다`로 나눴다. **4/4 PASS**다. ‘조회 없음’도 통과했으므로 특정 추가 조회가 해결책이라는 결론은 성립하지 않는다.
- 과거 알림 누락 상태에서도 currentEntitlements 재조회 시 회수되는 근거는 [이전 결과](../pio-storekit-stabilization-2026-10-23/RESULTS.md)에 있다. 이번 대조에서도 별도 refresh와 Basic 복귀를 검증했지만, 그것으로 live 알림 실패를 지우지 않았다. 앱에 추가 polling·타이머·진단 로그를 우회책으로 넣지 않았다.

증거: [A](matched-traces/direct-refund-seed-timeline.json), [B](matched-traces/manager-refund-seed-timeline.json), [단일 변수 대조 결과](readback-factors/series.json), [기존 실패 유지](matched-traces/original-eleven-summary.json).

### 2.4 finish: 마지막 상품 교체와 새 프로세스 관측

- A는 우주복을 먼저 구매한다. `outfit.space` **198**: verified 성공 → finish 반환 **1792756965.643879**. 이어 Cafe를 마지막 구매한다.
- `outfit.cafe` **199**: verified 성공 → finish 반환 **1792756965.658659** → currentEntitlements에 198/199, unfinished에는 마지막 **199**가 남는다.
- seed PID **5512**, fresh PID **5537**. 새 프로세스는 SKTestSession 생성/reset/clear/purchase/sync/finish보다 먼저 조회했다. wallTime **1792756970.475728**, 같은 verified 198/199와 unfinished 199를 관측했다. 마지막 finish 반환 약 **4.82초 후**다. 임의 sleep을 추가한 결과가 아니라 새 프로세스 시작 후 첫 관측이다.
- 따라서 seed 테스트 종료 순간 또는 동일 프로세스가 보유한 객체만으로 전부 설명할 수 없다. 다만 실제 서버 미완료와 테스트 서비스 readback 상태의 최종 구분은 미해결이다.
- B의 두 상품 대조 **202(space) / 203(cafe)**는 finish 후 및 새 프로세스 모두 unfinished가 비어 PASS다. 이 한 조건의 성공은 전체 13종의 마지막 거래 **216(space)** 잔존 FAIL을 해결하지 않는다.
- 우주복 전용 처리, 더미 추가 구매, 테스트 쪽 재-finish, 조건 삭제, 기존 3초 대기 확대는 하지 않았다.

증거: [A seed](matched-traces/direct-finish-seed-timeline.json), [A 새 프로세스](matched-traces/direct-finish-verify-timeline.json), [B seed](matched-traces/manager-finish-seed-timeline.json), [B 새 프로세스](matched-traces/manager-finish-verify-timeline.json).

## 3. SDK 계약 및 테스트 환경 검토

[독립 계약 검토서](CONTRACT-REVIEW.md)에 공식 Apple 문서와 설치된 헤더 근거를 정리했다.

- Deprecated `failTransactionsEnabled` / `failureError`로 되돌리지 않았다. 현재 테스트는 지원되는 async `setSimulatedError`와 readback을 사용한다.
- `resetToDefaultState`는 설정 복원, `clearTransactions`는 거래 삭제다. SDK 서비스·모든 캐시·기존 async listener 재시작을 보장하는 API로 해석하지 않았다. 공유 테스트 환경은 직렬화했다. [SKTestSession](https://developer.apple.com/documentation/storekittest/sktestsession)
- `resolveIssueForTransaction`은 issue가 있는 실제 driver 거래 ID로 호출했다. 새 update 의미와 공개 문서의 수치 SLA 부재를 구분한다. [resolveIssue](https://developer.apple.com/documentation/storekittest/sktestsession/resolveissuefortransaction(identifier:))
- Apple의 reviewed 문서는 finish 뒤 unfinished가 3초 안에 반드시 비어야 한다는 수치 보장을 제시하지 않는다. 3초는 유지한 프로젝트 합격 기준이다. 이 사실만으로 테스트 결함 또는 PASS로 판정하지 않는다. [finish](https://developer.apple.com/documentation/storekit/transaction/finish()), [unfinished](https://developer.apple.com/documentation/storekit/transaction/unfinished)
- updates에도 10초 수치 보장이나 앱이 사용할 구독 준비 완료 ACK는 없다. iterator 시작 표시는 테스트 순서 기록이며 SDK 구독 완료 보장은 아니다. [updates](https://developer.apple.com/documentation/storekit/transaction/updates)
- `Product.products`는 Collection<String>을 받으므로 Set 자체는 유효하다. 1개 Array와 13개 Set의 차이를 Set 버그 증거로 사용하지 않았다.

설치된 다른 iOS 런타임이 없어 다른 OS/SDK 대조는 NOT_TESTED다. SDK_DEPENDENT는 이 설치 환경의 최소 재현 분류이며 전 버전 공통 결함 단정이 아니다.

## 4. 실제 실행한 검증

### 원래 11개 — 새 실행, 삭제·제외 없음

| 테스트 | 결과 |
| --- | --- |
| ConfigurationLoadsThirteenNonConsumablesAtKoreanDisplayPrice | PASS |
| PurchaseDuplicateRelaunchAndRepeatedEquipmentUseVerifiedLedger | PASS |
| PendingAskToBuyDoesNotUnlockUntilApprovedUpdate | PASS |
| RefundUpdateRevokesAccessAndRefreshResetsEquipment | FAIL — live 알림 |
| EveryPremiumOutfitPurchasesEquipsAndLoadsApprovedArtwork | FAIL — 마지막 unfinished |
| ExplicitRestoreRecoversExternalPurchase | PASS |
| CancellationFromStoreKitDoesNotUnlockOrShowFailure | FAIL — 주입 오류 반환 |
| PurchaseFailureLeavesLockedAndAllowsRetry | PASS |
| ProductLoadFailureAndRetryUseRealStoreKitAPI | PASS |
| VerificationFailureNeverGrantsFreshManagerOwnership | PASS |
| InterruptedPurchaseOnlyUnlocksAfterResolution | FAIL — 해결 전 권한 |

[전체 실행 결과](matched-traces/original-eleven-summary.json), [로그](matched-traces/original-eleven.log), `matched-traces/original-eleven.xcresult`.

### 추가 진단 — 기존 합격 기준을 대체하지 않음

| 시나리오 | A 직접 SDK | B 실제 manager |
| --- | --- | --- |
| 취소 주입 | FAIL | FAIL |
| 중단 / resolve | FAIL | FAIL |
| 환불 live + 별도 권한 조회 | PASS | PASS |
| space 먼저 / cafe 마지막 finish | FAIL | PASS |
| 위 거래를 새 프로세스에서 첫 조회 | FAIL | PASS |

총 10개 진단 실행: **4 PASS / 6 FAIL / 0 SKIP**. [series.json](matched-traces/series.json).

- 환불 readback 대조: **4 PASS / 0 FAIL / 0 SKIP**. [결과](readback-factors/series.json)
- 실제 로컬 시트 취소: **PASS**, Basic만 소유·busy 해제. 취소 뒤 같은 프로세스 시트 재열기: **PASS**. 실제 UI 구매 확인: **NOT_TESTED**.
- interactive fixture 두 실행 자체는 1/1씩 성공했지만 자동 구매 합격 검사로 합산하지 않는다. 최종 상태와 사람이 한 조작을 함께 기록했다. [첫 결과](ui-local/observed-final-state.json), [두 번째 결과](ui-local-purchase/observed-final-state.json).
- 새 테스트 코드 컴파일: **PASS**, `harness-build-v2.log`, `readback-ui-build.log`, `readback-factors/build.log`. 최초 하네스 컴파일 오류 로그 `harness-build.log`도 보존했다. 진단 스냅샷 반환 ID를 verified로 제한한 마지막 보강은 후속 빌드에 포함됐으며, 앞선 matrix의 모든 실제 ID도 JSON에서 verified였다. matrix 자체를 수정 후 재실행했다고 주장하지 않는다.
- Sandbox 전용 unsigned generic-iOS Debug 빌드: **PASS**, [결과](sandbox-build/result.json). 실제 Sandbox 런타임: **NOT_TESTED**.

### 유효한 이전 증거 재사용 — 이번에 재실행하지 않음

| 항목 | 기존 결과 / 이번 취급 |
| --- | --- |
| 기존 69 + 추가 8 단위·회귀 | **77/77 PASS** 유지, NOT_RERUN |
| 즉시 구매·착용 후 새 프로세스 복구 | **3/3 PASS** 유지, NOT_RERUN |
| 전체 StoreKit 연속 3회 및 순서 변경 | 기존 모두 **7/11**, 새 전체 1회도 동일 |
| macOS Release | 기존 PASS 유지, NOT_RERUN |
| iOS Simulator Release | 기존 PASS 유지, NOT_RERUN |

근거는 [이전 RESULTS](../pio-storekit-stabilization-2026-10-23/RESULTS.md), 원래 로그와 `instant-fixed-1..3/`다. 관련 기존 검증 소스 9개와 이번 시작점 핵심 소스 10개를 SHA-256 대조해 모두 같았다. 새 diagnostic finish 재실행은 미완료 거래 관측용이며, 이전 ‘즉시 착용 상태 복원 3/3’과 다른 검사다.

## 5. 이번 변경과 보존

이번에 추가/수정한 실행 파일:

- `DaylogStoreKitTests/PioStoreKitIsolationTests.swift`: 네 시나리오 A/B 타임라인, 새 프로세스 finish 관측. 기록용 ID는 실제 검증 영수증 비교에만 사용하며 소유권으로 주입하지 않는다.
- `DaylogStoreKitTests/PioStoreKitRefundReadbackTests.swift`: 환불 전 네 조회 대조. live 알림 실패와 이후 명시적 refresh를 분리한다.
- `DaylogStoreKitTests/PioStoreKitReviewTests.swift`: 기존 opt-in 수동 UI fixture 끝에 typed 상태 출력/attachment **6줄만 추가**. [이번 diff](review-harness.diff)
- `Tools/pio-storekit/isolate.py`: 전용 이름/UUID Simulator만 허용, 결과 덮어쓰기 거부, 직렬 실행·로그·xcresult 추출. 실패 seed도 fresh 관측을 하되 실패는 그대로 보존한다.
- `Tools/pio-storekit/prepare-sandbox-build.py`: 정상 설정을 바꾸지 않는 Sandbox 전용 임시 plist/분리된 unsigned 빌드. widget plist 보존 검사.
- 이 QA 폴더의 원인·계약·Sandbox 문서와 원본 실행 증거.

앱 구매/권한/선택/UI/상품 매핑/StoreKit 구성/프로젝트 설정은 작업 시작점과 동일하다. 기존 uncommitted 수정들은 그대로 보존했다. [보존 결과](preservation-after.json): 원화·동작 **723/723 동일**, 핵심 소스 **10/10 동일**, 이전 검증 소스 **9/9 동일**, diff 공백 검사 PASS. HEAD는 시작점과 같은 `34a989ce2d77fd1da4166a88992ac01d2e528527`이다. 커밋·push·배포·운영 앱 교체·SwiftData/CloudKit 변경은 없다.

## 6. Sandbox 준비와 실제 구매 영향

[SANDBOX.md](SANDBOX.md)에 기존 확정 13 ID, 실제 계정/전용 기기 준비, StoreKit Configuration **None**, `.sandbox` 영수증 확인, 구매·취소·중단·복원·즉시 재실행·환불·미소유 착용 거부의 순서와 기대 결과를 기록했다.

- 임시 unsigned Debug 빌드의 bundle은 기존 `com.mungyubin.daylog.ios`, typed Boolean `PioStoreKitCatalogConfirmed=true`, 환경은 sandbox다. widget 설정도 보존했다. 정상 빌드의 결제 환경 gate는 변경하지 않았다.
- 사용 가능한 개발 서명 identity와 paired iPhone은 읽기 전용으로 확인했다. 전용 테스트 기기인지, 운영 앱이 없는지, Developer Mode/유효 provisioning/Sandbox 계정 준비는 확인되지 않았다. 따라서 서명·설치·계정 입력·구매를 진행하지 않았다.
- 실제 Apple 13개 상품 조회와 KOR 가격, 실제 Sandbox 구매·취소·환불 등은 **모두 NOT_TESTED**다. 로컬 ₩2,500 조회 PASS를 서버 가격 검증으로 바꾸지 않는다.
- 취소 오류 주입 FAIL은 실제 로컬 시트 취소 실패와 동일하지 않다. 그러나 중단 거래의 해결 전 verified 결과, 환불 알림 경로, 최종 unfinished 관측은 실제 Sandbox에서 반드시 다시 대조해야 한다. 현재 근거로 유료 구매 신뢰성을 최종 승인할 수 없다.
- 기존 ASC 캡처는 review screenshot 등 `MISSING_METADATA`를 보였다. 이번에 서버 상태를 재확인/변경하지 않았다. 이는 별도 출시 준비 항목이며 Sandbox 상품 조회 불가의 단독 원인으로 단정하지 않는다.

## 7. 다음 개발 단계 판단

**추가 앱 수정 없이 다른 기능 개발은 진행 가능하다.** 확인되지 않은 SDK 결과에 맞춰 구매 보안을 완화하거나 임시 예외를 추가할 근거는 없다. 정상 빌드 결제 gate와 원래 실패 검사는 유지한다.

**구매 시스템 완료·실제 결제 활성화·출시 승인은 보류한다.** 원래 11/11 기준 미달, 환불 원인 미확정, SDK 종속 관측의 실제 Sandbox 영향 미확인, 실기기/Sandbox 미검증이 남아 있다. 단순 테스트 환경 문제로 확정되어 출시 차단에서 제외할 수 있는 네 잔여 항목은 아직 없다. 다음 유효한 검증은 준비 문서대로 전용 기기와 Sandbox 계정의 동일 흐름을 비교하는 것이다. 동일 로컬 실패의 무한 반복이나 근거 없는 앱 리팩터링은 여기서 중단한다.
