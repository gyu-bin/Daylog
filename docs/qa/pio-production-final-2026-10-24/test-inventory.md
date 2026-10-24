# 실제 실행 테스트 인벤토리

현재 스냅샷: 2026-10-24T06:14:55.648097+00:00

**고유 실행 테스트 123개: XCTest 37개 + Swift Testing 86개.** 별도 opt-in 검사 3개는 SKIP만 관측돼 실행 개수에서 제외했다. 스킵 포함 발견된 식별자는 126개다. 같은 suite/method의 반복 실행과 Mac/iOS 모듈 차이는 합산하지 않았다. Swift Testing은 기존 회귀 77개와 별도 장면 검사 9개다. 이는 123/123 PASS 선언이 아니다. 각 기기별 마지막 관측 및 최초 실패 이력을 JSON에 보존했다.

집계 기준은 완료된 xcresult의 Test Case 식별자다. `System Failures / Daylog encountered an error`는 테스트 메서드가 아니므로 고유 개수에서 제외하고 환경 중단으로 기록한다. 스킵은 PASS가 아니다. 테스트 실행 PASS와 스크린샷·영상의 시각 QA PASS는 별도다.

## 실행별 결과

| 로그 | XCTest PASS / FAIL / SKIP | Swift Testing PASS / FAIL | 판정 |
|---|---:|---:|---|
| [SmallPhone-final-tests.log](SmallPhone-final-tests.log) | 1 / 0 / 0 | 0 / 0 | PASS |
| [SmallPhone-tests.log](SmallPhone-tests.log) | 0 / 0 / 0 | 0 / 0 | INTERRUPTED_ENVIRONMENT |
| [iPad-final-tests.log](iPad-final-tests.log) | 1 / 0 / 0 | 0 / 0 | PASS |
| [iPad-tests.log](iPad-tests.log) | 0 / 0 / 0 | 0 / 0 | INTERRUPTED_ENVIRONMENT |
| [iphone17-final-tests.log](iphone17-final-tests.log) | 0 / 0 / 0 | 0 / 0 | INTERRUPTED_ENVIRONMENT |
| [iphone17-final2-tests.log](iphone17-final2-tests.log) | 9 / 0 / 0 | 0 / 0 | PASS |
| [iphone17-tests.log](iphone17-tests.log) | 7 / 1 / 0 | 0 / 0 | FAIL |
| [mac-alias-regression-tests.log](mac-alias-regression-tests.log) | 6 / 0 / 0 | 0 / 0 | PASS |
| [mac-art-final-tests.log](mac-art-final-tests.log) | 11 / 0 / 0 | 9 / 0 | PASS |
| [mac-art-lifetime-tests.log](mac-art-lifetime-tests.log) | 4 / 3 / 0 | 0 / 0 | FAIL |
| [mac-corrected-tests.log](mac-corrected-tests.log) | 9 / 1 / 3 | 77 / 0 | FAIL |
| [mac-first-tests.log](mac-first-tests.log) | 8 / 1 / 0 | 75 / 2 | FAIL |
| [mac-performance-after-tests.log](mac-performance-after-tests.log) | 7 / 0 / 0 | 0 / 0 | PASS |
| [mac-performance-tests.log](mac-performance-tests.log) | 7 / 0 / 0 | 0 / 0 | PASS |
| [mac-visual-tests.log](mac-visual-tests.log) | 5 / 0 / 0 | 0 / 0 | PASS |

Mac에서 실제 실행된 고유 120개는 마지막 관측 PASS이며, 별도 opt-in 3개는 SKIP 상태다. 나머지 3개는 iOS Simulator에서만 실행됐다. 이는 단일 실행 120/120이 아니라 여러 focused 실행을 중복 제거한 관측이다. iPhone17 최초 실행은 7 PASS / 1 FAIL이었다. 별도 최종2 실행에서 동일 실패 검사를 포함해 9/9 PASS했으므로 해당 테스트의 미해결 상태를 해제했다. Mac PASS로 iPhone 실패를 대체한 것이 아니다. 화면의 시각 품질은 이 판정과 별도다.

