import Foundation

/// Exact non-consumable IDs read from Routimori's App Store Connect catalog.
/// Outfit raw values are artwork/preference keys and must not become product IDs.
enum PioProductRegistry {
    struct Entry: Identifiable, Sendable {
        let outfit: PioOutfitID
        let productID: String
        var id: String { productID }
        var displayName: String { outfit.title }
        var category: PioOutfitCategory { outfit.category }
        var artworkReference: String? { outfit.artAssetName }
    }

    static let entries: [Entry] = [
        Entry(outfit: .cherryBlossom, productID: "outfit.cherryblossom"),
        Entry(outfit: .summerVacation, productID: "outfit.summer"),
        Entry(outfit: .autumn, productID: "outfit.autumn"),
        Entry(outfit: .winter, productID: "outfit.winter"),
        Entry(outfit: .halloween, productID: "outfit.halloween"),
        Entry(outfit: .christmas, productID: "outfit.christmas"),
        Entry(outfit: .hanbok, productID: "outfit.hanbok"),
        Entry(outfit: .cafe, productID: "outfit.cafe"),
        Entry(outfit: .student, productID: "outfit.student"),
        Entry(outfit: .fitness, productID: "outfit.workout"),
        Entry(outfit: .rainyDay, productID: "outfit.rainy"),
        Entry(outfit: .pajamas, productID: "outfit.pajamas"),
        Entry(outfit: .astronaut, productID: "outfit.space")
    ]
    // Identity evidence only, not Sandbox, sale approval or release readiness.
    // Read-only ASC verification 2026-10-23, app 6821788787:
    // docs/qa/pio-storekit-integration-2026-10-23/asc-products-confirmed.json
    static let verifiedAppStoreConnectAppID = "6821788787"
    static let verifiedBundleID = "com.mungyubin.daylog.ios"
    static let isAppStoreConnectVerified = true
    static let productIDs = Set(entries.map(\.productID))
    static func productID(for outfit: PioOutfitID) -> String? {
        entries.first { $0.outfit == outfit }?.productID
    }
    static func outfit(for productID: String) -> PioOutfitID? {
        entries.first { $0.productID == productID }?.outfit
    }
}
