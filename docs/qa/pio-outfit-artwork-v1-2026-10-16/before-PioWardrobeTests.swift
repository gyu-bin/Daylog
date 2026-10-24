import Foundation
import Testing
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
        for outfit in PioOutfitID.allCases where outfit != .basic {
            #expect(outfit.artAssetName == nil)
            #expect(outfit.plannedPriceText == "출시 예정 · 약 ₩1,000")
            #expect(!outfit.title.isEmpty && !outfit.description.isEmpty && !outfit.symbol.isEmpty)
        }
    }

    @Test func basicIsAlwaysFreeAndUnownedSelectionsAreRejected() {
        withDefaults { defaults in
            let store = PioWardrobeStore(defaults: defaults)
            #expect(store.ownedOutfits == [.basic])
            for outfit in PioOutfitID.allCases where outfit != .basic {
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
            let store = PioWardrobeStore(defaults: defaults)
            #expect(!store.mockPurchase(.basic))
            #expect(store.mockPurchase(.cafe))
            #expect(!store.mockPurchase(.cafe))
            #expect(store.mockPurchase(.astronaut))
            #expect(store.equip(.cafe))
            #expect(store.selectIcon(.astronaut))
            let reopened = PioWardrobeStore(defaults: defaults)
            #expect(reopened.ownedOutfits == [.basic, .cafe, .astronaut])
            #expect(reopened.equippedOutfit == .cafe && reopened.selectedIcon == .astronaut)
            reopened.unequip()
            #expect(reopened.equippedOutfit == .basic && reopened.selectedIcon == .astronaut)
        }
    }

    @Test func unknownMockIDsCannotBecomeOwnedAndResetRepairsOnlyUnownedSelections() {
        withDefaults { defaults in
            defaults.set(["unknown", "cafe", "cafe", "basic"], forKey: PioWardrobeStore.mockOwnershipKey)
            let store = PioWardrobeStore(defaults: defaults)
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
            let reopened = PioWardrobeStore(defaults: defaults)
            #expect(reopened.equippedOutfit == .basic && reopened.selectedIcon == .basic)
            #expect(reopened.ownedOutfits == [.basic])
        }
    }
    #else
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
