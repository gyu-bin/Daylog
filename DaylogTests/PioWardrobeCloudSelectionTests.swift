import Foundation
import Testing
@testable import Daylog

/// iCloud 키-값 저장소 대신 쓰는 메모리 저장소.
private final class MemoryKeyValueStore: NSUbiquitousKeyValueStore {
    var values: [String: String] = [:]
    override func string(forKey aKey: String) -> String? { values[aKey] }
    override func set(_ aString: String?, forKey aKey: String) { values[aKey] = aString }
    override func synchronize() -> Bool { true }
}

@MainActor
private final class ReceiptClient: PioStoreClient {
    var snapshot = PioEntitlementSnapshot()
    var products: [PioStoreProduct] = []
    func loadProducts(ids: Set<String>) async throws -> [PioStoreProduct] { products }
    func purchase(productID: String) async throws -> PioStorePurchaseResult {
        let transaction = PioVerifiedTransaction(id: 900, productID: productID, revoked: false)
        snapshot.transactions.append(transaction)
        return .verified(transaction)
    }
    func currentEntitlements() async throws -> PioEntitlementSnapshot { snapshot }
    func updates() -> AsyncStream<PioTransactionEvent> { AsyncStream { $0.finish() } }
    func finish(transactionID: UInt64) async {}
    func sync() async throws {}
}

/// 입은 옷의 기기 사이 맞춤과 구매 직후 입히기(2026-10-26). 표시 설정일 뿐, 받은 기기에서도 검증된 소유가 있어야 입혀진다.
@MainActor
struct PioWardrobeCloudSelectionTests {
    private func receipt(_ outfit: PioOutfitID) -> PioVerifiedTransaction {
        PioVerifiedTransaction(id: 101, productID: PioProductRegistry.productID(for: outfit)!, revoked: false)
    }
    private func device(_ kvs: MemoryKeyValueStore, owns: [PioOutfitID]) -> (PioWardrobeStore, PioPurchaseManager, ReceiptClient) {
        let client = ReceiptClient()
        client.snapshot.transactions = owns.map(receipt)
        let manager = PioPurchaseManager(client: client, availability: .localTesting)
        let defaults = UserDefaults(suiteName: "PioCloudSelection.\(UUID().uuidString)")!
        let store = PioWardrobeStore(defaults: defaults, purchases: manager, cloudSelection: PioWardrobeCloudSelection(store: kvs))
        return (store, manager, client)
    }

    @Test func equippedOutfitFollowsToAnotherDeviceOnlyAfterItsOwnershipIsVerified() async {
        let kvs = MemoryKeyValueStore()
        let (phone, phoneManager, _) = device(kvs, owns: [.halloween])
        #expect(await phoneManager.refreshEntitlements())
        #expect(phone.equip(.halloween))
        #expect(kvs.values[PioWardrobeCloudSelection.key] == "halloween")

        // Mac: 아직 소유를 확인하기 전에는 기본 피오, 확인되면 할로윈.
        let (mac, macManager, macClient) = device(kvs, owns: [])
        #expect(mac.equippedOutfit == .basic)
        macClient.snapshot.transactions = [receipt(.halloween)]
        #expect(await macManager.refreshEntitlements())
        #expect(mac.equippedOutfit == .halloween)
    }

    @Test func deviceWithoutOwnershipStaysBasicAndDoesNotOverwriteTheCloudChoice() async {
        let kvs = MemoryKeyValueStore()
        kvs.values[PioWardrobeCloudSelection.key] = "halloween"
        let (other, manager, _) = device(kvs, owns: [])
        #expect(await manager.refreshEntitlements())
        #expect(other.equippedOutfit == .basic)
        #expect(kvs.values[PioWardrobeCloudSelection.key] == "halloween")
    }

