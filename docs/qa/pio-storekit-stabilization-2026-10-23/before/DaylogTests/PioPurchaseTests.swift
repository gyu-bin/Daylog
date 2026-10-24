import Foundation
import Testing
import StoreKit
@testable import Daylog

@MainActor
private final class FixturePioStoreClient: PioStoreClient {
    var products = PioProductRegistry.entries.map { PioStoreProduct(id: $0.productID, displayName: $0.displayName, displayPrice: "₩2,000") }
    var purchaseResult: PioStorePurchaseResult = .cancelled
    var snapshot = PioEntitlementSnapshot()
    var loadError: Error?
    var entitlementError: Error?
    var purchaseError: Error?
    var syncError: Error?
    var purchaseCalls = 0
    var syncCalls = 0
    var finished: [UInt64] = []
    var holdPurchase = false
    var purchaseContinuation: CheckedContinuation<Void, Never>?
    var updateContinuation: AsyncStream<PioTransactionEvent>.Continuation?
    let updateTermination = AsyncStream<Bool>.makeStream()
    var holdNextSnapshot = false
    var snapshotContinuation: CheckedContinuation<Void, Never>?
    var snapshotCalls = 0
    var holdNextFinish = false
    var finishContinuation: CheckedContinuation<Void, Never>?

    func loadProducts(ids: Set<String>) async throws -> [PioStoreProduct] {
        if let loadError { throw loadError }; return products
    }
    func purchase(productID: String) async throws -> PioStorePurchaseResult {
        purchaseCalls += 1
        if holdPurchase { await withCheckedContinuation { purchaseContinuation = $0 } }
        if let purchaseError { throw purchaseError }; return purchaseResult
    }
    func currentEntitlements() async throws -> PioEntitlementSnapshot {
        snapshotCalls += 1
        let captured = snapshot
        if holdNextSnapshot {
            holdNextSnapshot = false
            await withCheckedContinuation { snapshotContinuation = $0 }
        }
        if let entitlementError { throw entitlementError }; return captured
    }
    func updates() -> AsyncStream<PioTransactionEvent> {
        let termination = updateTermination.continuation
        return AsyncStream { continuation in
            updateContinuation = continuation
            continuation.onTermination = { reason in
                if case .cancelled = reason { termination.yield(true) }
                else { termination.yield(false) }
                termination.finish()
            }
        }
    }
    func finish(transactionID: UInt64) async {
        finished.append(transactionID)
        if holdNextFinish {
            holdNextFinish = false
            await withCheckedContinuation { finishContinuation = $0 }
        }
    }
    func sync() async throws { syncCalls += 1; if let syncError { throw syncError } }
}

@MainActor
struct PioPurchaseTests {
    private func transaction(_ outfit: PioOutfitID, revoked: Bool = false, id: UInt64 = 1) -> PioVerifiedTransaction {
        PioVerifiedTransaction(id: id, productID: PioProductRegistry.productID(for: outfit)!, revoked: revoked)
    }
    private func manager(_ client: FixturePioStoreClient) -> PioPurchaseManager {
        PioPurchaseManager(client: client, availability: .localTesting)
    }
    private func withDefaults(_ body: (UserDefaults) async throws -> Void) async rethrows {
        let name = "PioPurchaseTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try await body(defaults)
    }

    @Test func environmentPoliciesNeverMixLocalAndAppleTransactions() {
        #expect(PioStoreEnvironment.localTesting.accepts(.xcode))
        #expect(!PioStoreEnvironment.localTesting.accepts(.sandbox))
        #expect(!PioStoreEnvironment.localTesting.accepts(.production))
        #expect(PioStoreEnvironment.sandbox.accepts(.sandbox))
        #expect(!PioStoreEnvironment.sandbox.accepts(.production))
        #expect(!PioStoreEnvironment.sandbox.accepts(.xcode))
        #expect(PioStoreEnvironment.appStore.accepts(.production))
        #expect(PioStoreEnvironment.appStore.accepts(.sandbox)) // TestFlight
        #expect(!PioStoreEnvironment.appStore.accepts(.xcode))
    }

