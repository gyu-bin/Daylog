import Foundation

/// Only bundled, reviewed configuration may activate the updater (never UserDefaults).
struct UpdateConfiguration: Equatable {
    let enabled: Bool
    let feedURL: String
    let publicKey: String

    init(info: [String: Any]) {
        enabled = info["DaylogUpdatesEnabled"] as? Bool ?? false
        feedURL = info["SUFeedURL"] as? String ?? ""
        publicKey = info["SUPublicEDKey"] as? String ?? ""
    }

    var isReady: Bool {
        guard enabled,
              let url = URL(string: feedURL), url.scheme == "https",
              url.host == "github.com", url.user == nil, url.password == nil,
              url.path == "/gyu-bin/Daylog/releases/latest/download/appcast.xml",
              url.query == nil, url.fragment == nil,
              let key = Data(base64Encoded: publicKey), key.count == 32,
              key.contains(where: { $0 != 0 }) else { return false }
        return true
    }
}