    @Test func purchaseEquipsTheOutfitRightAway() async {
        let kvs = MemoryKeyValueStore()
        let (store, manager, client) = device(kvs, owns: [])
        client.products = [PioStoreProduct(id: "outfit.halloween", displayName: "할로윈 피오", displayPrice: "₩2,500")]
        await manager.loadProducts()
        #expect(await manager.refreshEntitlements())
        let result = await store.purchase(.halloween)
        #expect(result == .purchased(.halloween))
        #expect(store.equippedOutfit == .halloween)
        #expect(kvs.values[PioWardrobeCloudSelection.key] == "halloween")
    }
}

/// 옷장 숨은 해금(2026-10-26, 사용자 결정): 비밀번호가 맞으면 이 기기에서 모든 의상을 입힐 수 있고, 구매 내역은 생기지 않는다.
/// 실제 비밀번호는 저장소 어디에도 두지 않는다. 시험은 따로 만든 해시로 한다.
@MainActor
struct PioWardrobeSecretUnlockTests {
    private let testPassword = "test-only-pass"
    /// secretMatches와 같은 계산(소금 + SHA-256)으로 만든 시험용 해시.
    private var testDigest: String { PioWardrobeStoreTestDigest.make(PioWardrobeStore.secretSalt + testPassword) }

    private func clean() {
        for key in [PioWardrobeStore.secretUnlockKey, PioWardrobeStore.secretFailuresKey, PioWardrobeStore.secretLockedUntilKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    @Test func storedDigestIsNotAPlainPassword() {
        #expect(PioWardrobeStore.secretDigest.count == 64)
        #expect(!PioWardrobeStore.secretMatches("1234", digest: PioWardrobeStore.secretDigest))
        #expect(!PioWardrobeStore.secretMatches("", digest: PioWardrobeStore.secretDigest))
    }

    @Test func passwordUnlocksWearingOnlyAndLockRestoresPurchasedOnly() {
        clean(); defer { clean() }
        let defaults = UserDefaults(suiteName: "PioSecretUnlock.\(UUID().uuidString)")!
        let store = PioWardrobeStore(defaults: defaults, purchases: PioPurchaseManager(client: ReceiptClient(), availability: .localTesting))
        #expect(!store.canWear(.halloween))
        #expect(store.trySecretUnlock(password: "wrong", expectedDigest: testDigest) == .wrong(remaining: 2))
        #expect(store.trySecretUnlock(password: testPassword, expectedDigest: testDigest) == .unlocked)
        #expect(store.canWear(.halloween))
        #expect(store.equip(.halloween))
        #expect(!store.owns(.halloween))                                   // 구매 내역은 그대로
        #expect(!PioAppIconService.canSelect(.halloween, store: store))    // 아이콘은 구매한 의상만
        store.secretLock()
        #expect(!store.canWear(.halloween))
        #expect(store.equippedOutfit == .basic)
    }

    @Test func threeWrongTriesLockForTenMinutes() {
        clean(); defer { clean() }
        let defaults = UserDefaults(suiteName: "PioSecretUnlock.\(UUID().uuidString)")!
        let store = PioWardrobeStore(defaults: defaults, purchases: PioPurchaseManager(client: ReceiptClient(), availability: .localTesting))
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(store.trySecretUnlock(password: "a", now: now, expectedDigest: testDigest) == .wrong(remaining: 2))
        #expect(store.trySecretUnlock(password: "b", now: now, expectedDigest: testDigest) == .wrong(remaining: 1))
        #expect(store.trySecretUnlock(password: "c", now: now, expectedDigest: testDigest) == .lockedOut(until: now.addingTimeInterval(600)))
        // 잠긴 동안에는 맞는 비밀번호도 받지 않는다.
        #expect(store.trySecretUnlock(password: testPassword, now: now.addingTimeInterval(60), expectedDigest: testDigest) == .lockedOut(until: now.addingTimeInterval(600)))
        #expect(!store.isSecretUnlocked)
        #expect(store.trySecretUnlock(password: testPassword, now: now.addingTimeInterval(601), expectedDigest: testDigest) == .unlocked)
    }
}

import CryptoKit
enum PioWardrobeStoreTestDigest {
    static func make(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
}