    @Test func unconfirmedOrUnknownCatalogConfigurationStaysDisabled() {
        for environment in [nil,"appStore","sandbox","localTesting","unknown"] as [String?] {
            #expect(!PioPurchaseAvailability.configured(environment:environment,catalogConfirmed:false).isEnabled)
        }
        #expect(PioPurchaseAvailability.configured(environment:"sandbox",catalogConfirmed:true) == .sandbox)
        #expect(PioPurchaseAvailability.configured(environment:"appStore",catalogConfirmed:true) == .appStore)
        #expect(!PioPurchaseAvailability.configured(environment:"localTesting",catalogConfirmed:true).isEnabled)
        #expect(!PioPurchaseAvailability.configured(environment:"unknown",catalogConfirmed:true).isEnabled)
    }

    @Test func revokedSnapshotCannotBeUndoneByDelayedVerifiedUpdate() async {
        let client=FixturePioStoreClient();let sut=manager(client)
        client.snapshot.transactions=[transaction(.cafe,revoked:true,id:41)]
        await sut.start()
        #expect(!sut.owns(.cafe))
        client.updateContinuation?.yield(.verified(transaction(.cafe,id:41)))
        for _ in 0..<100 where !client.finished.contains(41) { await Task.yield() }
        #expect(!sut.owns(.cafe))
        #expect(client.finished.contains(41))
        client.updateContinuation?.finish()
    }

    @Test func stalePurchaseResultForPreviouslyRevokedIDNeverReportsPurchased() async {
        let client=FixturePioStoreClient();let sut=manager(client)
        client.snapshot.transactions=[transaction(.cafe,revoked:true,id:45)]
        await sut.start()
        client.purchaseResult = .verified(transaction(.cafe,id:45))
        #expect(await sut.purchase(.cafe) == .unverified)
        #expect(!sut.owns(.cafe))
        #expect(client.finished.contains(45))
        client.updateContinuation?.finish()
    }

    @Test func purchaseRevokedWhileFinishingCannotReportSuccess() async {
        let client=FixturePioStoreClient();let sut=manager(client)
        await sut.start()
        client.purchaseResult = .verified(transaction(.cafe,id:42));client.holdNextFinish=true
        let payment=Task { await sut.purchase(.cafe) }
        for _ in 0..<100 where client.finishContinuation == nil { await Task.yield() }
        #expect(client.finishContinuation != nil)
        #expect(sut.owns(.cafe))
        client.updateContinuation?.yield(.verified(transaction(.cafe,revoked:true,id:42)))
        for _ in 0..<100 where sut.owns(.cafe) { await Task.yield() }
        client.finishContinuation?.resume()
        #expect(await payment.value == .unverified)
        #expect(!sut.owns(.cafe))
        #expect(!sut.isBusy)
        client.updateContinuation?.finish()
    }

    @Test func registryMatchesApprovedCatalogAndOnlyNonBasicProducts() {
        #expect(PioProductRegistry.entries.count == 13)
        #expect(PioProductRegistry.productIDs.count == 13)
        #expect(PioProductRegistry.productID(for: .basic) == nil)
        #expect(PioProductRegistry.productID(for: .cherryBlossom) == "outfit.cherryblossom")
        for entry in PioProductRegistry.entries {
            #expect(PioProductRegistry.outfit(for: entry.productID) == entry.outfit)
            #expect(entry.artworkReference == entry.outfit.artAssetName)
            #expect(entry.category != .free)
        }
    }

    @Test func productsUseLocalizedPricesAndMissingProductsCannotBePurchased() async {
        let client = FixturePioStoreClient()
        client.products = [PioStoreProduct(id: PioProductRegistry.productID(for: .cafe)!, displayName: "Cafe", displayPrice: "$1.49")]
        let sut = manager(client)
        #expect(sut.productLoadState == .idle)
        await sut.loadProducts()
        #expect(sut.products[.cafe]?.displayPrice == "$1.49")
        guard case .unavailable(let missing) = sut.productLoadState else { Issue.record("Missing catalog state"); return }
        #expect(missing.count == 12)
        guard case .unavailable = await sut.purchase(.astronaut) else { Issue.record("Missing product must not purchase"); return }
        #expect(client.purchaseCalls == 0)
    }

