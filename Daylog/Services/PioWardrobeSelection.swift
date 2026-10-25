import Foundation

/// A durable display preference, NEVER a purchase receipt or an entitlement.
/// UserDefaults remains the backward-compatible mirror. It writes asynchronously
/// and cannot acknowledge the final selection before an immediate process exit.
@MainActor protocol PioWardrobeSelectionPersisting {
    func load() -> PioOutfitID?
    func save(_ outfit: PioOutfitID) throws
}

@MainActor final class PioWardrobeSelectionFile: PioWardrobeSelectionPersisting {
    let url: URL
    init(url: URL) { self.url = url }
    private struct Selection: Codable {
        let version: Int
        let outfit: String
    }
    func load() -> PioOutfitID? {
        guard let data = try? Data(contentsOf: url),
              let selection = try? JSONDecoder().decode(Selection.self, from: data),
              selection.version == 1 else { return nil }
        return PioOutfitID(rawValue: selection.outfit)
    }
    func save(_ outfit: PioOutfitID) throws {
        let data = try JSONEncoder().encode(Selection(version: 1, outfit: outfit.rawValue))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Complete the atomic replacement before acknowledging the user's equip
        // action. No sleep, background flush, receipt cache or ownership import.
        try data.write(to: url, options: .atomic)
    }
    static func profileName(for availability: PioPurchaseAvailability, outfitTesting: Bool) -> String {
        if outfitTesting { return "outfit-testing" }
        switch availability {
        case .localTesting: return "local-storekit"
        case .sandbox: return "sandbox"
        case .appStore, .disabled: return "production"
        }
    }
    static func current(for availability: PioPurchaseAvailability, outfitTesting: Bool) -> PioWardrobeSelectionFile? {
        // Ordinary unit tests inject their own UUID file, never a real profile.
        guard !RuntimeEnvironment.isRunningTests,
              let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let profile = profileName(for: availability, outfitTesting: outfitTesting)
        return PioWardrobeSelectionFile(url: support
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.mungyubin.daylog", isDirectory: true)
            .appendingPathComponent("PioWardrobe", isDirectory: true)
            .appendingPathComponent(profile, isDirectory: true).appendingPathComponent("selection-v1.json"))
    }
}
