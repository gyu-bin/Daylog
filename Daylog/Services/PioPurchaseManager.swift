import Foundation
import Observation
import StoreKit
#if os(macOS)
import AppKit
#endif

struct PioStoreProduct: Equatable, Sendable {
    let id: String
    let displayName: String
    let displayPrice: String
}

enum PioPurchaseAvailability: Equatable {
    case localTesting
    case disabled(message: String)

    static var current: Self {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-pio-storekit-testing") { return .localTesting }
        #endif
        #if os(macOS)
        return .disabled(message: "현재 Mac 배포판에서는 의상 구매를 지원하지 않아요. 의상 미리보기는 이용할 수 있어요.")
        #else
        return .disabled(message: "의상 구매를 준비 중이에요. 지금은 모든 의상을 미리 볼 수 있어요.")
        #endif
    }
    var isEnabled: Bool { self == .localTesting }
    var message: String? {
        if case .disabled(let message) = self { return message }
        return nil
    }
}

enum PioProductLoadState: Equatable {
    case idle, loading, available
    case unavailable(missing: Set<String>)
    case failed(message: String)
}

enum PioEntitlementState: Equatable {
    case unknown, loading, verified
    case failed(message: String)
}

enum PioPurchaseState: Equatable {
    case idle
    case purchasing(PioOutfitID)
    case restoring
    case completed(PioWardrobeEntitlementResult)
}

/// Only the StoreKit adapter constructs these from verified transactions in the
/// running app. Injection is internal and used by unit tests, never preferences.
struct PioVerifiedTransaction: Equatable, Sendable {
    let id: UInt64
    let productID: String
    let revoked: Bool
}

enum PioTransactionEvent: Sendable {
    case verified(PioVerifiedTransaction)
    case unverified(productID: String)
}

enum PioStorePurchaseResult: Sendable {
    case verified(PioVerifiedTransaction), cancelled, pending, unverified
}

struct PioEntitlementSnapshot: Sendable {
    var transactions: [PioVerifiedTransaction] = []
    var unverifiedProductIDs: Set<String> = []
}

@MainActor
protocol PioStoreClient: AnyObject {
    func loadProducts(ids: Set<String>) async throws -> [PioStoreProduct]
    func purchase(productID: String) async throws -> PioStorePurchaseResult
    func currentEntitlements() async throws -> PioEntitlementSnapshot
    func updates() -> AsyncStream<PioTransactionEvent>
    func finish(transactionID: UInt64) async
    func sync() async throws
}

enum PioStoreClientError: Error { case unavailable, cancelled, wrongEnvironment }

/// Coalesces acknowledgement of the same verified transaction. A caller joining
/// an in-flight finish must wait for Apple just as the first caller does.
@MainActor
final class PioTransactionFinisher {
    private var tasks: [UInt64: Task<Void, Never>] = [:]
    var inFlightCount: Int { tasks.count }

    func finish(transactionID: UInt64, operation: @escaping @MainActor () async -> Void) async {
        if let task = tasks[transactionID] {
            await task.value
            return
        }
        let task = Task { await operation() }
        tasks[transactionID] = task
        await task.value
        // Only the creator cleans up; joining callers cannot erase a newer task.
        tasks.removeValue(forKey: transactionID)
    }
}

@MainActor
final class StoreKitPioClient: PioStoreClient {
    private var products: [String: Product] = [:]
    private var transactions: [UInt64: Transaction] = [:]
    private let transactionFinisher = PioTransactionFinisher()

    /// This preflight is deliberately before payment/authentication UI. A debug
    /// flag without an attached Xcode StoreKit configuration must not charge money.
    private func requireLocalEnvironment() async throws {
        #if DEBUG
        guard case .verified(let app) = try await AppTransaction.shared,
              app.environment == .xcode else { throw PioStoreClientError.wrongEnvironment }
        #else
        throw PioStoreClientError.unavailable
        #endif
    }

    func loadProducts(ids: Set<String>) async throws -> [PioStoreProduct] {
        try await requireLocalEnvironment()
        let loaded = try await Product.products(for: ids)
        products = Dictionary(uniqueKeysWithValues: loaded.filter { $0.type == .nonConsumable }.map { ($0.id, $0) })
        return products.values.map { PioStoreProduct(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice) }
    }

