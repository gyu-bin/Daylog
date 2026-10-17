import Foundation

/// Stable identifiers belong to the existing iOS application. Never derive them
/// from the running target's bundle ID: the direct-distribution Mac is different.
enum PioProductRegistry {
    struct Entry: Identifiable, Sendable {
        let outfit: PioOutfitID
        let productID: String
        var id: String { productID }
        var displayName: String { outfit.title }
        var category: PioOutfitCategory { outfit.category }
        var artworkReference: String? { outfit.artAssetName }
    }

    static let entries: [Entry] = PioOutfitID.allCases.filter { $0 != .basic }.map {
        Entry(outfit: $0, productID: "com.mungyubin.daylog.ios.outfit.\($0.rawValue)")
    }
    static let productIDs = Set(entries.map(\.productID))
    static func productID(for outfit: PioOutfitID) -> String? {
        entries.first { $0.outfit == outfit }?.productID
    }
    static func outfit(for productID: String) -> PioOutfitID? {
        entries.first { $0.productID == productID }?.outfit
    }
}
