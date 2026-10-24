# 실제 검증된 로컬 권한과 장면 통합 검사

## 실행 결과: PARTIAL — 검증 환경 차단, 유료 52조합 미검증

새 `PioCharacterVerifiedSceneIntegrationTests`는 소유권 mock을 사용하지 않는다. `SKTestSession.buyProduct`로 Apple Xcode 로컬 거래를 준비한 뒤 `Transaction.currentEntitlements`에서 `.verified`, `.xcode`, 같은 transaction ID, revocation 없음이 확인된 경우만 앱의 실제 `PioPurchaseManager.shared`가 권한을 읽는다. 상품 누락이나 검증 실패는 FAIL이며 preview 또는 테스트 착용으로 대체하지 않는다.

## 안전 조건

- opt-in 인수 `-PioCharacterVerifiedScenes -pio-storekit-testing`
- 환경 `PIO_CHARACTER_ISOLATED_TEST_HOST=YES`
- XCTest runtime, Mac은 `com.daylog.verify`, iOS는 Simulator만 허용
- `-pio-wardrobe-testing` 및 Overhaul trial 거부
- verified AppTransaction의 environment `.xcode`를 확인한 뒤에만 local session 초기화
- `PioWardrobeStore.localTestingPreferencesSuite`만 backup/restore
- XCTest에서는 `PioWardrobeSelectionFile.current`가 nil이므로 shared production/local selection 파일을 쓰지 않음
- 별도 재생성 검사는 UUID UserDefaults 및 UUID 임시 selection 파일을 사용하고 종료 시 정리
- SwiftData는 `.inMemory`; 실제 사용자 기록, CloudKit, 실제 구매, Sandbox, App Store Connect 접근 없음
- teardown에서 manager.stop 완료 후 local ledger 초기화

## 새 테스트

1. `testVerifiedSharedFourteenOutfitsAcrossFiftySixNativeScenes`
   - 무료 basic + 유료 13종의 실제 verified 권한으로 shared wardrobe equip
   - shared coordinator의 요청 의상·허가 의상·access를 검사
   - 실제 `PioHeaderCompanion`, `RoutimoriSyncScene`, `RoutimoriVacationScene` SwiftUI/native 구성요소를 화면에 표시
   - 14 × 홈/클라우드 수신/휴가 낮/휴가 밤 = 56조합
   - actual visible + native animation tracks 확인 후 PNG 저장
   - scenePhase inactive에서 tracks0, active 복귀에서 재생 및 의상 유지
   - 상품별 실패를 기록하고 나머지 의상을 독립적으로 계속 검사
2. `testGenuineSavedSelectionRemainsHiddenUntilFreshManagerVerifies`
   - 검증된 cafe 거래를 실제 manager로 읽은 뒤 정상 equip API가 UUID selection 파일을 저장
   - 새로운 manager는 basic만 소유, 저장된 cafe는 checking 상태를 유지
   - 권한 확인 후 cafe/verified로 복구
   - 이 검사는 같은 프로세스 내 객체 재생성이다. OS 재실행으로 보고하지 않는다.

`SKTestSession.buyProduct`는 로컬 fixture 준비이며 `Product.purchase` UI 통과나 Sandbox 구매 성공의 증거가 아니다. 실제 shared 장면 구성요소를 사용하지만 옷장 클릭→전체 앱 navigation→CloudKit 동기화 E2E와도 구분한다. scenePhase 주입은 OS background 전환이 아니다.

## 실제 OS 재실행

기존 `PioStoreKitProcessRelaunchTests`를 수정 없이 재사용한다.

- 인수 `-pio-storekit-process-relaunch -pio-storekit-testing`
- 두 프로세스에 같은 fresh UUID `PIO_RELAUNCH_RUN_ID`
- 첫 실행 `PIO_RELAUNCH_PHASE=seed`, `PIO_RELAUNCH_SEED_METHOD=storekit-test`
- 두번째 실행 `PIO_RELAUNCH_PHASE=verify` (같은 seed method 값 유지 가능)
- seed selector `testSeedVerifiedLedgerInFirstProcess`
- verify selector `testVerifyLedgerAndEquipmentInFreshProcess`
- 실제 다른 PID, 같은 verified 거래 ID, 실제 저장된 선택 파일과 마지막 착용 상태를 검사
- verify 전 거래 초기화·재구매·restore 호출 없음; verify 종료 후 local ledger/UUID 파일 정리