    func purchase(productID: String) async throws -> PioStorePurchaseResult {
        try await requireLocalEnvironment()
        guard let product = products[productID], product.type == .nonConsumable else { throw PioStoreClientError.unavailable }
        switch try await presentPurchase(for: product) {
        case .success(let result):
            guard let transaction = accepted(result) else { return .unverified }
            guard transaction.productID == productID else { return .unverified }
            return .verified(transaction)
        case .userCancelled: return .cancelled
        case .pending: return .pending
        @unknown default: throw PioStoreClientError.unavailable
        }
    }

    private func presentPurchase(for product: Product) async throws -> Product.PurchaseResult {
        #if os(macOS)
        if #available(macOS 15.2, *),
           var window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            // Wardrobe previews may themselves be sheets. Anchor Apple's purchase
            // confirmation to the frontmost sheet instead of a covered parent.
            while let sheet = window.attachedSheet { window = sheet }
            return try await product.purchase(confirmIn: window)
        }
        #endif
        return try await product.purchase()
    }

    private func accepted(_ result: VerificationResult<Transaction>) -> PioVerifiedTransaction? {
        guard case .verified(let transaction) = result,
              transaction.environment == .xcode,
              transaction.productType == .nonConsumable,
              PioProductRegistry.productIDs.contains(transaction.productID) else { return nil }
        transactions[transaction.id] = transaction
        return PioVerifiedTransaction(id: transaction.id, productID: transaction.productID,
                                      revoked: transaction.revocationDate != nil || transaction.isUpgraded)
    }

    func currentEntitlements() async throws -> PioEntitlementSnapshot {
        try await requireLocalEnvironment()
        var snapshot = PioEntitlementSnapshot()
        for await result in Transaction.currentEntitlements {
            if let transaction = accepted(result) { snapshot.transactions.append(transaction) }
            else if PioProductRegistry.productIDs.contains(result.unsafePayloadValue.productID) {
                // Payload is used solely to deny access/report verification failure.
                snapshot.unverifiedProductIDs.insert(result.unsafePayloadValue.productID)
            }
        }
        return snapshot
    }

    func updates() -> AsyncStream<PioTransactionEvent> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                #if DEBUG
                let diagnostics = ProcessInfo.processInfo.arguments.contains("-pio-storekit-testing")
                if diagnostics { print("PioStoreKit: Transaction.updates listener started") }
                #endif
                for await result in Transaction.updates {
                    guard !Task.isCancelled, let self else { break }
                    #if DEBUG
                    if diagnostics {
                        // Local test diagnostics only; never log signed payloads.
                        switch result {
                        case .verified(let transaction):
                            print("PioStoreKit: raw verified update product=\(transaction.productID) environment=\(transaction.environment) revoked=\(transaction.revocationDate != nil)")
                        case .unverified(_, let error):
                            print("PioStoreKit: raw unverified update error=\(error)")
                        }
                    }
                    #endif
                    if let transaction = self.accepted(result) { continuation.yield(.verified(transaction)) }
                    else if PioProductRegistry.productIDs.contains(result.unsafePayloadValue.productID) {
                        continuation.yield(.unverified(productID: result.unsafePayloadValue.productID))
                    }
                }
                #if DEBUG
                if diagnostics { print("PioStoreKit: Transaction.updates listener ended") }
                #endif
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func finish(transactionID: UInt64) async {
        // Check the shared operation before the cache. Removing the cached value
        // before awaiting finish lets a simultaneous purchase/update return early.
        await transactionFinisher.finish(transactionID: transactionID) { [self] in
            guard let transaction = transactions[transactionID] else { return }
            await transaction.finish()
            transactions.removeValue(forKey: transactionID)
        }
    }

    func sync() async throws {
        try await requireLocalEnvironment()
        try await StoreKit.AppStore.sync()
    }
}

