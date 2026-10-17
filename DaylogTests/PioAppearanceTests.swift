import Foundation
import Observation
import Testing
@testable import Daylog

@MainActor
private final class AppearanceStoreClient: PioStoreClient {
    var transactions: [PioVerifiedTransaction] = []
    var failsRefresh = false
    func loadProducts(ids: Set<String>) async throws -> [PioStoreProduct] { [] }
    func purchase(productID: String) async throws -> PioStorePurchaseResult { .cancelled }
    func currentEntitlements() async throws -> PioEntitlementSnapshot {
        if failsRefresh { throw URLError(.notConnectedToInternet) }
        return PioEntitlementSnapshot(transactions: transactions)
    }
    func updates() -> AsyncStream<PioTransactionEvent> { AsyncStream { $0.finish() } }
    func finish(transactionID: UInt64) async {}
    func sync() async throws {}
    func own(_ outfits: [PioOutfitID]) {
        transactions = outfits.enumerated().compactMap { offset, outfit in
            PioProductRegistry.productID(for: outfit).map { PioVerifiedTransaction(id: UInt64(offset + 1), productID: $0, revoked: false) }
        }
    }
}

@MainActor @Observable
private final class AppearanceGrowthSource { var level = 1 }

@MainActor
struct PioAppearanceTests {
    private func withFixture(_ body: (UserDefaults, AppearanceStoreClient, PioPurchaseManager, PioWardrobeStore, PioAppearanceCoordinator) async throws -> Void) async rethrows {
        let name = "PioAppearanceTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let client = AppearanceStoreClient()
        let purchases = PioPurchaseManager(client: client, availability: .localTesting)
        let wardrobe = PioWardrobeStore(defaults: defaults, purchases: purchases)
        let coordinator = PioAppearanceCoordinator(wardrobe: wardrobe, assetExists: { _ in true },
                                                   layeredAvailable: { _ in false }, motionAvailable: { true })
        try await body(defaults, client, purchases, wardrobe, coordinator)
    }

    @Test func stageBoundariesMatchApprovedGrowthWithoutChangingCostume() async {
        await withFixture { _, client, purchases, wardrobe, coordinator in
            client.own([.halloween]); await purchases.refreshEntitlements()
            #expect(wardrobe.equip(.halloween))
            for (level, stage) in [(1,1),(9,1),(10,2),(24,2),(25,3),(49,3),(50,4),(100,4)] {
                let appearance = coordinator.resolve(level: level, context: .growth)
                #expect(appearance.stage == stage)
                #expect(appearance.stage == PioTrial.stage(forLevel: level).number)
                #expect(appearance.outfit == .halloween && wardrobe.equippedOutfit == .halloween)
                #expect(!appearance.growthCompatible)
                #expect(appearance.missingArtwork.contains("pio_outfit_halloween_stage\(stage)"))
            }
        }
    }

    @Test func allFourteenCatalogEntriesResolveTheirApprovedArtwork() async {
        await withFixture { _, client, purchases, wardrobe, coordinator in
            client.own(PioOutfitID.allCases); await purchases.refreshEntitlements()
            for outfit in PioOutfitID.allCases {
                #expect(wardrobe.equip(outfit))
                for context in [PioAppearanceContext.dashboard, .growth, .splash, .weeklyReview, .welcome, .celebration, .wardrobe, .settingsPreview] {
                    let appearance = coordinator.resolve(level: 25, context: context)
                    #expect(appearance.outfit == outfit && appearance.outfitApplied)
                    #expect(appearance.artwork.assetName == outfit.artAssetName)
                    #expect(appearance.stage == 3)
                }
            }
        }
    }

