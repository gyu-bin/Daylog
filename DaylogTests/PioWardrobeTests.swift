import Foundation
import Testing
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import Daylog

@MainActor
struct PioWardrobeTests {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let name = "PioWardrobeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
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
            #expect(outfit.plannedPriceText == "출시 예정 · 목표 ₩2,000")
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