## 실패·수정 이력

| 검사 | 첫 실패 및 수정 근거 | 현재 판정 |
|---|---|---|
| cloud intact scroll subtree | Mac clip 강한 참조 순환 재현, 미사용 ancestor 배열 제거 | Mac PASS |
| vacation SwiftUI subtree | autorelease fixture 참조 범위 문제, 생성/레이아웃/탐색 scope 수정 | Mac PASS |
| plain SwiftUI control | 동기 창 보임 가정, 조건 기반 visibility gate 수정 | Mac PASS |
| appearance 2개 Swift Testing | cloud production 승격 전 계약을 가정한 기대값, 구현 계약에 맞게 보정 | 수정 후 기존 77/77 PASS |
| vacation native eye 2개 | 첫 candidate/production native frame 검사 실패 로그 보존 | mac-art-final에서 재검사 PASS; 이미지 품질은 별도 VISUAL-REVIEW |
| cloud batch blink/held | iPhone17 첫 reopened 검증 실패 | iPhone17-final2 실제 재검사 PASS; 시각 QA 별도 |

## Simulator 중단과 재실행

`iphone17-final`, `SmallPhone`, `iPad` 최초 시도는 시작 환경이 약 6분 동안 멈춰 조정자가 중단했다. 완료 xcresult에는 Testing was canceled 등의 합성 오류만 있고 실행된 메서드는 0개다. 앱 로직 FAIL로 판정하지 않는다. 로그의 simulator service hub 연결 오류와 중단 이력은 그대로 보존했다.

`iPhone17-final2`는 9/9 PASS로 완료됐다. `SmallPhone-final` 및 `iPad-final`도 각각 1/1 PASS했다. 각각의 실제 화면 캡처 실행이 완료됐으나, 전체 UI의 접근성·시각 품질 승인과 동일하지 않다. 작은 iPhone/iPad 화면 캡처 fixture 수정 여부와 실제 검토 결과도 별도로 확인해야 한다. 이전 중단 실행을 성공으로 덮어쓰지 않았고, 후속 성공 실행의 증거를 별도로 기록했다.

## 실제 Mac 창 상태 증거

`mac-alias-regression-attachments/EEE56C12-0C1F-42E0-9987-914EAD7AF32A.json`을 xcresult에서 직접 추출했다. before-front false → front true → orderOut false → restore true → miniaturize false → deminiaturize true를 기록했고 모든 host callback이 expectedGate와 일치했다. visible occlusion은 8194, 숨김은 8192였다. appActive=false 상태에서도 실제 창 가시성을 판정했다. 이 검사는 앱 전체 foreground/background CPU 측정을 의미하지 않는다.

## 고유 테스트 목록