    @Test func unknownPreferencesNeverGrantPaidAppearanceOrEraseSelection() async {
        let name = "PioAppearanceUnknown.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("christmas", forKey: PioWardrobeStore.equippedKey)
        let client = AppearanceStoreClient()
        let purchases = PioPurchaseManager(client: client, availability: .localTesting)
        let wardrobe = PioWardrobeStore(defaults: defaults, purchases: purchases)
        let coordinator = PioAppearanceCoordinator(wardrobe: wardrobe, assetExists: { _ in true }, layeredAvailable: { _ in false })
        let unknown = coordinator.resolve(context: .splash)
        #expect(unknown.requestedOutfit == .christmas && unknown.outfit == .basic)
        #expect(unknown.access == .checking && !unknown.outfitApplied)
        #expect(unknown.compatibilityNote?.contains("확인 중") == true)
        client.failsRefresh = true; await purchases.refreshEntitlements()
        #expect(coordinator.resolve(context: .splash).access == .verificationUnavailable)
        #expect(defaults.string(forKey: PioWardrobeStore.equippedKey) == "christmas")
        let entitlementChanged = ObservationChangeFlag()
        withObservationTracking {
            _ = coordinator.resolve(context: .splash)
        } onChange: { entitlementChanged.mark() }
        client.failsRefresh = false; client.own([.christmas]); await purchases.refreshEntitlements()
        #expect(entitlementChanged.wasMarked)
        #expect(coordinator.resolve(context: .splash).outfit == .christmas)
        #expect(coordinator.resolve(context: .splash).access == .verified)
    }

    @Test func previewsNeverAuthorizeEquipOrChangeGlobalAppearance() async {
        await withFixture { _, _, _, wardrobe, coordinator in
            for outfit in PioOutfitID.allCases where outfit != .basic {
                let preview = coordinator.preview(outfit: outfit, stage: 4)
                #expect(preview.isPreview && preview.outfit == outfit && preview.outfitApplied)
                #expect(!wardrobe.owns(outfit) && !wardrobe.equip(outfit))
                #expect(coordinator.resolve(context: .dashboard).outfit == .basic)
                #expect(coordinator.currentStage == 1)
            }
        }
    }

    @Test func composedScenesKeepRegisteredOriginalAndReportEveryMissingCostumePose() async {
        await withFixture { _, client, purchases, wardrobe, coordinator in
            client.own([.christmas, .halloween, .hanbok, .astronaut]); await purchases.refreshEntitlements()
            let expected: [(PioAppearanceContext, String)] = [
                (.vacationDay, "routimori_vacation_hammock"),
                (.vacationNight, "routimori_vacation_hammock_night"),
                (.cloudDownloading, "routimori_sync_loading"),
                (.cloudCompleted, "routimori_sync_success"),
                (.cloudFailed, "routimori_sync_failure")
            ]
            for outfit in [PioOutfitID.basic, .christmas, .halloween, .hanbok, .astronaut] {
                wardrobe.equip(outfit)
                for (context, asset) in expected {
                    let appearance = coordinator.resolve(level: 50, context: context)
                    #expect(appearance.artwork == .existingScene(asset: asset))
                    #expect(appearance.animationPreserved)
                    #expect(appearance.outfitApplied == (outfit == .basic))
                    #expect(!appearance.growthCompatible)
                    if outfit != .basic {
                        #expect(appearance.missingArtwork.contains("\(asset)_\(outfit.rawValue)"))
                        #expect(appearance.compatibilityNote?.contains("기본 장면") == true)
                        #expect(wardrobe.equippedOutfit == outfit)
                    }
                }
            }
        }
    }

    @Test func standingOutfitsAreNeverCompositedAsRecliningOrSleeping() async {
        await withFixture { _, client, purchases, wardrobe, coordinator in
            client.own([.christmas]); await purchases.refreshEntitlements(); wardrobe.equip(.christmas)
            for pose in [PioAppearancePose.reclining, .sleeping] {
                let appearance = coordinator.resolve(context: .generic, pose: pose)
                #expect(appearance.artwork == .unavailable)
                #expect(!appearance.outfitApplied && !appearance.animationPreserved)
                #expect(appearance.missingArtwork.contains("pio_\(pose.rawValue)_christmas"))
                #expect(wardrobe.equippedOutfit == .christmas)
            }
            #expect(coordinator.resolve(context: .vacationNight).pose == .reclining)
        }
    }