    @Test func productFailureCanBeRetried() async {
        let client = FixturePioStoreClient(); let sut = manager(client)
        client.loadError = URLError(.notConnectedToInternet)
        await sut.loadProducts()
        guard case .failed = sut.productLoadState else { Issue.record("Missing failure"); return }
        #expect(sut.products.isEmpty)
        client.loadError = nil
        await sut.loadProducts()
        #expect(sut.productLoadState == .available)
        #expect(sut.products.count == 13)
    }

    @Test func successfulPurchaseGrantsAndFinishesOnlyVerifiedTransaction() async {
        let client = FixturePioStoreClient(); let sut = manager(client)
        client.purchaseResult = .verified(transaction(.cafe))
        await sut.loadProducts()
        #expect(await sut.purchase(.cafe) == .purchased(.cafe))
        #expect(sut.owns(.cafe))
        #expect(client.finished == [1])
        #expect(!sut.isBusy)
        #expect(await sut.purchase(.cafe) == .purchased(.cafe))
        #expect(client.purchaseCalls == 1)
    }

    @Test func cancellationPendingAndVerificationFailureNeverUnlock() async {
        for outcome in [PioStorePurchaseResult.cancelled, .pending, .unverified] {
            let client = FixturePioStoreClient(); let sut = manager(client)
            client.purchaseResult = outcome
            await sut.loadProducts()
            let result = await sut.purchase(.cafe)
            switch outcome {
            case .cancelled: #expect(result == .cancelled)
            case .pending: #expect(result == .pending)
            case .unverified: #expect(result == .unverified)
            case .verified: break
            }
            #expect(sut.ownedOutfits == [.basic])
            #expect(client.finished.isEmpty)
            #expect(!sut.isBusy)
        }
    }

    @Test func purchaseErrorsClearBusyStateAndCanRetry() async {
        let client = FixturePioStoreClient(); let sut = manager(client)
        await sut.loadProducts()
        client.purchaseError = URLError(.networkConnectionLost)
        guard case .failed = await sut.purchase(.cafe) else { Issue.record("Expected failure"); return }
        #expect(!sut.isBusy)
        client.purchaseError = nil; client.purchaseResult = .verified(transaction(.cafe))
        #expect(await sut.purchase(.cafe) == .purchased(.cafe))
    }

    @Test func mismatchedOrRevokedPurchaseResultNeverUnlocks() async {
        for tx in [transaction(.astronaut), transaction(.cafe, revoked: true)] {
            let client = FixturePioStoreClient(); let sut = manager(client)
            client.purchaseResult = .verified(tx)
            await sut.loadProducts()
            #expect(await sut.purchase(.cafe) == .unverified)
            #expect(sut.ownedOutfits == [.basic])
            #expect(client.finished.isEmpty)
            #expect(!sut.isBusy)
        }
    }

    @Test func duplicateTapsAndRestoreDuringPaymentAreRejected() async {
        let client = FixturePioStoreClient(); let sut = manager(client)
        await sut.loadProducts(); client.holdPurchase = true
        let first = Task { await sut.purchase(.cafe) }
        for _ in 0..<100 where client.purchaseContinuation == nil { await Task.yield() }
        #expect(sut.isBusy)
        #expect(sut.purchaseState == .purchasing(.cafe))
        guard case .unavailable = await sut.purchase(.astronaut), case .unavailable = await sut.restore() else {
            client.purchaseContinuation?.resume(); Issue.record("Duplicate operation started"); return
        }
        #expect(client.purchaseCalls == 1 && client.syncCalls == 0)
        client.purchaseContinuation?.resume()
        _ = await first.value
        #expect(!sut.isBusy)
    }

    @Test func refreshFailureRetainsPreviouslyVerifiedOwnership() async {
        let client = FixturePioStoreClient(); let sut = manager(client)
        #expect(sut.entitlementState == .unknown)
        client.snapshot.transactions = [transaction(.cafe)]
        #expect(await sut.refreshEntitlements())
        #expect(sut.entitlementState == .verified)
        client.entitlementError = URLError(.notConnectedToInternet)
        #expect(!(await sut.refreshEntitlements()))
        #expect(sut.owns(.cafe))
        guard case .failed = sut.entitlementState else { Issue.record("Expected failed refresh"); return }
    }

