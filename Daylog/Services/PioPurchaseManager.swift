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

/// Receipt policies explicitly separate local test grants from Apple-distributed grants.
enum PioStoreEnvironment: String, Equatable, Sendable {
    case localTesting, sandbox, appStore
    func accepts(_ environment: StoreKit.AppStore.Environment) -> Bool {
        switch self {
        case .localTesting: return environment == .xcode
        case .sandbox: return environment == .sandbox
        // App Store-distributed TestFlight builds use sandbox transactions.
        case .appStore: return environment == .production || environment == .sandbox
        }
    }
}

enum PioPurchaseAvailability: Equatable {
    case localTesting, sandbox, appStore
    case disabled(message: String)

    static var current: Self {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-pio-storekit-testing") { return .localTesting }
        #endif
        #if os(macOS) && !MAC_APP_STORE
        // GitHub DMG판: App Store 밖에서 배포해 Apple 앱 내 구입을 쓸 수 없다. 구매는 iPhone·iPad·Mac App Store판에서 한다.
        return .disabled(message: Self.directDistributionMessage)
        #else
        // The shipped defaults stay closed until product IDs have been confirmed
        // for this bundle in App Store Connect. A debug flag cannot bypass it.
        return configured(environment: Bundle.main.object(forInfoDictionaryKey: "PioStoreKitEnvironment") as? String,
                          catalogConfirmed: Bundle.main.object(forInfoDictionaryKey: "PioStoreKitCatalogConfirmed") as? Bool == true
                            && PioProductRegistry.isAppStoreConnectVerified)
        #endif
    }
    static let directDistributionMessage = "의상은 iPhone·iPad 앱이나 Mac App Store 버전에서 구매할 수 있어요. 여기서는 모든 의상을 미리 볼 수 있어요."
    static func configured(environment: String?, catalogConfirmed: Bool) -> Self {
        guard catalogConfirmed else { return .disabled(message: "의상 구매를 준비 중이에요. 지금은 모든 의상을 미리 볼 수 있어요.") }
        switch environment {
        case "sandbox": return .sandbox
        case "appStore": return .appStore
        default: return .disabled(message: "App Store 구매 환경이 아직 설정되지 않았어요. 의상 미리보기는 이용할 수 있어요.")
        }
    }
    var environment: PioStoreEnvironment? {
        switch self {
        case .localTesting: return .localTesting
        case .sandbox: return .sandbox
        case .appStore: return .appStore
        case .disabled: return nil
        }
    }
    var environmentLabel: String {
        switch self {
        case .localTesting: return "Apple 로컬 구매 테스트 · 실제 청구 없음"
        case .sandbox: return "Apple Sandbox 구매 테스트"
        case .appStore: return "App Store"
        case .disabled: return "구매 준비 중"
        }
    }
    var isEnabled: Bool { environment != nil }
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
    func stopUpdates() async
    func finish(transactionID: UInt64) async
    func sync() async throws
}

extension PioStoreClient {
    /// Clients with no retained background work need no asynchronous teardown.
    func stopUpdates() async {}
}

