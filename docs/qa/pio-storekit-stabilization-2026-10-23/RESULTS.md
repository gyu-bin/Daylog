# Routimori StoreKit 2 안정화 — 2026-10-23

**최종 판정: PARTIAL. 요구한 11/11 안정성 기준을 충족하지 못했습니다.**

즉시 재실행 시 착용 선택이 실제로 유실되는 앱 결함과 공개 오류의 중첩 취소 분류를 수정했습니다. 리스너 종료 경계를 명시하고, 서명 오류 주입 순서의 테스트 결함을 수정했습니다. 기존 69개 + 추가 8개 = **77개 단위·회귀 검사 PASS**, **즉시 새 프로세스 재실행 3/3 PASS**, macOS/iOS Simulator Release 빌드 PASS입니다.

반면 기존 StoreKit 11개는 **연속 3회 모두 7 PASS / 4 FAIL / 0 SKIP**이고, 무작위 순서에서도 같습니다. 네 실패는 취소 오류 주입, 중단 거래, 환불 알림, 마지막 거래의 unfinished 잔존입니다. 실제 Apple Sandbox는 **NOT_TESTED**입니다. 테스트 실패를 해결된 것으로 표시하거나 출시 준비 완료라고 판단하지 않습니다.

## A. 원인 분석

### D — 즉시 재실행: 확인된 앱 결함, 수정 후 PASS