| ID | 프레임워크 | 최초 실패 존재 | 마지막 기기별 관측 |
|---|---|---|---|
| `PioAppIconTests/cancellationIsSilentAndPendingNeverSaysOwned()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioAppIconTests/missingPremiumIconFilesCannotBeSelected()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioAppearanceTests/allFourteenCatalogEntriesResolveTheirApprovedArtwork()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioAppearanceTests/appearanceReadsTrackWardrobeAndLiveGrowthChanges()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioAppearanceTests/approvedLayeredPilotRemainsExplicitAndDoesNotInventGrowthStages()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioAppearanceTests/composedScenesKeepRegisteredOriginalAndReportEveryMissingCostumePose()` | Swift Testing | 예 | macOS / My Mac: Passed |
| `PioAppearanceTests/fallbackMotionsNeverClaimIndependentWingsOrWalking()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioAppearanceTests/growthSourceIsLiveAndAllScreenReadsUseIt()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioAppearanceTests/legacyMockOwnershipCannotAuthorizeGlobalAppearance()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioAppearanceTests/missingSourceArtworkAndAbsentWidgetSurfacesAreExplicit()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioAppearanceTests/outfitAndAppIconStayIndependentAfterRefreshAndReopen()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioAppearanceTests/previewsNeverAuthorizeEquipOrChangeGlobalAppearance()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioAppearanceTests/stageBoundariesMatchApprovedGrowthWithoutChangingCostume()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioAppearanceTests/standingOutfitsAreNeverCompositedAsRecliningOrSleeping()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioAppearanceTests/testingModeAuthorizesAllCostumesWithoutVerifiedAccess()` | Swift Testing | 예 | macOS / My Mac: Passed |
| `PioAppearanceTests/unknownPreferencesNeverGrantPaidAppearanceOrEraseSelection()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioCloudCandidateReviewTests/testActualPresentationSequence()` | XCTest | 아니오 | macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed |
| `PioCloudCandidateReviewTests/testBatchActualIndependentBlinkAndHeldPresentation()` | XCTest | 예 | macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed |
| `PioCloudCandidateReviewTests/testBatchCandidateRegistrationNeutralAndStop()` | XCTest | 아니오 | macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed |
| `PioCloudProductionTests/testFourteenProductionRegistrationsAndIndependentHold()` | XCTest | 아니오 | macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed |
| `PioCloudProductionTests/testFourteenProductionTransitionsSuppressionAndReduceMotion()` | XCTest | 아니오 | macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed |
| `PioCloudProductionTests/testProductionAppearanceAdapterPreservesAuthorizationAndNotes()` | XCTest | 아니오 | macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed |
| `PioCloudProductionTests/testProductionBasicLiveAndStoppedObservations()` | XCTest | 아니오 | macOS / My Mac: Skipped |
| `PioCloudProductionTests/testProductionOffscreenWindowDetachStopsTracks()` | XCTest | 아니오 | macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed |
| `PioCloudProductionTests/testProductionReduceMotionSuppressionAndSceneStop()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioCloudProductionTests/testProductionRepeatedAttachDetachObservations()` | XCTest | 아니오 | macOS / My Mac: Skipped |
| `PioCloudProductionTests/testSmallProductionPackAndIndependentEyeFrames()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioCloudProductionTests/testVisibleNativeSceneHostForScreenshot()` | XCTest | 아니오 | macOS / My Mac: Skipped |
| `PioCloudTextureAliasesTests/testAllRegisteredProductionTexturesHaveIdempotentAliases()` | XCTest | 아니오 | macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed |
| `PioCloudTextureAliasesTests/testEveryCanonicalTextureHasIdenticalNativeDecodedPixels()` | XCTest | 아니오 | macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed |
| `PioHeaderCompletionTests/testGestureAutomaticallyReturnsToIdleWithoutAnotherTap()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioHeaderInteractionTests/testLeavingScreenCancelsAndRejectsStaleCompletion()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioHeaderInteractionTests/testNativeHeaderReusesJointsWithTinyIdleAndFiniteTapTracks()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioHeaderInteractionTests/testProductionFallbackUsesOnlyAvailableMotionsForAllOutfits()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioHeaderInteractionTests/testProgressReactionDoesNotConsumeTapSequence()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioHeaderInteractionTests/testResponsesAreBoundedAndDoNotOverlap()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioMacStabilityReviewTests/testActualWindowVisibilityTransitions()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioOutfitMotionTests/activeTelemetrySurvivesResetAndDoesNotRetainDestroyedRigs()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioOutfitMotionTests/capabilitiesNeverPretendCostumesHaveIndependentPartsOrGrowthArt()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioOutfitMotionTests/decodedArtworkIsReusedAndUnsupportedWaveFallsBackHonestly()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioOutfitMotionTests/unchangedUpdatesAndPartialStageChangesDoNotReconfigureOrDecode()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioOutfitMotionTests/visibilityPauseAndReduceMotionRemoveAllTracksIncludingTheBasicWing()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioOverhaulRigTests/allFourteenOutfitsResolveWithoutReplacingOriginalPilots()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioOverhaulRigTests/eyeStatesAreExclusiveAndStayBehindOpticalLayers()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioOverhaulRigTests/heldPropsShareTheirHandJointAndAnimation()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioOverhaulRigTests/jumpBounceAndGreetingHaveDifferentVisibleTrajectories()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioOverhaulRigTests/landingRecoversWithoutStartingAnotherJump()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioOverhaulRigTests/motionChangesDoNotRebuildLayersAndStoppingRemovesAllTracks()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioOverhaulRigTests/twoHandedPropsStayWithinValidatedRotation()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioProductRegistryTests/artworkAndPreferenceKeysRemainIndependentOfRegisteredProductNames()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioProductRegistryTests/everyPaidOutfitMapsOnceAndBasicIsNotAProduct()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioProductionFinalLifecycleTests/testFiftyVisibleCloudAttachDetachCycles()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioProductionFinalLifecycleTests/testFourteenOutfitsThreeVisibleSequentialPasses()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioProductionFinalLifecycleTests/testHomeReferenceFourteenOutfitsTwoVisiblePasses()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioProductionFinalLifecycleTests/testMacIntactScrollSubtreeReleasesNativeHost()` | XCTest | 예 | macOS / My Mac: Passed |
| `PioProductionFinalLifecycleTests/testMacPlainSwiftUIScrollSubtreeOwnershipControl()` | XCTest | 예 | macOS / My Mac: Passed |
| `PioProductionFinalLifecycleTests/testMacVacationSwiftUIScrollSubtreeReleasesNativeView()` | XCTest | 예 | macOS / My Mac: Passed |
| `PioProductionFinalLifecycleTests/testPairedVisibleActiveStoppedProcessObservations()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioProductionFinalLifecycleTests/testTenVisibleCloudAttachDetachCycles()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioProductionFinalLifecycleTests/testTwentyVisibleCloudAttachDetachCycles()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioProductionFinalLifecycleTests/testVacationFourteenDayNightTwoVisiblePasses()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioProductionFinalScreenTests/testActualDeviceScreensAndAccessibilityLayouts()` | XCTest | 아니오 | iOS Simulator / Pio Motion Review 2026-10-23: Passed; iOS Simulator / Pio Small Phone QA 2026-10-24: Passed; iOS Simulator / Pio iPad QA 2026-10-24: Passed |
| `PioProductionFinalVisualTests/testFourteenHomeProductionMotionFrames()` | XCTest | 아니오 | macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed |
| `PioProductionFinalVisualTests/testFourteenVacationDayNightActualMotionFrames()` | XCTest | 아니오 | macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed |
| `PioPurchaseTests/cancellationPendingAndVerificationFailureNeverUnlock()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/concurrentFinishCallersWaitForOneAcknowledgementAndCleanUp()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/confirmedAbsenceRevokesAndPreservesOtherPreferences()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/disabledGateNeverTouchesStoreOrImportsMocks()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/duplicateTapsAndRestoreDuringPaymentAreRejected()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/environmentPoliciesNeverMixLocalAndAppleTransactions()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/explicitStopIsIdempotentAndManagerCanRestartItsListener()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/lateRefundOfOldTransactionPreservesRepurchasedOutfitAndPreference()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/localTestingPreferencesNeverChangeProductionSelections()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/managerLifetimeDoesNotRetainOldTransactionListener()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/mismatchedOrRevokedPurchaseResultNeverUnlocks()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/productFailureCanBeRetried()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/productsUseLocalizedPricesAndMissingProductsCannotBePurchased()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/publicNestedCancellationIsRecognizedWithoutPrivateServerCodeMapping()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/purchaseErrorsClearBusyStateAndCanRetry()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/purchaseRevokedWhileFinishingCannotReportSuccess()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/refreshFailureRetainsPreviouslyVerifiedOwnership()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/registryMatchesApprovedCatalogAndOnlyNonBasicProducts()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/reopenWaitsForVerifiedLedgerAndNeverTrustsMockDefaults()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/restoreIsExplicitHandlesEmptySuccessAndCancellation()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/restoreJoiningRefreshWaitsForStableSnapshotAfterUpdate()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/restoreRequiresPostSyncSnapshotEvenWithoutTransactionUpdate()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/revokedSnapshotCannotBeUndoneByDelayedVerifiedUpdate()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/stalePurchaseResultForPreviouslyRevokedIDNeverReportsPurchased()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/stopWaitsForAnAlreadyDeliveredVerifiedTransactionToFinish()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/successfulPurchaseGrantsAndFinishesOnlyVerifiedTransaction()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/transactionUpdatesDeliverPendingPurchaseAndRefund()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/unconfirmedOrUnknownCatalogConfigurationStaysDisabled()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioPurchaseTests/unverifiedSnapshotCannotGrantOrReportSuccessfulRestore()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioVacationFinalArtworkTests/testBasicDayProductionEyesNativePlayback()` | XCTest | 예 | macOS / My Mac: Passed |
| `PioVacationFinalArtworkTests/testBasicDayProductionEyesPreserveNightPaidAndLifecycle()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioVacationFinalArtworkTests/testNativeEyeCandidateActualPresentationSequence()` | XCTest | 예 | macOS / My Mac: Passed |
| `PioVacationFinalArtworkTests/testNativePreciselyReconstructedEyeRegions()` | XCTest | 아니오 | macOS / My Mac: Passed |
| `PioVacationProductionTests/testBasicDayEyeResourcesAndLifecycle()` | XCTest | 아니오 | iOS Simulator / Pio Motion Review 2026-10-23: Passed |
| `PioVacationProductionTests/testBasicDayEyesActualUIKitPresentationAt64And220()` | XCTest | 아니오 | iOS Simulator / Pio Motion Review 2026-10-23: Passed |
| `PioVacationSceneIntegrationTests/allThirteenOutfitsHaveNativeDayAndNightArtworkWithTransparentPixels()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioVacationSceneIntegrationTests/everyCandidateRegistrationKeepsPivotFixedAndBeachStationaryAtSwayExtremes()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioVacationSceneIntegrationTests/pendingVerificationShowsOnlyBeachAndStopsAnyPreviousForegroundMotion()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioVacationSceneIntegrationTests/reduceMotionAndInactiveOrInvisibleScenesRemoveForegroundAnimation()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/basicIsAlwaysFreeAndUnownedSelectionsAreRejected()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/catalogHasFourteenUniqueHonestEntries()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/corruptOrUnsupportedSelectionFallsBackWithoutGrantingOwnership()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/durableLastSelectionSurvivesReopenButRequiresFreshVerifiedOwnership()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/durableSelectionProfilesCannotOverwriteOneAnother()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/everyCatalogArtworkLoadsFromTheAppBundleAtFullResolution()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/failedDurableWriteRejectsEquipAndPreservesPreviousPreference()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/invalidOrUnownedStoredSelectionsFallBackSafely()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/mockOwnershipPersistsWhileOutfitAndIconStayIndependent()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/outfitTestingAllowsEveryCostumeWithoutOwnershipOrIcons()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/outfitTestingPreferencesAreSeparateAndSurviveEntitlementRepair()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/outfitTestingRequiresExactExplicitFlag()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/previewStagePersistsWithoutChangingOwnershipOrOutfit()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/productionEntitlementBoundaryIsUnavailable()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/rejectedUnownedEquipNeverTouchesDurableOrLegacyPreferences()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/stagePreviewAndLevelBoundariesNeverClearAnOwnedOutfit()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/unavailableShopNeverGrantsPaidWearingAndPreservesPreferences()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `PioWardrobeTests/unknownMockIDsCannotBecomeOwnedAndResetRepairsOnlyUnownedSelections()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `RoutimoriSyncTests/repeatedUpdatesDoNotAccumulateTracksAndActivityStops()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `RoutimoriSyncTests/sceneTransitionReplacesMotionAndReduceMotionStopsEveryLayer()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `RoutimoriVacationTests/changingTimeOfDaySelectsRegisteredArtworkWithoutRestartingSway()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `RoutimoriVacationTests/registeredImagesStayAlignedAndTheRopeAnchorDoesNotMove()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
| `RoutimoriVacationTests/swayStopsRestoresAndNeverAnimatesTheBeach()` | Swift Testing | 아니오 | macOS / My Mac: Passed |