@MainActor @Observable
final class PioPurchaseManager {
    static let shared = PioPurchaseManager()
    let availability: PioPurchaseAvailability
    private(set) var products: [PioOutfitID: PioStoreProduct] = [:]
    private(set) var productLoadState: PioProductLoadState = .idle
    private(set) var entitlementState: PioEntitlementState = .unknown
    private(set) var purchaseState: PioPurchaseState = .idle
    private(set) var ownedOutfits: Set<PioOutfitID> = [.basic]
    @ObservationIgnored private let client: any PioStoreClient
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var refreshTask: Task<Bool, Never>?
    @ObservationIgnored private var entitlementRevision = 0
    @ObservationIgnored private var activeTransactionIDs: [PioOutfitID: Set<UInt64>] = [:]
    @ObservationIgnored private var revokedTransactionIDs: Set<UInt64> = []
    /// A verified snapshot may repair invalid stored selections; an unknown or
    /// temporarily unavailable snapshot may not erase the user's preference.
    @ObservationIgnored var ownershipDidChange: ((Set<PioOutfitID>?) -> Void)?

    init(client: (any PioStoreClient)? = nil, availability: PioPurchaseAvailability = .current) {
        self.client = client ?? StoreKitPioClient()
        self.availability = availability
    }

    deinit { updatesTask?.cancel() }

    var isBusy: Bool {
        switch purchaseState { case .purchasing, .restoring: true; default: false }
    }
    func owns(_ outfit: PioOutfitID) -> Bool { ownedOutfits.contains(outfit) }
    func product(for outfit: PioOutfitID) -> PioStoreProduct? { products[outfit] }

    func start() async {
        guard availability.isEnabled, !started else { return }
        started = true
        let stream = client.updates()
        updatesTask = Task { [weak self] in
            for await event in stream {
                guard !Task.isCancelled, let self else { break }
                await self.receive(event)
            }
        }
        _ = await refreshEntitlements()
        await loadProducts()
    }

    func loadProducts() async {
        guard availability.isEnabled, productLoadState != .loading else { return }
        productLoadState = .loading
        do {
            let loaded = try await client.loadProducts(ids: PioProductRegistry.productIDs)
            products = Dictionary(loaded.compactMap { product in
                PioProductRegistry.outfit(for: product.id).map { ($0, product) }
            }, uniquingKeysWith: { first, _ in first })
            let missing = PioProductRegistry.productIDs.subtracting(loaded.map(\.id))
            productLoadState = missing.isEmpty ? .available : .unavailable(missing: missing)
        } catch {
            products = [:]
            productLoadState = .failed(message: Self.message(for: error))
        }
    }

    @discardableResult func refreshEntitlements() async -> Bool {
        guard availability.isEnabled else { return false }
        if let refreshTask { return await refreshTask.value }
        entitlementState = .loading
        // The shared task includes retries, so every coalesced caller (including
        // Restore) receives the same final stable ledger result.
        let task = Task { [weak self] () -> Bool in
            guard let self else { return false }
            while !Task.isCancelled {
                let revision = entitlementRevision
                do {
                    let snapshot = try await client.currentEntitlements()
                    guard revision == entitlementRevision else { continue }
                    let validTransactions = snapshot.transactions.filter {
                        !$0.revoked && !self.revokedTransactionIDs.contains($0.id)
                    }
                    let verified = Set(validTransactions.compactMap { PioProductRegistry.outfit(for: $0.productID) })
                    let ledger = Dictionary(grouping: validTransactions, by: \.productID)
                    if snapshot.unverifiedProductIDs.isEmpty {
                        activeTransactionIDs = Dictionary(uniqueKeysWithValues: ledger.compactMap { productID, transactions in
                            PioProductRegistry.outfit(for: productID).map { ($0, Set(transactions.map(\.id))) }
                        })
                        ownedOutfits = verified.union([.basic])
                        entitlementState = .verified
                        ownershipDidChange?(nil)
                        return true
                    }
                    for transaction in validTransactions {
                        if let outfit = PioProductRegistry.outfit(for: transaction.productID) {
                            activeTransactionIDs[outfit, default: []].insert(transaction.id)
                        }
                    }
                    let invalid = Set(snapshot.unverifiedProductIDs.compactMap(PioProductRegistry.outfit))
                    ownedOutfits.formUnion(verified)
                    ownedOutfits.subtract(invalid)
                    for outfit in invalid { activeTransactionIDs[outfit] = nil }
                    entitlementState = .failed(message: "구매 내역을 안전하게 확인하지 못했어요. 잠시 후 다시 확인해 주세요.")
                    ownershipDidChange?([])
                    return false
                } catch {
                    guard revision == entitlementRevision else { continue }
                    entitlementState = .failed(message: Self.message(for: error))
                    return false
                }
            }
            return false
        }
        refreshTask = task
        let success = await task.value
        refreshTask = nil
        return success
    }