    @Test func confirmedAbsenceRevokesAndPreservesOtherPreferences() async {
        await withDefaults { defaults in
            let client = FixturePioStoreClient(); let sut = manager(client)
            let store = PioWardrobeStore(defaults: defaults, purchases: sut)
            defaults.set("keep", forKey: "unrelated")
            client.snapshot.transactions = [transaction(.cafe), transaction(.astronaut, id: 2)]
            await sut.refreshEntitlements()
            #expect(store.equip(.cafe))
            #expect(store.selectIcon(.astronaut))
            client.snapshot.transactions = [transaction(.astronaut, id: 2)]
            await sut.refreshEntitlements()
            #expect(store.equippedOutfit == .basic)
            #expect(store.selectedIcon == .astronaut)
            #expect(!store.equip(.cafe))
            #expect(defaults.string(forKey: "unrelated") == "keep")
        }
    }

    @Test func reopenWaitsForVerifiedLedgerAndNeverTrustsMockDefaults() async {
        await withDefaults { defaults in
            defaults.set("cafe", forKey: PioWardrobeStore.equippedKey)
            defaults.set("astronaut", forKey: PioWardrobeStore.selectedIconKey)
            defaults.set(["cafe", "astronaut", "pajamas"], forKey: "PioWardrobe.debugOwnedOutfits.v1")
            let client = FixturePioStoreClient(); let sut = manager(client)
            let store = PioWardrobeStore(defaults: defaults, purchases: sut)
            #expect(store.ownedOutfits == [.basic])
            #expect(store.equippedOutfit == .basic)
            #expect(defaults.string(forKey: PioWardrobeStore.equippedKey) == "cafe")
            client.entitlementError = URLError(.notConnectedToInternet)
            await sut.refreshEntitlements()
            #expect(defaults.string(forKey: PioWardrobeStore.equippedKey) == "cafe")
            client.entitlementError = nil
            client.snapshot.transactions = [transaction(.cafe), transaction(.astronaut, id: 2)]
            await sut.refreshEntitlements()
            #expect(store.equippedOutfit == .cafe && store.selectedIcon == .astronaut)
            #expect(!store.owns(.pajamas))
            #expect(!store.selectIcon(.pajamas))
        }
    }

    @Test func restoreIsExplicitHandlesEmptySuccessAndCancellation() async {
        let client = FixturePioStoreClient(); let sut = manager(client)
        await sut.start()
        #expect(client.syncCalls == 0)
        #expect(await sut.restore() == .restored([]))
        client.snapshot.transactions = [transaction(.hanbok)]
        #expect(await sut.restore() == .restored([.hanbok]))
        client.syncError = PioStoreClientError.cancelled
        #expect(await sut.restore() == .cancelled)
        #expect(sut.owns(.hanbok) && !sut.isBusy)
        client.syncError = URLError(.notConnectedToInternet)
        guard case .failed = await sut.restore() else { Issue.record("Expected restore error"); return }
        #expect(sut.owns(.hanbok) && !sut.isBusy)
    }

    @Test func unverifiedSnapshotCannotGrantOrReportSuccessfulRestore() async {
        let client = FixturePioStoreClient(); let sut = manager(client)
        client.snapshot.unverifiedProductIDs = [PioProductRegistry.productID(for: .cafe)!]
        #expect(!(await sut.refreshEntitlements()))
        #expect(!sut.owns(.cafe))
        guard case .failed = await sut.restore() else { Issue.record("Unverified restore cannot succeed"); return }
    }

    @Test func transactionUpdatesDeliverPendingPurchaseAndRefund() async {
        await withDefaults { defaults in
            let client = FixturePioStoreClient(); let sut = manager(client)
            let store = PioWardrobeStore(defaults: defaults, purchases: sut)
            await sut.start()
            client.updateContinuation?.yield(.verified(transaction(.cafe)))
            for _ in 0..<100 where !sut.owns(.cafe) { await Task.yield() }
            #expect(store.equip(.cafe))
            client.updateContinuation?.yield(.verified(transaction(.cafe, revoked: true)))
            for _ in 0..<100 where client.finished.count < 2 { await Task.yield() }
            #expect(!sut.owns(.cafe))
            #expect(store.equippedOutfit == .basic)
            #expect(defaults.string(forKey: PioWardrobeStore.equippedKey) == "basic")
            client.updateContinuation?.finish()
        }
    }