    @Test func fallbackMotionsNeverClaimIndependentWingsOrWalking() async {
        await withFixture { _, client, purchases, wardrobe, coordinator in
            client.own([.halloween]); await purchases.refreshEntitlements(); wardrobe.equip(.halloween)
            let greeting = coordinator.resolve(context: .welcome, motion: .wave)
            #expect(greeting.motion == .idle && !greeting.animationPreserved)
            #expect(greeting.missingArtwork.contains("pio_layered_halloween_wave"))
            #expect(!coordinator.resolve(context: .welcome).animationPreserved)
            let walking = coordinator.resolve(context: .dashboard, pose: .walking)
            #expect(walking.motion == .idle && !walking.animationPreserved)
            #expect(walking.missingArtwork.contains("pio_layered_halloween_walk"))
            wardrobe.equip(.basic)
            #expect(coordinator.resolve(context: .splash, motion: .wave).animationPreserved)
        }
    }

    @Test func approvedLayeredPilotRemainsExplicitAndDoesNotInventGrowthStages() async {
        await withFixture { _, client, purchases, wardrobe, _ in
            client.own([.hanbok]); await purchases.refreshEntitlements(); wardrobe.equip(.hanbok)
            let coordinator = PioAppearanceCoordinator(wardrobe: wardrobe, assetExists: { _ in true },
                                                       layeredAvailable: { $0 == .hanbok })
            let appearance = coordinator.resolve(level: 50, context: .dashboard, pose: .walking)
            #expect(appearance.renderer == .layeredPilot && appearance.animationPreserved)
            #expect(appearance.outfitApplied && !appearance.growthCompatible)
            #expect(appearance.stage == 4)
        }
    }

    @Test func growthSourceIsLiveAndAllScreenReadsUseIt() async {
        await withFixture { _, client, purchases, wardrobe, coordinator in
            client.own([.astronaut]); await purchases.refreshEntitlements(); wardrobe.equip(.astronaut)
            let source = AppearanceGrowthSource()
            coordinator.bindGrowthSource { source.level }
            #expect(coordinator.currentStage == 1)
            source.level = 25
            for context in PioAppearanceContext.allCases {
                #expect(coordinator.resolve(context: context).stage == 3)
            }
            source.level = 50
            #expect(coordinator.resolve(context: .weeklyReview).stage == 4)
            #expect(wardrobe.equippedOutfit == .astronaut)
        }
    }

    @Test func appearanceReadsTrackWardrobeAndLiveGrowthChanges() async {
        await withFixture { _, client, purchases, wardrobe, coordinator in
            client.own([.christmas]); await purchases.refreshEntitlements()
            let source = AppearanceGrowthSource()
            coordinator.bindGrowthSource { source.level }
            let changed = ObservationChangeFlag()
            withObservationTracking {
                _ = coordinator.resolve(context: .dashboard)
            } onChange: { changed.mark() }
            wardrobe.equip(.christmas)
            #expect(changed.wasMarked)
            let growthChanged = ObservationChangeFlag()
            withObservationTracking {
                _ = coordinator.resolve(context: .growth)
            } onChange: { growthChanged.mark() }
            source.level = 50
            #expect(growthChanged.wasMarked)
        }
    }

    @Test func outfitAndAppIconStayIndependentAfterRefreshAndReopen() async {
        await withFixture { defaults, client, purchases, wardrobe, coordinator in
            client.own([.christmas, .hanbok]); await purchases.refreshEntitlements()
            wardrobe.equip(.christmas); wardrobe.selectIcon(.hanbok)
            #expect(coordinator.resolve(context: .dashboard).outfit == .christmas)
            #expect(wardrobe.selectedIcon == .hanbok)
            let reopenedPurchases = PioPurchaseManager(client: client, availability: .localTesting)
            let reopened = PioWardrobeStore(defaults: defaults, purchases: reopenedPurchases)
            let restored = PioAppearanceCoordinator(wardrobe: reopened, assetExists: { _ in true }, layeredAvailable: { _ in false })
            #expect(restored.resolve(context: .splash).access == .checking)
            await reopenedPurchases.refreshEntitlements()
            #expect(restored.resolve(context: .splash).outfit == .christmas)
            #expect(reopened.selectedIcon == .hanbok)
            client.own([.hanbok]); await reopenedPurchases.refreshEntitlements()
            #expect(restored.resolve(context: .dashboard).outfit == .basic)
            #expect(reopened.selectedIcon == .hanbok)
        }
    }