enum PioStoreClientError: Error {
    case unavailable, cancelled, wrongEnvironment
    /// 기기에 App Store(또는 Sandbox) 계정이 없어 앱 영수증을 받을 수 없다. 권한은 주지 않고 안내 문구만 다르다.
    case accountUnavailable
}

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
    private let environment: PioStoreEnvironment
    private struct UpdateSubscription {
        let task: Task<Void, Never>
        let continuation: AsyncStream<PioTransactionEvent>.Continuation
    }
    private var updateSubscriptions: [UUID: UpdateSubscription] = [:]
    init(environment: PioStoreEnvironment = .localTesting) { self.environment = environment }
    #if DEBUG
    private static var diagnosticEvents: [String] = []
    private static var rawListenerIDs: Set<UUID> = []
    static var debugActiveRawListenerCount: Int { rawListenerIDs.count }
    static var debugEvents: [String] { diagnosticEvents }
    static func resetDebugEvents() { diagnosticEvents.removeAll(keepingCapacity: true) }
    private let diagnosticClientID = UUID().uuidString.prefix(8)
    private func record(_ message: String) {
        guard ProcessInfo.processInfo.arguments.contains("-pio-storekit-testing") else { return }
        let entry = "client=\(diagnosticClientID) time=\(Date().timeIntervalSince1970) \(message)"
        Self.diagnosticEvents.append(entry)
        if Self.diagnosticEvents.count > 256 { Self.diagnosticEvents.removeFirst(Self.diagnosticEvents.count-256) }
        print("PioStoreKit: \(entry)")
    }
    #endif

    /// Validates the signed app receipt before product/payment/restore requests.
    /// Transaction acceptance below independently enforces the same environment.
    /// This does not guarantee SDK payment-UI routing: Xcode's active StoreKit
    /// configuration must also be attached. A verified local AppTransaction alone
    /// has empirically not prevented misconfigured CLI runs opening Sandbox UI.
    private func requireConfiguredEnvironment() async throws {
        let shared: VerificationResult<AppTransaction>
        do {
            shared = try await AppTransaction.shared
        } catch {
            // 계정이 없을 때 StoreKit은 내부 오류(noAccount)를 감싸서 던진다. 공개 타입이 없어 설명 글자로만 구분한다.
            // 안내 문구를 고르는 데만 쓰고, 어느 경우든 요청을 거절한다(검증 정책은 그대로).
            if String(reflecting: error).contains("noAccount") { throw PioStoreClientError.accountUnavailable }
            throw error
        }
        guard case .verified(let app) = shared,
              environment.accepts(app.environment) else { throw PioStoreClientError.wrongEnvironment }
        if environment != .localTesting {
            guard app.bundleID == PioProductRegistry.verifiedBundleID,
                  Bundle.main.bundleIdentifier == PioProductRegistry.verifiedBundleID else { throw PioStoreClientError.wrongEnvironment }
        }
        #if !DEBUG
        if environment == .localTesting { throw PioStoreClientError.unavailable }
        #endif
    }

    func loadProducts(ids: Set<String>) async throws -> [PioStoreProduct] {
        try await requireConfiguredEnvironment()
        let loaded = try await Product.products(for: ids)
        products = Dictionary(uniqueKeysWithValues: loaded.filter { $0.type == .nonConsumable }.map { ($0.id, $0) })
        return products.values.map { PioStoreProduct(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice) }
    }

    func purchase(productID: String) async throws -> PioStorePurchaseResult {
        try await requireConfiguredEnvironment()
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
              environment.accepts(transaction.environment),
              environment == .localTesting || transaction.appBundleID == PioProductRegistry.verifiedBundleID,
              transaction.productType == .nonConsumable,
              PioProductRegistry.productIDs.contains(transaction.productID) else { return nil }
        transactions[transaction.id] = transaction
        #if DEBUG
        record("accepted id=\(transaction.id) product=\(transaction.productID) revoked=\(transaction.revocationDate != nil)")
        #endif
        return PioVerifiedTransaction(id: transaction.id, productID: transaction.productID,
                                      revoked: transaction.revocationDate != nil || transaction.isUpgraded)
    }

    func currentEntitlements() async throws -> PioEntitlementSnapshot {
        try await requireConfiguredEnvironment()
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
        let id = UUID()
        let pair = AsyncStream<PioTransactionEvent>.makeStream()
        let continuation = pair.continuation
        let task = Task { [weak self] in
            #if DEBUG
            Self.rawListenerIDs.insert(id)
            self?.record("raw listener started subscription=\(id)")
            #endif
            defer {
                #if DEBUG
                Self.rawListenerIDs.remove(id)
                self?.record("raw listener ended subscription=\(id)")
                #endif
                continuation.finish()
                self?.updateSubscriptions.removeValue(forKey: id)
            }
            for await result in Transaction.updates {
                guard !Task.isCancelled, let self else { break }
                #if DEBUG
                switch result {
                case .verified(let transaction):
                    record("raw verified update id=\(transaction.id) product=\(transaction.productID) environment=\(transaction.environment) revoked=\(transaction.revocationDate != nil)")
                case .unverified(_, let error):
                    record("raw unverified update error=\(error)")
                }
                #endif
                if let transaction = self.accepted(result) { continuation.yield(.verified(transaction)) }
                else if PioProductRegistry.productIDs.contains(result.unsafePayloadValue.productID) {
                    continuation.yield(.unverified(productID: result.unsafePayloadValue.productID))
                }
            }
        }
        updateSubscriptions[id] = UpdateSubscription(task: task, continuation: continuation)
        continuation.onTermination = { _ in task.cancel() }
        return pair.stream
    }

    /// Cancellation alone does not prove that Apple's raw iterator has exited.
    /// Join all subscriptions that existed when teardown began before a caller
    /// resets a shared local test ledger or deliberately releases this client.
    func stopUpdates() async {
        let subscriptions = updateSubscriptions
        for subscription in subscriptions.values {
            subscription.task.cancel()
            subscription.continuation.finish()
        }
        for subscription in subscriptions.values { await subscription.task.value }
        for id in subscriptions.keys { updateSubscriptions.removeValue(forKey: id) }
    }

    func finish(transactionID: UInt64) async {
        #if DEBUG
        let diagnostics = ProcessInfo.processInfo.arguments.contains("-pio-storekit-testing")
        if diagnostics { record("finish requested id=\(transactionID) cached=\(transactions[transactionID] != nil) inFlight=\(transactionFinisher.inFlightCount)") }
        #endif
        // Check the shared operation before the cache. Removing the cached value
        // before awaiting finish lets a simultaneous purchase/update return early.
        await transactionFinisher.finish(transactionID: transactionID) { [self] in
            guard let transaction = transactions[transactionID] else {
                #if DEBUG
                if diagnostics { record("finish missing cached verified transaction id=\(transactionID)") }
                #endif
                return
            }
            #if DEBUG
            if diagnostics { record("finish begin id=\(transaction.id) product=\(transaction.productID) revoked=\(transaction.revocationDate != nil)") }
            #endif
            await transaction.finish()
            #if DEBUG
            if diagnostics { record("finish returned id=\(transaction.id)") }
            #endif
            transactions.removeValue(forKey: transactionID)
        }
    }

    func sync() async throws {
        try await requireConfiguredEnvironment()
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
    @ObservationIgnored private var lifecycleRevision = 0
    @ObservationIgnored private var stopTask: Task<Void, Never>?
    @ObservationIgnored private var stopToken: UUID?
    @ObservationIgnored private var refreshTask: Task<Bool, Never>?
    @ObservationIgnored private var refreshToken: UUID?
    @ObservationIgnored private var lastRefreshRevision: Int?
    @ObservationIgnored private var entitlementRevision = 0
    @ObservationIgnored private var activeTransactionIDs: [PioOutfitID: Set<UInt64>] = [:]
    @ObservationIgnored private var revokedTransactionIDs: Set<UInt64> = []
    /// A verified snapshot may repair invalid stored selections; an unknown or
    /// temporarily unavailable snapshot may not erase the user's preference.
    @ObservationIgnored var ownershipDidChange: ((Set<PioOutfitID>?) -> Void)?

    init(client: (any PioStoreClient)? = nil, availability: PioPurchaseAvailability = .current) {
        self.client = client ?? StoreKitPioClient(environment: availability.environment ?? .localTesting)
        self.availability = availability
    }

    deinit { updatesTask?.cancel() }

    var isBusy: Bool {
        switch purchaseState { case .purchasing, .restoring: true; default: false }
    }
    func owns(_ outfit: PioOutfitID) -> Bool { ownedOutfits.contains(outfit) }
    func product(for outfit: PioOutfitID) -> PioStoreProduct? { products[outfit] }

    func start() async {
        if let stopTask {
            let token = stopToken
            await stopTask.value
            if stopToken == token { self.stopTask = nil; stopToken = nil }
        }
        guard availability.isEnabled, !started else { return }
        started = true
        lifecycleRevision += 1
        let revision = lifecycleRevision
        let stream = client.updates()
        updatesTask = Task { [weak self] in
            for await event in stream {
                guard !Task.isCancelled, let self else { break }
                await self.receive(event)
            }
        }
        _ = await refreshEntitlements()
        guard started, lifecycleRevision == revision else { return }
        await loadProducts()
    }

    /// Explicit lifecycle boundary, not a screen-disappearance operation. Shared
    /// app ownership monitoring stays active across navigation. Tests await this
    /// before clearing the process-global StoreKitTest ledger.
    func stop() async {
        if let stopTask { await stopTask.value; return }
        guard started || updatesTask != nil else { return }
        started = false
        lifecycleRevision += 1
        let listener = updatesTask
        updatesTask = nil
        listener?.cancel()
        let client = self.client
        let task = Task<Void, Never> {
            await client.stopUpdates()
            // A transaction already being delivered is allowed to finish its
            // verified grant/revocation and acknowledgement before stopping.
            await listener?.value
        }
        let token = UUID()
        stopTask = task; stopToken = token
        await task.value
        if stopToken == token { stopTask = nil; stopToken = nil }
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
        if let refreshTask {
            let token = refreshToken
            let success = await refreshTask.value
            if refreshToken == token { self.refreshTask = nil; refreshToken = nil }
            // A completed task can still be retained while its creator resumes.
            // Do not let Restore join a result completed before AppStore.sync.
            if lastRefreshRevision != entitlementRevision { return await refreshEntitlements() }
            return success
        }
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
                    // Refunds observed during reconciliation are terminal for
                    // that transaction ID, even if an old update arrives later.
                    revokedTransactionIDs.formUnion(snapshot.transactions.filter(\.revoked).map(\.id))
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
                        lastRefreshRevision = revision
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
                    lastRefreshRevision = revision
                    entitlementState = .failed(message: "구매 내역을 안전하게 확인하지 못했어요. 잠시 후 다시 확인해 주세요.")
                    ownershipDidChange?([])
                    return false
                } catch {
                    guard revision == entitlementRevision else { continue }
                    lastRefreshRevision = revision
                    entitlementState = .failed(message: Self.message(for: error))
                    return false
                }
            }
            return false
        }
        let token = UUID()
        refreshTask = task; refreshToken = token
        let success = await task.value
        if refreshToken == token { refreshTask = nil; refreshToken = nil }
        if lastRefreshRevision != entitlementRevision { return await refreshEntitlements() }
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
                // A revocation/update may interleave while finish is awaiting.
                // Report success only if the verified grant still exists.
                result = owns(outfit) && !revokedTransactionIDs.contains(transaction.id) ? .purchased(outfit) : .unverified
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
            // Force any pre-sync in-flight snapshot to retry after Apple sync.
            entitlementRevision += 1
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

    private static func isCancellation(_ error: Error, depth: Int = 0) -> Bool {
        guard depth < 8 else { return false }
        if case StoreKitError.userCancelled = error { return true }
        if case PioStoreClientError.cancelled = error { return true }
        if case StoreKitError.systemError(let underlying) = error {
            return isCancellation(underlying, depth: depth + 1)
        }
        let nsError = error as NSError
        if nsError.domain == SKErrorDomain && nsError.code == SKError.paymentCancelled.rawValue { return true }
        // Follow only Apple's public underlying-error contract. Private server
        // numbers (including 907) are never interpreted as user cancellation.
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isCancellation(underlying, depth: depth + 1)
        }
        return false
    }
    private static func message(for error: Error) -> String {
        if case PioStoreClientError.accountUnavailable = error {
            return "App Store 계정을 확인할 수 없어요. 기기 설정에서 App Store에 로그인한 뒤 다시 시도해 주세요."
        }
        if case PioStoreClientError.wrongEnvironment = error {
            return "설정된 App Store 구매 환경을 확인하지 못했어요. 올바른 테스트·배포 환경에서 다시 시도해 주세요."
        }
        return "App Store에 연결하지 못했어요. 네트워크를 확인하고 잠시 후 다시 시도해 주세요."
    }
}