    @Test func restoreJoiningRefreshWaitsForStableSnapshotAfterUpdate() async {
        let client = FixturePioStoreClient(); let sut = manager(client)
        await sut.start()
        client.holdNextSnapshot = true
        let foreground = Task { await sut.refreshEntitlements() }
        for _ in 0..<100 where client.snapshotContinuation == nil { await Task.yield() }
        #expect(sut.entitlementState == .loading)
        let restore = Task { await sut.restore() }
        for _ in 0..<100 where client.syncCalls == 0 { await Task.yield() }
        client.snapshot.transactions = [transaction(.cafe, id: 2)]
        client.updateContinuation?.yield(.verified(transaction(.cafe, id: 2)))
        for _ in 0..<100 where !sut.owns(.cafe) { await Task.yield() }
        client.snapshotContinuation?.resume()
        #expect(await foreground.value)
        #expect(await restore.value == .restored([.cafe]))
        #expect(sut.owns(.cafe) && sut.entitlementState == .verified)
        #expect(client.snapshotCalls == 3)
        client.updateContinuation?.finish()
    }

    @Test func restoreRequiresPostSyncSnapshotEvenWithoutTransactionUpdate() async {
        let client=FixturePioStoreClient();let sut=manager(client)
        await sut.start();client.holdNextSnapshot=true
        let foreground=Task { await sut.refreshEntitlements() }
        for _ in 0..<100 where client.snapshotContinuation == nil { await Task.yield() }
        let restore=Task { await sut.restore() }
        for _ in 0..<100 where client.syncCalls == 0 { await Task.yield() }
        // AppStore.sync can change its local receipt without an updates event.
        client.snapshot.transactions=[transaction(.cafe,id:73)]
        client.snapshotContinuation?.resume()
        #expect(await foreground.value)
        #expect(await restore.value == .restored([.cafe]))
        #expect(sut.owns(.cafe))
        #expect(client.snapshotCalls == 3)
        client.updateContinuation?.finish()
    }

    @Test func lateRefundOfOldTransactionPreservesRepurchasedOutfitAndPreference() async {
        await withDefaults { defaults in
            let client = FixturePioStoreClient(); let sut = manager(client)
            let store = PioWardrobeStore(defaults: defaults, purchases: sut)
            client.snapshot.transactions = [transaction(.cafe, id: 1)]
            await sut.start()
            #expect(store.equip(.cafe) && store.selectIcon(.cafe))
            client.snapshot.transactions = [transaction(.cafe, id: 2)]
            client.updateContinuation?.yield(.verified(transaction(.cafe, id: 2)))
            for _ in 0..<100 where !client.finished.contains(2) { await Task.yield() }
            client.updateContinuation?.yield(.verified(transaction(.cafe, revoked: true, id: 1)))
            for _ in 0..<100 where !client.finished.contains(1) { await Task.yield() }
            #expect(sut.owns(.cafe))
            #expect(store.equippedOutfit == .cafe && store.selectedIcon == .cafe)
            #expect(defaults.string(forKey: PioWardrobeStore.equippedKey) == "cafe")
            #expect(defaults.string(forKey: PioWardrobeStore.selectedIconKey) == "cafe")
            client.updateContinuation?.finish()
        }
    }

