# 실제 실행 테스트 목록

현재 실행 증거 스냅샷이다. suite/method ID 기준 고유 개수이며 재실행·플랫폼 중복을 합산하지 않는다. 스크린샷 생성 PASS는 최종 시각 승인이나 실제 구매 E2E PASS가 아니다.

실행된 고유 테스트 **134개**, 프레임워크 {'Swift Testing': 98, 'XCTest': 36}.

| 로그 | 실제 결과 | 원본 xcresult |
|---|---|---|
|ipad-portrait-final-tests.log|PASS {'Passed': 1}|/tmp/PioCharacterFinal-iPad-portrait-final-20261024.xcresult|
|ipad-recheck-tests.log|FAIL {'Failed': 1, 'Passed': 1}|/tmp/PioCharacterFinal-iPad-recheck-20261024.xcresult|
|ipad-tests.log|FAIL {'Failed': 1, 'Passed': 1}|/tmp/PioCharacterFinal-iPad-20261024.xcresult|
|iphone-candidates-tests.log|PASS {'Passed': 4}|/tmp/PioCharacterFinal-iPhone-candidates-20261024.xcresult|
|iphone-final-tests.log|PASS {'Passed': 7}|/tmp/PioCharacterFinal-iPhone-final-20261024.xcresult|
|iphone-first-tests.log|PASS {'Passed': 4}|/tmp/PioCharacterFinal-iPhone-first-20261024.xcresult|
|iphone-live-tests.log|PASS {'Passed': 1}|/tmp/PioCharacterFinal-iPhone-live-20261024.xcresult|
|iphone-vacation-c7-tests.log|PASS {'Passed': 8}|/tmp/PioCharacterFinal-iPhone-vacationC7-20261024.xcresult|
|iphone-verified-tests.log|FAIL {'Failed': 2}|/tmp/PioCharacterFinal-iPhone-verified-20261024.xcresult|
|mac-candidates-tests.log|PASS {'Passed': 9}|/tmp/PioCharacterFinal-Mac-candidates-20261024.xcresult|
|mac-extra-candidates-tests.log|PASS {'Passed': 3}|/tmp/PioCharacterFinal-Mac-extra-candidates-20261024.xcresult|
|mac-first-tests.log|FAIL {'Passed': 15, 'Failed': 1}|/tmp/PioCharacterFinal-Mac-first-20261024.xcresult|
|mac-home-fixes-tests.log|FAIL {'Passed': 7, 'Failed': 1}|/tmp/PioCharacterFinal-Mac-home-fixes-20261024.xcresult|
|mac-home-hosted-C8-tests.log|PASS {'Passed': 8}|/tmp/PioCharacterFinal-Mac-home-hosted-C8-20261024.xcresult|
|mac-home-performance-final-tests.log|PASS {'Passed': 1}|/tmp/PioCharacterFinal-Mac-home-performance-final-20261024.xcresult|
|mac-home-performance-tests.log|FAIL {'Failed': 1}|/tmp/PioCharacterFinal-Mac-home-performance-20261024.xcresult|
|mac-native-screens-C8-tests.log|PASS {'Passed': 1}|/tmp/PioCharacterFinal-Mac-native-screens-C8-20261024.xcresult|
|mac-performance-final-tests.log|PASS {'Passed': 7}|/tmp/PioCharacterFinal-Mac-performance-final-20261024.xcresult|
|mac-regression-final-tests.log|PASS {'Passed': 107}|/tmp/PioCharacterFinal-Mac-regression-final-20261024.xcresult|
|mac-regression-tests.log|PASS {'Passed': 101}|/tmp/PioCharacterFinal-Mac-regression-20261024.xcresult|
|mac-screens-C8-tests.log|NOT_TESTED_ZERO_METHODS {}|/tmp/PioCharacterFinal-Mac-screens-C8-20261024.xcresult|
|mac-verified-tests.log|FAIL {'Failed': 2}|/tmp/PioCharacterFinal-Mac-verified-20261024.xcresult|
|smallphone-c7-tests.log|PASS {'Passed': 2}|/tmp/PioCharacterFinal-SmallPhone-C7-20261024.xcresult|

## 실패와 제약

