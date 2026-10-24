import Foundation
import Testing
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import Daylog

/// Unit receipt boundary only: no StoreKit session, SDK purchases or ownership cache.
@MainActor
private final class WardrobeSelectionReceiptClient: PioStoreClient {
    var snapshot = PioEntitlementSnapshot()
    private(set) var snapshotCalls = 0
    func loadProducts(ids: Set<String>) async throws -> [PioStoreProduct] { [] }
    func purchase(productID: String) async throws -> PioStorePurchaseResult { throw PioStoreClientError.unavailable }
    func currentEntitlements() async throws -> PioEntitlementSnapshot {
        snapshotCalls += 1
        return snapshot
    }
    func updates() -> AsyncStream<PioTransactionEvent> { AsyncStream { $0.finish() } }
    func finish(transactionID: UInt64) async {}
    func sync() async throws {}
}

@MainActor
struct PioWardrobeTests {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let name = "PioWardrobeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    private func withIsolatedSelection(_ body: (UserDefaults, URL) async throws -> Void) async throws {
        let name = "PioWardrobeSelectionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: directory)
        }
        try await body(defaults, directory)
    }

    private func receipt(_ outfit: PioOutfitID, id: UInt64 = 101) -> PioVerifiedTransaction {
        PioVerifiedTransaction(id: id, productID: PioProductRegistry.productID(for: outfit)!, revoked: false)
    }

    @Test func durableLastSelectionSurvivesReopenButRequiresFreshVerifiedOwnership() async throws {
        try await withIsolatedSelection { defaults, directory in
            let url = directory.appendingPathComponent("selection.json")
            let client = WardrobeSelectionReceiptClient()
            client.snapshot.transactions = [receipt(.cafe)]
            let manager = PioPurchaseManager(client: client, availability: .localTesting)
            let store = PioWardrobeStore(defaults: defaults, purchases: manager,
                                         selectionPersistence: PioWardrobeSelectionFile(url: url))
            #expect(await manager.refreshEntitlements())
            #expect(store.equip(.cafe))
            #expect(store.equip(.basic))
            #expect(store.equip(.cafe))
            #expect(PioWardrobeSelectionFile(url: url).load() == .cafe)

            // Simulate the independently stale, asynchronous legacy mirror.
            defaults.set(PioOutfitID.basic.rawValue, forKey: PioWardrobeStore.equippedKey)
            let freshClient = WardrobeSelectionReceiptClient()
            let freshManager = PioPurchaseManager(client: freshClient, availability: .localTesting)
            let reopened = PioWardrobeStore(defaults: defaults, purchases: freshManager,
                                            selectionPersistence: PioWardrobeSelectionFile(url: url))
            #expect(freshClient.snapshotCalls == 0)
            #expect(reopened.preferredAppearanceOutfit == .cafe)
            #expect(reopened.ownedOutfits == [.basic])
            #expect(!reopened.canWear(.cafe))
            #expect(reopened.equippedOutfit == .basic)
            freshClient.snapshot.transactions = [receipt(.cafe)]
            #expect(await freshManager.refreshEntitlements())
            #expect(freshClient.snapshotCalls == 1)
            #expect(reopened.equippedOutfit == .cafe)
            let payload = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            #expect(Set(payload.keys) == ["version", "outfit"])
            #expect(payload["outfit"] as? String == PioOutfitID.cafe.rawValue)

            // A newly verified empty ledger repairs the preference durably too.
            freshClient.snapshot = PioEntitlementSnapshot()
            #expect(await freshManager.refreshEntitlements())
            #expect(freshClient.snapshotCalls == 2)
            #expect(reopened.ownedOutfits == [.basic])
            #expect(reopened.equippedOutfit == .basic)
            #expect(reopened.preferredAppearanceOutfit == .basic)
            #expect(PioWardrobeSelectionFile(url: url).load() == .basic)
            #expect(defaults.string(forKey: PioWardrobeStore.equippedKey) == PioOutfitID.basic.rawValue)
            let afterRemoval = PioWardrobeStore(defaults: defaults,
                purchases: PioPurchaseManager(client: WardrobeSelectionReceiptClient(), availability: .localTesting),
                selectionPersistence: PioWardrobeSelectionFile(url: url))
            #expect(afterRemoval.preferredAppearanceOutfit == .basic)
            #expect(afterRemoval.equippedOutfit == .basic)
            #expect(afterRemoval.ownedOutfits == [.basic])
        }
    }

    @Test func corruptOrUnsupportedSelectionFallsBackWithoutGrantingOwnership() async throws {
        try await withIsolatedSelection { defaults, directory in
            defaults.set(PioOutfitID.cafe.rawValue, forKey: PioWardrobeStore.equippedKey)
            let invalidPayloads = ["not JSON", "{\"version\":2,\"outfit\":\"christmas\"}",
                                   "{\"version\":1,\"outfit\":\"not-a-real-outfit\"}"]
            for (index, raw) in invalidPayloads.enumerated() {
                let url = directory.appendingPathComponent("invalid-\(index).json")
                let bytes = Data(raw.utf8)
                try bytes.write(to: url)
                let file = PioWardrobeSelectionFile(url: url)
                #expect(file.load() == nil)
                let manager = PioPurchaseManager(client: WardrobeSelectionReceiptClient(), availability: .localTesting)
                let store = PioWardrobeStore(defaults: defaults, purchases: manager, selectionPersistence: file)
                #expect(store.preferredAppearanceOutfit == .cafe)
                #expect(store.equippedOutfit == .basic)
                #expect(store.ownedOutfits == [.basic])
                #expect(try Data(contentsOf: url) == bytes)
            }
            let missing = PioWardrobeSelectionFile(url: directory.appendingPathComponent("missing.json"))
            #expect(missing.load() == nil)
            defaults.set("unknown-legacy", forKey: PioWardrobeStore.equippedKey)
            let store = PioWardrobeStore(defaults: defaults,
                                         purchases: PioPurchaseManager(client: WardrobeSelectionReceiptClient(), availability: .localTesting),
                                         selectionPersistence: missing)
            #expect(store.preferredAppearanceOutfit == .basic)
            #expect(store.equippedOutfit == .basic)
        }
    }

    @Test func failedDurableWriteRejectsEquipAndPreservesPreviousPreference() async throws {
        try await withIsolatedSelection { defaults, directory in
            defaults.set(PioOutfitID.cafe.rawValue, forKey: PioWardrobeStore.equippedKey)
            let blocker = directory.appendingPathComponent("regular-file")
            let originalBytes = Data("cannot become a directory".utf8)
            try originalBytes.write(to: blocker)
            let file = PioWardrobeSelectionFile(url: blocker.appendingPathComponent("selection.json"))
            let client = WardrobeSelectionReceiptClient()
            client.snapshot.transactions = [receipt(.cafe)]
            let manager = PioPurchaseManager(client: client, availability: .localTesting)
            let store = PioWardrobeStore(defaults: defaults, purchases: manager, selectionPersistence: file)
            #expect(await manager.refreshEntitlements())
            #expect(store.equippedOutfit == .cafe)
            #expect(!store.equip(.basic))
            #expect(store.preferredAppearanceOutfit == .cafe)
            #expect(store.equippedOutfit == .cafe)
            #expect(defaults.string(forKey: PioWardrobeStore.equippedKey) == PioOutfitID.cafe.rawValue)
            #expect(try Data(contentsOf: blocker) == originalBytes)
        }
    }

    @Test func rejectedUnownedEquipNeverTouchesDurableOrLegacyPreferences() async throws {
        try await withIsolatedSelection { defaults, directory in
            let url = directory.appendingPathComponent("selection.json")
            let file = PioWardrobeSelectionFile(url: url)
            try file.save(.basic)
            let originalBytes = try Data(contentsOf: url)
            defaults.set(PioOutfitID.basic.rawValue, forKey: PioWardrobeStore.equippedKey)
            let manager = PioPurchaseManager(client: WardrobeSelectionReceiptClient(), availability: .localTesting)
            let store = PioWardrobeStore(defaults: defaults, purchases: manager, selectionPersistence: file)
            for outfit in PioOutfitID.allCases where outfit != .basic {
                #expect(!store.equip(outfit))
                #expect(try Data(contentsOf: url) == originalBytes)
                #expect(defaults.string(forKey: PioWardrobeStore.equippedKey) == PioOutfitID.basic.rawValue)
            }
            #expect(store.ownedOutfits == [.basic])
        }
    }

    @Test func durableSelectionProfilesCannotOverwriteOneAnother() async throws {
        try await withIsolatedSelection { _, directory in
            let policies: [(PioPurchaseAvailability, Bool, PioOutfitID)] = [
                (.localTesting, false, .cafe), (.sandbox, false, .christmas),
                (.appStore, false, .hanbok), (.localTesting, true, .astronaut)
            ]
            let profiles = policies.map { PioWardrobeSelectionFile.profileName(for: $0.0, outfitTesting: $0.1) }
            #expect(Set(profiles).count == policies.count)
            #expect(PioWardrobeSelectionFile.profileName(for: .disabled(message: "offline"), outfitTesting: false)
                    == PioWardrobeSelectionFile.profileName(for: .appStore, outfitTesting: false))
            for (index, policy) in policies.enumerated() {
                try PioWardrobeSelectionFile(url: directory.appendingPathComponent(profiles[index])
                    .appendingPathComponent("selection.json")).save(policy.2)
            }
            for (index, policy) in policies.enumerated() {
                let reopened = PioWardrobeSelectionFile(url: directory.appendingPathComponent(profiles[index])
                    .appendingPathComponent("selection.json"))
                #expect(reopened.load() == policy.2)
            }
        }
    }

    @Test func catalogHasFourteenUniqueHonestEntries() {
        #expect(PioOutfitID.allCases.count == 14)
        #expect(Set(PioOutfitID.allCases.map(\.id)).count == 14)
        let expected: [PioOutfitCategory: Int] = [.free: 1, .seasonal: 4, .holiday: 3, .everyday: 5, .special: 1]
        for (category, count) in expected {
            #expect(PioOutfitID.allCases.filter { $0.category == category }.count == count)
        }
        #expect(PioOutfitID.basic.artAssetName == "pio_wardrobe_basic_reference")
        #expect(PioOutfitID.basic.plannedPriceText == "무료")
        #expect(Set(PioOutfitID.allCases.compactMap(\.artAssetName)).count == 14)
        for outfit in PioOutfitID.allCases where outfit != .basic {
            #expect(outfit.artAssetName == "pio_outfit_\(outfit.rawValue)")
            #expect(outfit.plannedPriceText == "App Store에서 가격 확인")
            #expect(!outfit.title.isEmpty && !outfit.description.isEmpty && !outfit.symbol.isEmpty)
        }
    }

    @Test func everyCatalogArtworkLoadsFromTheAppBundleAtFullResolution() throws {
        for outfit in PioOutfitID.allCases {
            let name = try #require(outfit.artAssetName)
            #if os(macOS)
            let nativeImage = try #require(NSImage(named: name), "Missing bundled artwork: \(name)")
            let image = try #require(nativeImage.cgImage(forProposedRect: nil, context: nil, hints: nil))
            #else
            let nativeImage = try #require(UIImage(named: name), "Missing bundled artwork: \(name)")
            let image = try #require(nativeImage.cgImage)
            #endif
            #expect(image.width >= 1024, "Artwork width is below source resolution: \(name)")
            #expect(image.height >= 1024, "Artwork height is below source resolution: \(name)")
        }
    }

    @Test func basicIsAlwaysFreeAndUnownedSelectionsAreRejected() {
        withDefaults { defaults in
            let store = PioWardrobeStore(defaults: defaults)
            #expect(store.ownedOutfits == [.basic])
            #expect(!store.isOutfitTestingEnabled)
            #expect(store.availableOutfits == [.basic])
            for outfit in PioOutfitID.allCases where outfit != .basic {
                #expect(!store.canWear(outfit))
                #expect(!store.equip(outfit))
                #expect(!store.selectIcon(outfit))
            }
            #expect(store.equip(.basic) && store.selectIcon(.basic))
            store.unequip()
            #expect(store.equippedOutfit == .basic && store.selectedIcon == .basic)
        }
    }

    @Test func unavailableShopNeverGrantsPaidWearingAndPreservesPreferences() {
        withDefaults { defaults in
            defaults.set("cafe", forKey: PioWardrobeStore.equippedKey)
            let manager = PioPurchaseManager(availability: .disabled(message: "오프라인"))
            let store = PioWardrobeStore(defaults: defaults, purchases: manager)
            #expect(!store.isFreeWearing)
            #expect(!store.equip(.cafe))
            #expect(store.equippedOutfit == .basic)
            #expect(store.preferredAppearanceOutfit == .cafe)
            #expect(defaults.string(forKey: PioWardrobeStore.equippedKey) == "cafe")
            #expect(store.ownedOutfits == [.basic])
        }
    }

    @Test func invalidOrUnownedStoredSelectionsFallBackSafely() {
        withDefaults { defaults in
            defaults.set("future-unknown-outfit", forKey: PioWardrobeStore.equippedKey)
            defaults.set(PioOutfitID.astronaut.rawValue, forKey: PioWardrobeStore.selectedIconKey)
            let store = PioWardrobeStore(defaults: defaults)
            #expect(store.equippedOutfit == .basic && store.selectedIcon == .basic)
            #expect(PioOutfitID(rawValue: "future-unknown-outfit") == nil)
        }
    }

    @Test func previewStagePersistsWithoutChangingOwnershipOrOutfit() {
        withDefaults { defaults in
            defaults.set("untouched", forKey: "unrelated.preference")
            let store = PioWardrobeStore(defaults: defaults)
            #expect(store.previewStage == 1)
            for stage in 1...4 {
                store.selectPreviewStage(stage)
                #expect(store.previewStage == stage)
                #expect(store.equippedOutfit == .basic)
                #expect(store.ownedOutfits == [.basic])
            }
            store.selectPreviewStage(0)
            store.selectPreviewStage(5)
            let reopened = PioWardrobeStore(defaults: defaults)
            #expect(reopened.previewStage == 4)
            #expect(reopened.equippedOutfit == .basic)
            #expect(defaults.string(forKey: "unrelated.preference") == "untouched")
        }
    }

    #if DEBUG
    @Test func outfitTestingRequiresExactExplicitFlag() {
        #expect(!PioWardrobeStore.outfitTestingEnabled(arguments: []))
        #expect(!PioWardrobeStore.outfitTestingEnabled(arguments: ["-pio-storekit-testing"]))
        #expect(!PioWardrobeStore.outfitTestingEnabled(arguments: ["-pio-wardrobe-testing=false"]))
        #expect(PioWardrobeStore.outfitTestingEnabled(arguments: ["-pio-wardrobe-testing"]))
    }

    @Test func outfitTestingAllowsEveryCostumeWithoutOwnershipOrIcons() {
        withDefaults { production in
            withDefaults { testing in
                let store = PioWardrobeStore(defaults: production, isOutfitTestingEnabled: true,
                                             outfitTestingDefaults: testing)
                #expect(store.isOutfitTestingEnabled)
                #expect(store.availableOutfits == Set(PioOutfitID.allCases))
                for outfit in PioOutfitID.allCases where outfit != .basic {
                    #expect(store.canWear(outfit) && store.equip(outfit))
                    #expect(store.equippedOutfit == outfit)
                    #expect(!store.owns(outfit) && !store.purchases.owns(outfit))
                    #expect(!store.selectIcon(outfit))
                }
                #expect(store.ownedOutfits == [.basic])
                #expect(store.purchases.ownedOutfits == [.basic])
                #expect(store.purchases.entitlementState == .unknown)
                #expect(store.selectedIcon == .basic)
            }
        }
    }

    @Test func outfitTestingPreferencesAreSeparateAndSurviveEntitlementRepair() {
        withDefaults { production in
            withDefaults { storeKit in
                withDefaults { testing in
                    production.set("cafe", forKey: PioWardrobeStore.equippedKey)
                    storeKit.set("winter", forKey: PioWardrobeStore.equippedKey)
                    let supplied = PioWardrobeStore.preferences(for: .localTesting,
                                                               production: production, localTesting: storeKit)
                    let store = PioWardrobeStore(defaults: supplied, isOutfitTestingEnabled: true,
                                                 outfitTestingDefaults: testing)
                    #expect(store.equippedOutfit == .basic)
                    #expect(store.equip(.astronaut))
                    store.purchases.ownershipDidChange?(nil)
                    store.purchases.ownershipDidChange?([.astronaut])
                    #expect(store.equippedOutfit == .astronaut)
                    #expect(testing.string(forKey: PioWardrobeStore.equippedKey) == "astronaut")
                    #expect(production.string(forKey: PioWardrobeStore.equippedKey) == "cafe")
                    #expect(storeKit.string(forKey: PioWardrobeStore.equippedKey) == "winter")
                    let reopened = PioWardrobeStore(defaults: supplied, isOutfitTestingEnabled: true,
                                                    outfitTestingDefaults: testing)
                    #expect(reopened.equippedOutfit == .astronaut && !reopened.owns(.astronaut))
                    let modeOff = PioWardrobeStore(defaults: supplied, outfitTestingDefaults: testing)
                    #expect(!modeOff.isOutfitTestingEnabled && !modeOff.canWear(.astronaut))
                    #expect(modeOff.preferredAppearanceOutfit == .winter)
                    #expect(modeOff.equippedOutfit == .basic)
                    store.unequip()
                    #expect(store.equippedOutfit == .basic)
                    #expect(store.availableOutfits.count == 14)
                    #expect(PioWardrobeStore.outfitTestingPreferencesSuite != PioWardrobeStore.localTestingPreferencesSuite)
                }
            }
        }
    }

    @Test func stagePreviewAndLevelBoundariesNeverClearAnOwnedOutfit() {
        withDefaults { defaults in
            let store = PioWardrobeStore(defaults: defaults, legacyMockMode: true)
            store.mockPurchase(.christmas)
            store.equip(.christmas)
            store.selectIcon(.christmas)
            for (level, stage) in [(1,1),(9,1),(10,2),(24,2),(25,3),(49,3),(50,4),(100,4)] {
                #expect(PioTrial.stage(forLevel: level).number == stage)
                store.selectPreviewStage(stage)
                #expect(store.equippedOutfit == .christmas)
                #expect(store.owns(.christmas))
            }
            let reopened = PioWardrobeStore(defaults: defaults, legacyMockMode: true)
            #expect(reopened.previewStage == 4)
            #expect(reopened.equippedOutfit == .christmas)
            #expect(reopened.selectedIcon == .christmas)
        }
    }
    #endif

    @Test func productionEntitlementBoundaryIsUnavailable() async {
        let service = UnavailablePioWardrobeEntitlements()
        guard case .unavailable = await service.purchase(.astronaut),
              case .unavailable = await service.restore() else {
            Issue.record("V1 must not report a real purchase or restoration")
            return
        }
    }

    #if DEBUG
    @Test func mockOwnershipPersistsWhileOutfitAndIconStayIndependent() {
        withDefaults { defaults in
            let store = PioWardrobeStore(defaults: defaults, legacyMockMode: true)
            #expect(!store.mockPurchase(.basic))
            #expect(store.mockPurchase(.cafe))
            #expect(!store.mockPurchase(.cafe))
            #expect(store.mockPurchase(.astronaut))
            #expect(store.equip(.cafe))
            #expect(store.selectIcon(.astronaut))
            let reopened = PioWardrobeStore(defaults: defaults, legacyMockMode: true)
            #expect(reopened.ownedOutfits == [.basic, .cafe, .astronaut])
            #expect(reopened.equippedOutfit == .cafe && reopened.selectedIcon == .astronaut)
            reopened.unequip()
            #expect(reopened.equippedOutfit == .basic && reopened.selectedIcon == .astronaut)
        }
    }

    @Test func unknownMockIDsCannotBecomeOwnedAndResetRepairsOnlyUnownedSelections() {
        withDefaults { defaults in
            defaults.set(["unknown", "cafe", "cafe", "basic"], forKey: PioWardrobeStore.mockOwnershipKey)
            let store = PioWardrobeStore(defaults: defaults, legacyMockMode: true)
            #expect(store.ownedOutfits == [.basic, .cafe])
            store.equip(.cafe)
            store.selectIcon(.basic)
            defaults.set("preserve-me", forKey: "unrelated.preference")
            store.resetMockPurchases()
            #expect(store.ownedOutfits == [.basic])
            #expect(store.equippedOutfit == .basic && store.selectedIcon == .basic)
            #expect(defaults.string(forKey: "unrelated.preference") == "preserve-me")
            #expect(defaults.object(forKey: PioWardrobeStore.mockOwnershipKey) == nil)
            store.mockPurchase(.pajamas)
            store.selectIcon(.pajamas)
            store.resetMockPurchases()
            let reopened = PioWardrobeStore(defaults: defaults, legacyMockMode: true)
            #expect(reopened.equippedOutfit == .basic && reopened.selectedIcon == .basic)
            #expect(reopened.ownedOutfits == [.basic])
        }
    }
    #else
    @Test func releaseCannotEnableWardrobeTestingByFlagOrInjection() {
        #expect(!PioWardrobeStore.outfitTestingEnabled(arguments: ["-pio-wardrobe-testing"]))
        withDefaults { defaults in
            let store = PioWardrobeStore(defaults: defaults, isOutfitTestingEnabled: true)
            #expect(!store.isOutfitTestingEnabled)
            #expect(store.availableOutfits == [.basic])
            #expect(!store.canWear(.astronaut) && !store.equip(.astronaut))
        }
    }

    @Test func releaseIgnoresDebugOwnershipEntirely() {
        withDefaults { defaults in
            defaults.set(["cafe", "astronaut"], forKey: "PioWardrobe.debugOwnedOutfits.v1")
            defaults.set("cafe", forKey: PioWardrobeStore.equippedKey)
            defaults.set("astronaut", forKey: PioWardrobeStore.selectedIconKey)
            let store = PioWardrobeStore(defaults: defaults)
            #expect(store.ownedOutfits == [.basic])
            #expect(store.equippedOutfit == .basic && store.selectedIcon == .basic)
        }
    }
    #endif
}
