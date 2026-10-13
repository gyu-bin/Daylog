import Foundation
import Security

/// 로그인 정보를 이 기기의 키체인에 둔다. iCloud 키체인으로 동기화하지 않는다(기기마다 따로 로그인한다).
/// UserDefaults나 SwiftData·iCloud의 기록 저장소에는 쓰지 않는다.
final class KeychainSessionStore: CommunitySessionStore, @unchecked Sendable {
    private let service: String
    private let account = "session"

    init(service: String = "com.daylog.community") {
        self.service = service
    }

    private var query: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: false
        ]
    }

    func load() -> CommunitySession? {
        var request = query
        request[kSecReturnData] = true
        request[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(CommunitySession.self, from: data)
    }

    func save(_ session: CommunitySession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let attributes: [CFString: Any] = [kSecValueData: data, kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var item = query
            item.merge(attributes) { _, new in new }
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    func clear() {
        SecItemDelete(query as CFDictionary)
    }
}