- Mac 첫 홈 제스처 정착 검사 실패의 로그를 보존한다. 최신 기기별 동일 메서드 결과를 아래에서 확인한다.
- Mac 첫 홈 성능은 즉시 해제 assertion28건, 메서드1개 FAIL이다. 조건 기반 weak 해제 관측으로 수정 후 최종1/1PASS. 실제 해제/CPU/RSS 세부는 PERFORMANCE.md.
- Mac verified2개 FAIL: 로컬 seed notEntitled. 기본4조합만 검증, 유료52조합·복원 미검증.
- iPhone verified2개 setUp 인증서 체인 실패. 로그에 skip 수가 함께 있어도 PASS/정상skip 아님.
- 첫 iPad는 로그 INTERRUPTED이나 xcresult PASS1/FAIL1을 보존했다. orientation fixture 수정 후 결과가 있다면 아래 최신 기기별 결과와 별도로 읽는다.
- 실제 Sandbox 및 이번 OS2-process 재실행 NOT_TESTED. 이전 PASS를 승계하지 않는다.

## 고유 테스트와 최신 기기별 상태

| 테스트 | 프레임워크 | 최신 관측 | 과거 실패 |
|---|---|---|---|
|`PioAppIconTests/cancellationIsSilentAndPendingNeverSaysOwned()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioAppIconTests/missingPremiumIconFilesCannotBeSelected()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioAppearanceTests/allFourteenCatalogEntriesResolveTheirApprovedArtwork()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioAppearanceTests/appearanceReadsTrackWardrobeAndLiveGrowthChanges()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioAppearanceTests/approvedLayeredPilotRemainsExplicitAndDoesNotInventGrowthStages()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioAppearanceTests/composedScenesKeepRegisteredOriginalAndReportEveryMissingCostumePose()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioAppearanceTests/fallbackMotionsNeverClaimIndependentWingsOrWalking()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioAppearanceTests/growthSourceIsLiveAndAllScreenReadsUseIt()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioAppearanceTests/legacyMockOwnershipCannotAuthorizeGlobalAppearance()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioAppearanceTests/missingSourceArtworkAndAbsentWidgetSurfacesAreExplicit()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioAppearanceTests/outfitAndAppIconStayIndependentAfterRefreshAndReopen()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioAppearanceTests/previewsNeverAuthorizeEquipOrChangeGlobalAppearance()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioAppearanceTests/stageBoundariesMatchApprovedGrowthWithoutChangingCostume()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioAppearanceTests/standingOutfitsAreNeverCompositedAsRecliningOrSleeping()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioAppearanceTests/testingModeAuthorizesAllCostumesWithoutVerifiedAccess()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioAppearanceTests/unknownPreferencesNeverGrantPaidAppearanceOrEraseSelection()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioCharacterDeviceLayoutTests/testIPadActualPortraitLandscapeAndReturn()`|XCTest|iOS Simulator / Pio iPad QA 2026-10-24: Failed|있음|
|`PioCharacterDeviceLayoutTests/testLargeTextScreensCanScrollToTheirContentEnd()`|XCTest|iOS Simulator / Pio Motion Review 2026-10-23: Passed; iOS Simulator / Pio iPad QA 2026-10-24: Passed; iOS Simulator / Pio Small Phone QA 2026-10-24: Passed|없음|
|`PioCharacterDeviceLayoutTests/testLiveVacationScreensForExternalFrameBufferCapture()`|XCTest|iOS Simulator / Pio Motion Review 2026-10-23: Passed|없음|
|`PioCharacterHomeNativeReviewTests/testAllFourteenHomeIndependentPresentationAt64And220()`|XCTest|macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed|없음|
|`PioCharacterHomeNativeReviewTests/testThreeAuthoredGesturesActuallySettleAfterPlayback()`|XCTest|macOS / My Mac: Passed|있음|
|`PioCharacterHomePerformanceTests/testProductionHomeFourteenOutfitsTwiceAndPairedIdleStop()`|XCTest|macOS / My Mac: Passed|있음|
|`PioCharacterMacScreenTests/testOrdinaryMacScreensAtTwoActualWindowSizes()`|XCTest|macOS / My Mac: Passed|없음|
|`PioCharacterVerifiedSceneIntegrationTests/testGenuineSavedSelectionRemainsHiddenUntilFreshManagerVerifies()`|XCTest|macOS / My Mac: Failed; iOS Simulator / Pio Motion Review 2026-10-23: Failed|있음|
|`PioCharacterVerifiedSceneIntegrationTests/testVerifiedSharedFourteenOutfitsAcrossFiftySixNativeScenes()`|XCTest|macOS / My Mac: Failed; iOS Simulator / Pio Motion Review 2026-10-23: Failed|있음|
|`PioCloudProductionTests/testFourteenProductionRegistrationsAndIndependentHold()`|XCTest|macOS / My Mac: Passed|없음|
|`PioCloudProductionTests/testFourteenProductionTransitionsSuppressionAndReduceMotion()`|XCTest|macOS / My Mac: Passed|없음|
|`PioCloudProductionTests/testProductionAppearanceAdapterPreservesAuthorizationAndNotes()`|XCTest|macOS / My Mac: Passed|없음|
|`PioHeaderCompletionTests/testGestureAutomaticallyReturnsToIdleWithoutAnotherTap()`|XCTest|macOS / My Mac: Passed|없음|
|`PioHeaderInteractionTests/testLeavingScreenCancelsAndRejectsStaleCompletion()`|XCTest|macOS / My Mac: Passed|없음|
|`PioHeaderInteractionTests/testNativeHeaderReusesJointsWithTinyIdleAndFiniteTapTracks()`|XCTest|macOS / My Mac: Passed|없음|
|`PioHeaderInteractionTests/testProductionFallbackUsesOnlyAvailableMotionsForAllOutfits()`|XCTest|macOS / My Mac: Passed|없음|
|`PioHeaderInteractionTests/testProgressReactionDoesNotConsumeTapSequence()`|XCTest|macOS / My Mac: Passed|없음|
|`PioHeaderInteractionTests/testResponsesAreBoundedAndDoNotOverlap()`|XCTest|macOS / My Mac: Passed|없음|
|`PioHomeProductionTests/all140ProductionTimelinesMatchProtectedCanonicalRig()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioHomeProductionTests/allFourteenRegistrationsHaveGenuineSizedLayers()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioHomeProductionTests/boundedActionsReturnToQuietIdleAndLifecycleStopsAllTracks()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioHomeProductionTests/firstInactiveRequestStartsWhenVisibleButPlayedRequestDoesNotReplay()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioHomeProductionTests/growthBubbleDismissalDoesNotCutOffAuthoredCelebration()`|Swift Testing|macOS / My Mac: Passed|있음|
|`PioHomeProductionTests/homeProductionDoesNotGrantPreviewOrUnverifiedPaidAccess()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioHomeProductionTests/outfitSwitchCancelsOldDeadlineWithoutInterruptingNewAction()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioHomeProductionTests/quietIdleHasIndependentSlowJointsWithoutTranslationHops()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioOutfitMotionTests/activeTelemetrySurvivesResetAndDoesNotRetainDestroyedRigs()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioOutfitMotionTests/capabilitiesNeverPretendCostumesHaveIndependentPartsOrGrowthArt()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioOutfitMotionTests/decodedArtworkIsReusedAndUnsupportedWaveFallsBackHonestly()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioOutfitMotionTests/unchangedUpdatesAndPartialStageChangesDoNotReconfigureOrDecode()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioOutfitMotionTests/visibilityPauseAndReduceMotionRemoveAllTracksIncludingTheBasicWing()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioOverhaulRigTests/allFourteenOutfitsResolveWithoutReplacingOriginalPilots()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioOverhaulRigTests/eyeStatesAreExclusiveAndStayBehindOpticalLayers()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioOverhaulRigTests/heldPropsShareTheirHandJointAndAnimation()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioOverhaulRigTests/jumpBounceAndGreetingHaveDifferentVisibleTrajectories()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioOverhaulRigTests/landingRecoversWithoutStartingAnotherJump()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioOverhaulRigTests/motionChangesDoNotRebuildLayersAndStoppingRemovesAllTracks()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioOverhaulRigTests/twoHandedPropsStayWithinValidatedRotation()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioProductRegistryTests/artworkAndPreferenceKeysRemainIndependentOfRegisteredProductNames()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioProductRegistryTests/everyPaidOutfitMapsOnceAndBasicIsNotAProduct()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioProductionFinalLifecycleTests/testFiftyVisibleCloudAttachDetachCycles()`|XCTest|macOS / My Mac: Passed|없음|
|`PioProductionFinalLifecycleTests/testFourteenOutfitsThreeVisibleSequentialPasses()`|XCTest|macOS / My Mac: Passed|없음|
|`PioProductionFinalLifecycleTests/testHomeReferenceFourteenOutfitsTwoVisiblePasses()`|XCTest|macOS / My Mac: Passed|없음|
|`PioProductionFinalLifecycleTests/testPairedVisibleActiveStoppedProcessObservations()`|XCTest|macOS / My Mac: Passed|없음|
|`PioProductionFinalLifecycleTests/testTenVisibleCloudAttachDetachCycles()`|XCTest|macOS / My Mac: Passed|없음|
|`PioProductionFinalLifecycleTests/testTwentyVisibleCloudAttachDetachCycles()`|XCTest|macOS / My Mac: Passed|없음|
|`PioProductionFinalLifecycleTests/testVacationFourteenDayNightTwoVisiblePasses()`|XCTest|macOS / My Mac: Passed|없음|
|`PioProductionFinalScreenTests/testActualDeviceScreensAndAccessibilityLayouts()`|XCTest|iOS Simulator / Pio Motion Review 2026-10-23: Passed; iOS Simulator / Pio Small Phone QA 2026-10-24: Passed; iOS Simulator / Pio iPad QA 2026-10-24: Passed|없음|
|`PioPurchaseTests/cancellationPendingAndVerificationFailureNeverUnlock()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/concurrentFinishCallersWaitForOneAcknowledgementAndCleanUp()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/confirmedAbsenceRevokesAndPreservesOtherPreferences()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/disabledGateNeverTouchesStoreOrImportsMocks()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/duplicateTapsAndRestoreDuringPaymentAreRejected()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/environmentPoliciesNeverMixLocalAndAppleTransactions()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/explicitStopIsIdempotentAndManagerCanRestartItsListener()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/lateRefundOfOldTransactionPreservesRepurchasedOutfitAndPreference()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/localTestingPreferencesNeverChangeProductionSelections()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/managerLifetimeDoesNotRetainOldTransactionListener()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/mismatchedOrRevokedPurchaseResultNeverUnlocks()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/productFailureCanBeRetried()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/productsUseLocalizedPricesAndMissingProductsCannotBePurchased()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/publicNestedCancellationIsRecognizedWithoutPrivateServerCodeMapping()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/purchaseErrorsClearBusyStateAndCanRetry()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/purchaseRevokedWhileFinishingCannotReportSuccess()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/refreshFailureRetainsPreviouslyVerifiedOwnership()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/registryMatchesApprovedCatalogAndOnlyNonBasicProducts()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/reopenWaitsForVerifiedLedgerAndNeverTrustsMockDefaults()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/restoreIsExplicitHandlesEmptySuccessAndCancellation()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/restoreJoiningRefreshWaitsForStableSnapshotAfterUpdate()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/restoreRequiresPostSyncSnapshotEvenWithoutTransactionUpdate()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/revokedSnapshotCannotBeUndoneByDelayedVerifiedUpdate()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/stalePurchaseResultForPreviouslyRevokedIDNeverReportsPurchased()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/stopWaitsForAnAlreadyDeliveredVerifiedTransactionToFinish()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/successfulPurchaseGrantsAndFinishesOnlyVerifiedTransaction()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/transactionUpdatesDeliverPendingPurchaseAndRefund()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/unconfirmedOrUnknownCatalogConfigurationStaysDisabled()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioPurchaseTests/unverifiedSnapshotCannotGrantOrReportSuccessfulRestore()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioVacationAnchorMotionTests/everyNativeTransformIsPlanarAndPreservesArea()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioVacationAnchorMotionTests/invalidOrAggressiveRegistrationIsRejected()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioVacationAnchorMotionTests/projectedCharacterMovementIsSmallAndExistingPeriodIsPreserved()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioVacationAnchorMotionTests/twoSourceAttachmentPointsStayFixedAcrossWholeHingeCycle()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioVacationComponentArtworkTests/testChristmasDayEyeRegistration()`|XCTest|macOS / My Mac: Passed|없음|
|`PioVacationComponentArtworkTests/testChristmasNightEyeRegistration()`|XCTest|macOS / My Mac: Passed|없음|
|`PioVacationComponentArtworkTests/testWinterNightEyeRegistration()`|XCTest|macOS / My Mac: Passed|없음|
|`PioVacationHingeNativeTests/testBasicDayNightHingeKeepsBothVisibleSourcePointsFixed()`|XCTest|macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed|없음|
|`PioVacationNightArtworkTests/testChristmasDayProductionLifecycleAndPresentation()`|XCTest|iOS Simulator / Pio Motion Review 2026-10-23: Passed; macOS / My Mac: Passed|없음|
|`PioVacationNightArtworkTests/testChristmasNightProductionLifecycleAndPresentation()`|XCTest|macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed|없음|
|`PioVacationNightArtworkTests/testNightCandidate1024StaticRegistration()`|XCTest|macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed|없음|
|`PioVacationNightArtworkTests/testNightCandidateNativePresentationAt64And220()`|XCTest|macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed|없음|
|`PioVacationNightArtworkTests/testNightCandidateResourcesAndLifecycle()`|XCTest|macOS / My Mac: Passed; iOS Simulator / Pio Motion Review 2026-10-23: Passed|없음|
|`PioVacationNightArtworkTests/testWinterNightProductionLifecycleAndPresentation()`|XCTest|iOS Simulator / Pio Motion Review 2026-10-23: Passed; macOS / My Mac: Passed|없음|
|`PioVacationSceneIntegrationTests/allThirteenOutfitsHaveNativeDayAndNightArtworkWithTransparentPixels()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioVacationSceneIntegrationTests/everyCandidateRegistrationKeepsPivotFixedAndBeachStationaryAtSwayExtremes()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioVacationSceneIntegrationTests/pendingVerificationShowsOnlyBeachAndStopsAnyPreviousForegroundMotion()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioVacationSceneIntegrationTests/reduceMotionAndInactiveOrInvisibleScenesRemoveForegroundAnimation()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/basicIsAlwaysFreeAndUnownedSelectionsAreRejected()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/catalogHasFourteenUniqueHonestEntries()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/corruptOrUnsupportedSelectionFallsBackWithoutGrantingOwnership()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/durableLastSelectionSurvivesReopenButRequiresFreshVerifiedOwnership()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/durableSelectionProfilesCannotOverwriteOneAnother()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/everyCatalogArtworkLoadsFromTheAppBundleAtFullResolution()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/failedDurableWriteRejectsEquipAndPreservesPreviousPreference()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/invalidOrUnownedStoredSelectionsFallBackSafely()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/mockOwnershipPersistsWhileOutfitAndIconStayIndependent()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/outfitTestingAllowsEveryCostumeWithoutOwnershipOrIcons()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/outfitTestingPreferencesAreSeparateAndSurviveEntitlementRepair()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/outfitTestingRequiresExactExplicitFlag()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/previewStagePersistsWithoutChangingOwnershipOrOutfit()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/productionEntitlementBoundaryIsUnavailable()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/rejectedUnownedEquipNeverTouchesDurableOrLegacyPreferences()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/stagePreviewAndLevelBoundariesNeverClearAnOwnedOutfit()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/unavailableShopNeverGrantsPaidWearingAndPreservesPreferences()`|Swift Testing|macOS / My Mac: Passed|없음|
|`PioWardrobeTests/unknownMockIDsCannotBecomeOwnedAndResetRepairsOnlyUnownedSelections()`|Swift Testing|macOS / My Mac: Passed|없음|
|`RoutimoriSyncTests/repeatedUpdatesDoNotAccumulateTracksAndActivityStops()`|Swift Testing|macOS / My Mac: Passed|없음|
|`RoutimoriSyncTests/sceneTransitionReplacesMotionAndReduceMotionStopsEveryLayer()`|Swift Testing|macOS / My Mac: Passed|없음|
|`RoutimoriVacationTests/changingTimeOfDaySelectsRegisteredArtworkWithoutRestartingSway()`|Swift Testing|macOS / My Mac: Passed|없음|
|`RoutimoriVacationTests/registeredImagesStayAlignedAndTheRopeAnchorDoesNotMove()`|Swift Testing|macOS / My Mac: Passed|없음|
|`RoutimoriVacationTests/swayStopsRestoresAndNeverAnimatesTheBeach()`|Swift Testing|macOS / My Mac: Passed|없음|

## 최종 실행 해석

C8 Mac regression107/107(98 Swift Testing+9 XCTest), hosted home8/8, actual native screen1/1, quiet7/7 PASS. iPhone 최종7/7 및 C7 vacation8/8, small phone2/2, iPad 최종portrait1/1 PASS. 서로 중복된 메서드를 합산하지 않는다.

현재 고유 실행134개(98 Swift Testing+36 XCTest). 최신 실패는 iPad 실제 portrait→landscape→portrait 메서드와 verified integration2메서드다. iPad portrait PASS가 회전 실패를 해결한 것은 아니다. Mac screens-C8 첫 선택자는0개를 실행했으므로 NOT_TESTED_ZERO_METHODS이며 native-screens-C8의 실제1개PASS로 구분한다.
