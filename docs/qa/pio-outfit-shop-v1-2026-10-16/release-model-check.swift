import Foundation
@main struct ReleaseWardrobeCheck {
    @MainActor static func main() async {
        let name = "PioWardrobe.ReleaseVerification.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(["cafe", "astronaut"], forKey: "PioWardrobe.debugOwnedOutfits.v1")
        defaults.set("cafe", forKey: PioWardrobeStore.equippedKey)
        defaults.set("astronaut", forKey: PioWardrobeStore.selectedIconKey)
        let store = PioWardrobeStore(defaults: defaults)
        precondition(store.ownedOutfits == [.basic])
        precondition(store.equippedOutfit == .basic && store.selectedIcon == .basic)
        precondition(!store.equip(.cafe) && !store.selectIcon(.astronaut))
        guard case .unavailable = await store.restorePurchases() else { fatalError("Restore must remain unavailable") }
        print("PASS: non-DEBUG model ignores mock ownership and rejects premium selections; restoration remains unavailable.")
    }
}