이 기존 fixture는 cafe 한 종의 실제 재실행 검증이다. 14종 전체 재실행이나 전체 앱 UI E2E로 확대하지 않는다. 현재 SDK의 알려진 StoreKit 실패 4개는 이 작업에서 해결했다고 표시하지 않는다.

## 실행 분리

이 파일과 기존 재실행 검사는 native pixel 전수 검사·quiet 7성능 검사와 별도 프로세스에서 직렬 실행한다. 실제 실행 결과와 증거 경로는 완료 후 추가한다.

## 실제 실행 증거 (2026-10-24)

| 환경·검사 | 실제 실행 결과 | 해석 |
|---|---|---|
| Mac shared 56 matrix | FAIL, 기본 4조합만 렌더 성공 | 13상품 모두 SKTestSession.buyProduct 단계에서 notEntitled; 유료 52조합 미실행 |
| Mac fresh manager restore | FAIL | cafe fixture seed notEntitled로 재생성 본문 미실행 |
| iPhone Simulator 두 검사 | FAIL (setUp) | AppTransaction 검증 인증서 체인 실패, seed 이전 차단 |
| 새 OS 2-process cafe 재실행 | NOT_TESTED | 동일 verified 환경 전제 조건이 막혀 추가 구매 시도 중단 |
| 실제 Apple Sandbox / 실기기 | NOT_TESTED | 실행하지 않음 |

Mac 원본: `mac-verified-tests.log`, `/tmp/PioCharacterFinal-Mac-verified-20261024.xcresult`, `mac-verified-attachments/manifest.json`. `.xcode` AppTransaction guard는 통과했지만 fixture 구매 API가 모든 13상품에서 `notEntitled`를 반환했다. 현재 unsigned/no-entitlement test host 설정이 가능한 조사 대상이지만, 서명 설정만을 확정 원인으로 단정하지 않는다. 앱 purchase/verification 로직이 실행되기 전 실패여서 앱 소유권 결함으로 판정할 근거는 없다. 최소 SDK 하네스 대조도 이번에 수행하지 않았으므로 SDK_DEPENDENT로 분류하지 않는다.

Mac 기본 4조합은 실제 shared state, access=free로 홈 15 / 클라우드 9 / 휴가 낮 5 / 휴가 밤 1 active tracks를 관측했다. scenePhase inactive에서는 모두 0, 복귀 시 재생됨을 검사했다. JSON `mac-verified-attachments/5F80421E-2109-4B11-AB5B-0D0741037912.json`과 실제 PNG 4장이 증거다. 이 결과는 해당 실행 시점 코드의 기능 관측이며 최종 원화 승격 이후의 시각 판정을 대신하지 않는다.

iPhone 원본: `iphone-verified-tests.log:17–26`, `/tmp/PioCharacterFinal-iPhone-verified-20261024.xcresult`. Apple 로그의 `NSOSStatusErrorDomain -67818`, `‘StoreKit Testing in Xcode’ 인증서가 만료됨`, `failedToVerifyCertificateChain`이 확인되었다. fixture의 `wrongEnvironment`는 검증 실패 시 닫히는 guard 오류다. 실제 관측은 **환경의 인증서 검증 차단**이며 `.xcode`라고 주장한 미검증 payload를 허용하지 않았다. XCTest 요약에 skipped와 failures가 함께 표시되지만 성공/정상 skip으로 보고하지 않는다. setUp 실패 2건이다. iPhone 첨부 export는 manifest만 생성되었고 이미지/거래 첨부는 없었다.

검증 우회, 시간 변경, 보안 설정 완화, 임의 소유권 부여를 하지 않았다. 이 환경에서 동일 구매 시도를 반복하지 않는다. 안전한 다음 단계는 Xcode 로컬 StoreKit 인증서/서명 환경을 Apple 지원 방식으로 정상화한 별도 테스트 호스트에서 같은 guard를 유지하여 재검증하는 것이다. 현 환경에서 통과가 입증된 대체 구성은 없다. 실제 Sandbox 결과와 로컬 인증서 문제는 별개이며 Sandbox 완료로 간주할 수 없다.