- 수정 전 실제 `Product.purchase()`로 Cafe 구매 → 검증 거래 ID 80 → 실제 `wardrobe.equip(.cafe) → .basic → .cafe`를 실행했습니다.
- 인위적 지연 없이 새 OS 프로세스를 실행하자 같은 **검증된 거래 ID 80/소유권은 복구**했지만, 공개 UserDefaults API와 실제 착용 상태가 모두 Basic이었습니다. 메타데이터를 선호 도메인에 주입하지 않은 상태에서도 재현됐습니다.
- 기존 `PioWardrobeStore.equip`는 메모리 상태와 UserDefaults 비동기 저장만 갱신하고 성공을 반환했습니다. 마지막 착용 선호를 프로세스 종료 전에 보존했다는 보장이 없었습니다. [Apple UserDefaults 설명](https://developer.apple.com/documentation/foundation/userdefaults).
- 새 `PioWardrobeSelectionFile`은 **버전과 의상 선택 하나만** 작은 JSON 파일로 원자적으로 저장합니다. 저장이 완료돼야 equip이 성공합니다. 로컬 테스트/체험/Sandbox/운영 프로필 및 앱 번들별로 분리합니다. 기존 UserDefaults는 호환용 읽기·미러로 남깁니다.
- 파일은 영수증이나 소유권을 저장하지 않습니다. 새 manager는 Basic만 소유하며, 검증 전 유료 선호가 있어도 실제 착용은 Basic입니다. 검증된 currentEntitlements가 확인돼야 이전 의상을 표시합니다. 손상·모르는 버전/의상은 안전하게 처리하고 저장 실패는 성공으로 반환하지 않습니다.
- `instant-relaunch-1/`은 수정 전 실패 원본입니다. 수정 후 `instant-fixed-1/` ~ `3/`은 실제 구매, 서로 다른 PID, 동일 검증 영수증, Cafe 착용 복구를 각각 확인했습니다. seed와 verify 사이에 sleep/재구매/복원/권한 주입은 없습니다. 런처에 따른 실제 간격은 약 5.13/5.09/4.86초이며, 강제 종료·실기기·전원 차단 검증을 의미하지 않습니다.

### A — 취소·중단 거래: 일부 코드 결함 수정, 로컬 통합 실패 유지

- 기존 취소 분류는 최상위 공개 취소 오류만 인식했습니다. `StoreKitError.systemError(underlying:)` 또는 `NSUnderlyingErrorKey` 아래의 공개 취소 오류를 재귀적으로 분류하도록 수정하고, 순환/깊이를 제한했습니다. 비공개 서버 코드 907이나 모든 unknown 오류를 취소로 해석하지 않습니다. 새 단위 검사 PASS입니다.
- 로컬 취소 테스트의 `.generic(.userCancelled)` 주입이 실제로 설정됐음을 확인했지만, 앱을 거치지 않은 직접 `Product.purchase()`도 `StoreKitError.unknown`을 반환했습니다. 사용자 구매 시트의 Cancel 버튼을 누른 실제 UX는 이번에 검증하지 않았습니다. 기존 취소 통합 assertion은 유지했고 FAIL입니다.
- 중단 거래는 해결 전 `hasPurchaseIssue == true`인데 같은 ID의 **검증된 currentEntitlements**와 verified 업데이트가 이미 나타납니다. 직접 SDK 실험 ID 79에서도 재현됐습니다. 최종 전체 검사에서는 ID 154의 verified 업데이트와 finish가 resolve 호출 전에 관측됐습니다.
- 테스트 전용 `hasPurchaseIssue`로 운영 소유권을 가로채거나 검증된 거래를 임의로 무시하는 우회는 넣지 않았습니다. 해결 전 잠금과 해결 후 알림 assertion을 유지했습니다. 이 로컬 경로는 FAIL이고 SDK 내부 원인은 확정하지 않았습니다.
- 취소/대기/실패 후 busy 해제, 공개 오류 재시도, 중복 입력 차단, 미검증·다른 상품·취소된 거래 거부는 단위 검사에서 통과합니다. Pending → 승인 업데이트는 실제 로컬 통합에서도 PASS입니다.

### B — 환불 알림: 재현되지만 단일 근본 원인은 미확정, FAIL

- 각 manager와 실제 `Transaction.updates` 구독을 명시적으로 중단·완료까지 기다린 뒤에만 테스트 ledger를 초기화합니다. 시작/종료·활성 구독 수를 기록하며, 최종 연속·무작위 검사에서 잔존 리스너 assertion 실패는 없었습니다. 따라서 **중복/잔존 리스너가 원인이었다고 결론 내리지 않습니다.**
- 독립 앱 검사에서도 refund 이후 raw revoked 알림을 받지 못합니다. 이때 manager는 기존 소유/착용을 유지해 기존 assertion이 실패합니다. 뒤이어 실제 currentEntitlements를 재조회하면 소유권은 제거됩니다. 알림을 받았을 때의 회수·기본 의상 전환과 저장은 단위 검사에서 PASS입니다.
- 직접 SDK 대조 검사 `sdk-refund.log`는 ID 180의 raw revoked 알림과 빈 권한 목록으로 PASS했습니다. 그러나 앱 경로 뒤에 같은 직접 검사를 실행한 `refund-final-control.log`에서는 ID 194가 권한 목록에서 제거됐어도 raw 알림이 없어 FAIL했습니다. 새 프로세스 단독 `sdk-refund-isolated-final.log`에서는 ID 195로 다시 PASS했습니다.
- 영수증 사전 확인·상품 사전 조회만으로 앱 실패가 해결되지 않았습니다. 어댑터만 사용한 검사도 초기화 조건에 따라 다른 결과였습니다. `refund-order*`, `refund-factors*`, `matched-*`에 통제 조건과 실패/통과 원본을 남겼습니다. 후속 비교의 직접 baseline도 실패했으므로 특정 API/child Task 하나가 원인이라는 인과 결론은 내리지 않습니다.
- 이 증거는 테스트 세션/SDK 이벤트 전달과 앱 경로의 상호작용을 더 조사해야 함을 보여줍니다. 운영 앱 문제를 배제하거나 SDK 전체 오류로 일반화할 근거는 부족합니다. 환불 이벤트 누락을 임의 polling/sleep/무조건 소유권 제거로 덮지 않았습니다. **출시 전 해결 또는 다른 지원 도구 체계에서 재검증이 필요한 핵심 미해결 항목입니다.**

### C — 마지막 우주복 거래: 상품별 매핑 결함은 아님, 완료 관측 FAIL

- 기존 13종 검사의 구매 결과·검증·소유권 누적·착용 및 각 의상의 10개 rig 동작 assertion은 통과하고, 마지막 `Transaction.unfinished` 관측에서 실패합니다. 즉 우주복만 구매 성공/착용이 빠졌다는 설명은 정확하지 않습니다.
- 실제 어댑터는 마지막 거래에 finish를 호출하고 반환까지 기다렸으나, 원래 3초 한도 내 unfinished 목록에서 사라지지 않았습니다. 타임아웃을 늘리거나 테스트 관찰자가 대신 finish/sync/clear를 호출하지 않았습니다.
- 직접 SDK 대조에서는 **우주복을 먼저** 구매/finish하면 unfinished가 비고, **Cafe를 마지막**으로 구매/finish하면 ID 78이 3초 동안 남았습니다. Pio manager/어댑터/중복 완료 캐시를 사용하지 않은 실험입니다. 증상은 특정 상품 ID를 따라가지 않습니다.
- 이 환경에서 실제 finish 반환 이후 StoreKit의 완료 readback이 실패한다는 점까지 확인했으며, SDK 내부 원인을 확정하거나 운영 완료 보장을 주장하지 않습니다. 특정 우주복 예외 처리는 없습니다.

### 별도 테스트 결함 — 서명 오류 주입 순서, 수정 후 PASS

- 이번 수정 전 현재 소스를 실행하자 보고서의 7/4와 달리 6/5였습니다. 추가 실패는 서명 오류 주입 검사였습니다.
- 원래 검증된 거래를 만든 **뒤에** invalidSignature를 주입하므로 이미 검증·캐시된 영수증이 테스트 의도와 충돌할 수 있었습니다.
- 오류를 **거래 생성 전** 설정하고 실제 거래 생성·상품 ID·거래 수까지 확인합니다. 미검증 권한 거부 및 refresh 실패 assertion은 유지했습니다. 독립 실행, 전체 3회 및 무작위 실행 모두 PASS입니다.

## B. 이번 작업에서 변경한 파일

이전 작업의 미커밋 변경은 덮어쓰지 않았습니다. `before/` 및 `task-scoped.diff`는 이번 작업 시작점과의 차이를 보관합니다.

| 파일 | 이번 변경 |
|---|---|
| `Daylog/Services/PioPurchaseManager.swift` | 공개 중첩 취소 분류, 재시작 가능한 명시적 비동기 stop, raw 구독 Task/continuation 종료·join, 수명 진단. 기존 verified 거래 수용/매핑/가격/finish 조건은 유지 |
| `Daylog/Services/PioWardrobe.swift` | 선택 저장소 주입 및 공유 인스턴스 연결, 저장 성공 후 착용 완료, 기존 소유권 gate 유지 |
| `Daylog/Services/PioWardrobeSelection.swift` | **신규**, 원자적 착용 선호 저장. 영수증·소유권 없음 |
| `DaylogTests/PioPurchaseTests.swift` | 중첩 공개 취소/비공개 오류 거부, 중단·재시작 및 진행 중 acknowledgement 종료 대기 3개 회귀 검사 |
| `DaylogTests/PioWardrobeTests.swift` | 재오픈·검증 전 잠금·권한 제거 후 기본 저장, 손상/저장 실패, 미구매 쓰기 차단, 프로필 분리 5개 검사 |
| `DaylogStoreKitTests/PioStoreKitIntegrationTests.swift` | 원래 11개 메서드 유지, 모든 manager teardown join, 세션 잔존 검사, 서명 오류 주입 순서, 중단 거래의 관측 시작을 구매 전으로 이동 |
| `DaylogStoreKitTests/PioStoreKitProcessRelaunchTests.swift` | 공개 동작 기반 실제 새 프로세스 검증, 진단 메타데이터 분리, 실제 선택 저장 파일 주입·검증. 소유권/선택 재주입 없음 |
| `DaylogStoreKitTests/PioStoreKitSDKContractTests.swift` | **신규/명시적 opt-in**, 앱 없는 취소·중단·마지막 finish·환불 대조 검사 |
| `DaylogStoreKitTests/PioStoreKitRefundOrderingTests.swift` | **신규/명시적 opt-in**, 환불 초기화 순서/API 차이 진단. 기존 11개 성공을 대체하지 않음 |
| 현재 QA 폴더 | 실행 로그, 결과 JSON, 재현 명령, 실패 원본, 독립 검토 및 보존 검사 |

`Tools/pio-storekit/process-relaunch.py` 자체는 이번 작업 시작점과 동일합니다. 상품 레지스트리, StoreKit 구성, AppearanceCoordinator, 옷장 디자인 및 애니메이션 코드는 변경하지 않았습니다.

## C. 기존 StoreKit 테스트별 최종 결과

아래 결과는 **11개 전체를 연속 실행한 각 3회에서 동일**합니다. 어느 테스트도 제외/삭제/성공으로 바꾸지 않았습니다.

| 기존 테스트 메서드 | 상태 | 근거 |
|---|---|---|
| `testConfigurationLoadsThirteenNonConsumablesAtKoreanDisplayPrice` | PASS | 13종 ID/비소모성/₩2,500 표시 |
| `testPurchaseDuplicateRelaunchAndRepeatedEquipmentUseVerifiedLedger` | PASS | 실제 구매·검증·중복 방지·착용·같은 프로세스 재생성 |
| `testPendingAskToBuyDoesNotUnlockUntilApprovedUpdate` | PASS | Pending 잠금, 승인 후 verified 업데이트 |
| `testRefundUpdateRevokesAccessAndRefreshResetsEquipment` | FAIL | raw 환불 알림 누락, 명시적 refresh 전 소유/착용 유지 |
| `testEveryPremiumOutfitPurchasesEquipsAndLoadsApprovedArtwork` | FAIL | 13종 구매/착용/기존 동작 검사는 통과하나 마지막 unfinished 잔존 |
| `testExplicitRestoreRecoversExternalPurchase` | PASS | 명시적 sync와 실제 권한 재조회 |
| `testCancellationFromStoreKitDoesNotUnlockOrShowFailure` | FAIL | 취소 주입이 공개 취소로 반환되지 않음 |
| `testPurchaseFailureLeavesLockedAndAllowsRetry` | PASS | 구매 오류 후 잠금·busy 해제·재시도 |
| `testProductLoadFailureAndRetryUseRealStoreKitAPI` | PASS | 조회 실패·구매 차단·다시 조회 |
| `testVerificationFailureNeverGrantsFreshManagerOwnership` | PASS | 거래 생성 전 서명 오류 주입, 검증 실패 시 미소유 |
| `testInterruptedPurchaseOnlyUnlocksAfterResolution` | FAIL | resolve 전 verified 거래/소유 관측, resolve 후 기대 이벤트 누락 |

취소·중단·환불·13종 완료·서명 검사를 각각 새 테스트 프로세스에서 독립 실행했습니다. 서명만 PASS, 나머지 네 검사는 독립 실행에서도 FAIL입니다. `runtime-series.json`과 `isolated-*.log`에 모든 결과가 있습니다.

## D. 안정성 검증

| 검증 | 결과 | 원본 |
|---|---|---|
| 전체 11개 연속 1회 | 7 PASS / 4 FAIL / 0 SKIP | `full-final-1.log`, `full-final-1-tests.json` |
| 전체 11개 연속 2회 | 7 PASS / 4 FAIL / 0 SKIP | `full-final-2.log`, `full-final-2-tests.json` |
| 전체 11개 연속 3회 | 7 PASS / 4 FAIL / 0 SKIP | `full-final-3.log`, `full-final-3-tests.json` |
| 실제 무작위 순서 11개 | 7 PASS / 4 FAIL / 0 SKIP | `full-random.log`, `random-xctestrun.plist` |
| 즉시 실제 OS 재실행 1회 | PASS, 거래 81, Cafe 복구 | `instant-fixed-1/` |
| 즉시 실제 OS 재실행 2회 | PASS, 거래 82, Cafe 복구 | `instant-fixed-2/` |
| 즉시 실제 OS 재실행 3회 | PASS, 거래 83, Cafe 복구 | `instant-fixed-3/` |

무작위 실행은 xctestrun의 문서화된 `TestExecutionOrdering=random`으로 실제 순서가 변경됐음을 로그에서 확인했습니다. 실패 재시도 기능은 사용하지 않았습니다. 기존 3초 acknowledgement 한도 및 10초 이벤트 기대 조건을 확장하지 않았습니다. [Apple 실행 순서 설명](https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback).

## E. 회귀 검사 및 보존

| 항목 | 결과 | 근거 |
|---|---|---|
| 기존 69 + 신규 8 단위·회귀 검사 | **PASS: 77/77, 7 suites** | `mac-unit-final-v2.log`, `/tmp/PioStoreKit-Stabilization-unit-final-v2.xcresult` |
| macOS Release 빌드 | PASS | `mac-release.log` |
| iOS Simulator Release 빌드 | PASS | `ios-release.log` |
| 실제 서명된 iPhone 기기 빌드/설치 | NOT_TESTED | 이번 범위에서 실행하지 않음 |
| 원화·rig·동작 파일 723개 | PASS, 변경/누락 0 | SHA-256 `preservation-before.json`, `preservation-after.json` |
| 13종 상품 ID/StoreKit 구성 | PASS, 이번 작업 변경 없음 | 시작점과 바이트 비교 |
| 기존 11개 테스트 유지 | PASS | 메서드 이름·수 비교, 제외 없음 |
| diff 공백 검사 | PASS | `git-diff-check.txt` |

환경: Xcode 27.1 (27A9275), macOS 27.0.1, 전용 iOS 27.0 (24A434) 시뮬레이터 `0426CD78-3807-4650-9776-B649780E2884` / `Pio StoreKit Local 2026-10-23`입니다. 설치된 다른 iOS 런타임은 없어 다른 SDK/OS 조합은 NOT_TESTED입니다. 다른 사용자 시뮬레이터나 운영 앱을 교체/초기화하지 않았습니다.

## F. 남은 위험 및 다음 검증

1. 네 로컬 통합 실패는 미해결입니다. 특히 환불 알림 수신·중단 거래 처리를 전체 완료라고 주장할 수 없습니다. 공개 SDK 최소 재현과 세션 순서 증거를 갖고 지원되는 다른 도구 체계/런타임에서 확인하고, 그 결과에 따라 앱 수정 여부를 결정해야 합니다. 이번에는 원인이 확정되지 않은 권한 로직을 추측으로 변경하지 않았습니다.
2. 실제 Apple Sandbox·실기기에서 정상 구매/시트 취소/중단·대기 승인/강제 종료 직후 재실행/복원/환불·취소/계정 변경/오프라인 복구/동시 이벤트를 검증해야 합니다. 모두 **NOT_TESTED**입니다.
3. 즉시 재실행 PASS는 Xcode 로컬 거래와 새 XCTest OS 프로세스 범위입니다. 강제 종료 시점·OS 전원 손실까지 보장하는 검증이 아닙니다.
4. 기존 ASC의 심사 메타데이터·앱 아이콘 제공 약속·판매 활성화 관련 이전 출시 제한은 이번에 변경하거나 재확인하지 않았습니다. 이 작업으로 판매 준비 완료가 되지 않습니다.

## G. 최종 판정

**PARTIAL — 즉시 재실행 결함과 확인된 코드·테스트 결함은 수정됐지만, 로컬 11/11 × 3회 기준은 미달입니다.**

검증된 StoreKit 거래만 소유권으로 인정하는 경계, 기본 무료 정책, 상품 13종, 기존 데이터/원화/UI를 보존했습니다. 실제 결제, ASC 수정, 운영 앱 교체, 커밋, push, 배포는 하지 않았습니다. HEAD는 시작과 같은 `34a989ce2d77fd1da4166a88992ac01d2e528527`입니다.