    func purchase(_ outfit: PioOutfitID) async -> PioWardrobeEntitlementResult {
        guard availability.isEnabled else { return .unavailable(message: availability.message ?? "구매를 이용할 수 없어요.") }
        guard !isBusy else { return .unavailable(message: "진행 중인 구매 또는 복원을 기다려 주세요.") }
        if owns(outfit) { return .purchased(outfit) }
        guard let product = products[outfit] else { return .unavailable(message: "상품 정보를 불러오지 못했어요. 다시 시도해 주세요.") }
        purchaseState = .purchasing(outfit)
        let result: PioWardrobeEntitlementResult
        do {
            switch try await client.purchase(productID: product.id) {
            case .verified(let transaction):
                guard transaction.productID == product.id, !transaction.revoked else {
                    purchaseState = .completed(.unverified)
                    return .unverified
                }
                await receive(.verified(transaction))
                result = .purchased(outfit)
            case .cancelled: result = .cancelled
            case .pending: result = .pending
            case .unverified: result = .unverified
            }
        } catch {
            result = Self.isCancellation(error) ? .cancelled : .failed(message: Self.message(for: error))
        }
        purchaseState = .completed(result)
        return result
    }

    func restore() async -> PioWardrobeEntitlementResult {
        guard availability.isEnabled else { return .unavailable(message: availability.message ?? "구매 복원을 이용할 수 없어요.") }
        guard !isBusy else { return .unavailable(message: "진행 중인 구매 또는 복원을 기다려 주세요.") }
        purchaseState = .restoring
        let result: PioWardrobeEntitlementResult
        do {
            // This is the only sync call site and is reached by explicit Restore.
            try await client.sync()
            if await refreshEntitlements() { result = .restored(ownedOutfits.subtracting([.basic])) }
            else { result = .failed(message: "구매 내역을 확인하지 못했어요. 연결 상태를 확인하고 다시 복원해 주세요.") }
        } catch {
            result = Self.isCancellation(error) ? .cancelled : .failed(message: Self.message(for: error))
        }
        purchaseState = .completed(result)
        return result
    }

    private func receive(_ event: PioTransactionEvent) async {
        entitlementRevision += 1
        switch event {
        case .verified(let transaction):
            guard let outfit = PioProductRegistry.outfit(for: transaction.productID) else { return }
            if transaction.revoked {
                revokedTransactionIDs.insert(transaction.id)
                activeTransactionIDs[outfit]?.remove(transaction.id)
                if activeTransactionIDs[outfit]?.isEmpty != false { ownedOutfits.remove(outfit) }
                // A refunded older transaction does not revoke a later purchase.
                // Only a reconciled ledger may permanently reset a preference.
                _ = await refreshEntitlements()
            } else if !revokedTransactionIDs.contains(transaction.id) {
                activeTransactionIDs[outfit, default: []].insert(transaction.id)
                ownedOutfits.insert(outfit)
                ownershipDidChange?([])
            }
            await client.finish(transactionID: transaction.id)
        case .unverified(let productID):
            if let outfit = PioProductRegistry.outfit(for: productID) {
                ownedOutfits.remove(outfit)
                activeTransactionIDs[outfit] = nil
            }
            entitlementState = .failed(message: "구매 내역의 인증을 확인하지 못했어요. 구매 복원을 다시 시도해 주세요.")
            ownershipDidChange?([])
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if case StoreKitError.userCancelled = error { return true }
        if case PioStoreClientError.cancelled = error { return true }
        let nsError = error as NSError
        return nsError.domain == SKErrorDomain && nsError.code == SKError.paymentCancelled.rawValue
    }
    private static func message(for error: Error) -> String {
        if case PioStoreClientError.wrongEnvironment = error {
            return "로컬 StoreKit 테스트 환경이 연결되지 않았어요. 테스트 전용 실행 구성을 확인해 주세요."
        }
        return "App Store에 연결하지 못했어요. 네트워크를 확인하고 잠시 후 다시 시도해 주세요."
    }
}