    @Test func missingSourceArtworkAndAbsentWidgetSurfacesAreExplicit() async {
        await withFixture { _, _, _, wardrobe, _ in
            let coordinator = PioAppearanceCoordinator(wardrobe: wardrobe, assetExists: { _ in false }, layeredAvailable: { _ in false })
            let appearance = coordinator.resolve(context: .dashboard)
            #expect(appearance.artwork == .unavailable && !appearance.outfitApplied)
            #expect(appearance.missingArtwork.contains("pio_wardrobe_basic_reference"))
            for context in [PioAppearanceContext.widget, .menuBar] {
                let unsupported = coordinator.resolve(context: context)
                #expect(unsupported.artwork == .unavailable && !unsupported.outfitApplied)
                #expect(unsupported.compatibilityNote?.contains("표시 영역") == true)
            }
        }
    }

    #if DEBUG
    @Test func testingModeAuthorizesAllCostumesWithoutVerifiedAccess() async {
        await withFixture { defaults, client, purchases, _, _ in
            let name = "PioAppearanceWearTesting.\(UUID())"
            let testing = UserDefaults(suiteName: name)!
            defer { testing.removePersistentDomain(forName: name) }
            let wardrobe = PioWardrobeStore(defaults: defaults, purchases: purchases,
                                             isOutfitTestingEnabled: true, outfitTestingDefaults: testing)
            let coordinator = PioAppearanceCoordinator(wardrobe: wardrobe, assetExists: { _ in true },
                                                       layeredAvailable: { _ in false })
            for outfit in PioOutfitID.allCases where outfit != .basic {
                #expect(wardrobe.equip(outfit))
                for context in [PioAppearanceContext.dashboard, .growth, .splash, .weeklyReview, .welcome] {
                    let appearance = coordinator.resolve(level: 25, context: context)
                    #expect(appearance.outfit == outfit && appearance.outfitApplied)
                    #expect(appearance.access == .testing)
                    #expect(appearance.compatibilityNote?.contains("테스트 모드") == true)
                    #expect(appearance.artwork.assetName == outfit.artAssetName)
                }
                #expect(coordinator.equippedOutfit == outfit)
                #expect(!purchases.owns(outfit))
            }
            #expect(coordinator.ownedOutfits == [.basic])
            #expect(client.transactions.isEmpty)
            await purchases.refreshEntitlements()
            #expect(purchases.entitlementState == .verified)
            #expect(coordinator.resolve(context: .dashboard).access == .testing)
            #expect(wardrobe.equippedOutfit == .astronaut)
            let preview = coordinator.preview(outfit: .cafe, stage: 4)
            #expect(preview.access == .preview && preview.outfit == .cafe)
            #expect(coordinator.equippedOutfit == .astronaut)
            let scene = coordinator.resolve(context: .vacationNight)
            #expect(scene.access == .testing && !scene.outfitApplied)
            #expect(scene.artwork == .existingScene(asset: "routimori_vacation_hammock_night"))
            #expect(!wardrobe.selectIcon(.astronaut))
        }
    }

    @Test func legacyMockOwnershipCannotAuthorizeGlobalAppearance() async {
        let name = "PioAppearanceMock.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let wardrobe = PioWardrobeStore(defaults: defaults, legacyMockMode: true)
        wardrobe.mockPurchase(.christmas); wardrobe.equip(.christmas)
        let coordinator = PioAppearanceCoordinator(wardrobe: wardrobe, assetExists: { _ in true }, layeredAvailable: { _ in false })
        #expect(coordinator.resolve(context: .dashboard).outfit == .basic)
        #expect(!coordinator.resolve(context: .dashboard).outfitApplied)
    }
    #endif
}

/// Observation's callback is @Sendable; a lock makes this a real observation
/// assertion without relying on task scheduling or unchecked shared mutation.
private final class ObservationChangeFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var marked = false
    func mark() { lock.lock(); marked = true; lock.unlock() }
    var wasMarked: Bool { lock.lock(); defer { lock.unlock() }; return marked }
}
