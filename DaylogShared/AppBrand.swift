import Foundation

/// User-facing identity only. Persistent identifiers deliberately remain Daylog.
enum AppBrand {
    static let name = "RoutiMori"

    /// Remote UI text may contain the previous name in an existing cached payload.
    /// Normalize only this app-owned copy at presentation; never rewrite user data,
    /// URLs, product identifiers, storage keys or the cached configuration itself.
    static func displayCopy(_ copy: String) -> String {
        copy.replacingOccurrences(of: "Daylog", with: name)
            .replacingOccurrences(of: "Routimori", with: name)
            .replacingOccurrences(of: "루티모리", with: name)
    }
}