    @Test func concurrentFinishCallersWaitForOneAcknowledgementAndCleanUp() async {
        let finisher = PioTransactionFinisher()
        var resumeFinish: CheckedContinuation<Void, Never>?
        var operationCount = 0
        var firstReturned = false
        var secondStarted = false
        var secondReturned = false
        let first = Task {
            await finisher.finish(transactionID: 7) {
                operationCount += 1
                await withCheckedContinuation { resumeFinish = $0 }
            }
            firstReturned = true
        }
        for _ in 0..<100 where resumeFinish == nil { await Task.yield() }
        #expect(resumeFinish != nil)
        let second = Task {
            secondStarted = true
            await finisher.finish(transactionID: 7) { operationCount += 1 }
            secondReturned = true
        }
        for _ in 0..<100 where !secondStarted { await Task.yield() }
        #expect(secondStarted)
        #expect(!firstReturned && !secondReturned)
        #expect(operationCount == 1 && finisher.inFlightCount == 1)

        // A different transaction must not wait behind this one's network call.
        var otherFinished = false
        await finisher.finish(transactionID: 8) { otherFinished = true }
        #expect(otherFinished && finisher.inFlightCount == 1)
        #expect(!firstReturned && !secondReturned)
        resumeFinish?.resume()
        await first.value
        await second.value
        #expect(firstReturned && secondReturned)
        #expect(operationCount == 1 && finisher.inFlightCount == 0)

        // There is no permanent completed-ID cache across later ledger events.
        await finisher.finish(transactionID: 7) { operationCount += 1 }
        #expect(operationCount == 2 && finisher.inFlightCount == 0)
    }

    @Test func managerLifetimeDoesNotRetainOldTransactionListener() async {
        let client = FixturePioStoreClient()
        var sut: PioPurchaseManager? = manager(client)
        weak var released = sut
        await sut?.start()
        client.updateContinuation?.yield(.verified(transaction(.cafe)))
        for _ in 0..<100 where client.finished.isEmpty { await Task.yield() }
        let termination = client.updateTermination.stream
        sut = nil
        // Deinit releases the manager before cancellation has necessarily
        // propagated through AsyncStream. Observe the real termination event,
        // with a bounded timeout; scheduler-yield counts are not a clock.
        let cancelled = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await wasCancelled in termination { return wasCancelled }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(2))
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
        #expect(cancelled, "Manager deinit must cancel its StoreKit update stream within the deadline")
        #expect(released == nil)
        let update = client.updateContinuation?.yield(.verified(transaction(.astronaut, id: 2)))
        if case .terminated = update { } else { Issue.record("Released manager must terminate its old stream") }
    }

    @Test func localTestingPreferencesNeverChangeProductionSelections() async {
        await withDefaults { production in
            await withDefaults { isolated in
                production.set("cafe", forKey: PioWardrobeStore.equippedKey)
                production.set("astronaut", forKey: PioWardrobeStore.selectedIconKey)
                production.set(4, forKey: PioWardrobeStore.previewStageKey)
                let selected = PioWardrobeStore.preferences(for: .localTesting, production: production, localTesting: isolated)
                #expect(selected === isolated)
                #expect(PioWardrobeStore.preferences(for: .disabled(message: "준비 중"), production: production, localTesting: isolated) === production)
                let client = FixturePioStoreClient(); let sut = manager(client)
                let store = PioWardrobeStore(defaults: selected, purchases: sut)
                #expect(store.previewStage == 1)
                client.snapshot.transactions = [transaction(.hanbok)]
                await sut.refreshEntitlements()
                #expect(store.equip(.hanbok) && store.selectIcon(.hanbok))
                store.selectPreviewStage(2)
                #expect(isolated.string(forKey: PioWardrobeStore.equippedKey) == "hanbok")
                #expect(production.string(forKey: PioWardrobeStore.equippedKey) == "cafe")
                #expect(production.string(forKey: PioWardrobeStore.selectedIconKey) == "astronaut")
                #expect(production.integer(forKey: PioWardrobeStore.previewStageKey) == 4)
            }
        }
    }

    @Test func disabledGateNeverTouchesStoreOrImportsMocks() async {
        let client = FixturePioStoreClient()
        let sut = PioPurchaseManager(client: client, availability: .disabled(message: "준비 중"))
        await sut.start(); await sut.loadProducts()
        #expect(!(await sut.refreshEntitlements()))
        guard case .unavailable = await sut.purchase(.cafe), case .unavailable = await sut.restore() else {
            Issue.record("Disabled gate must reject purchase"); return
        }
        #expect(sut.products.isEmpty && sut.ownedOutfits == [.basic])
        #expect(client.purchaseCalls == 0 && client.syncCalls == 0)
        #expect(sut.entitlementState == .unknown)
    }
}
