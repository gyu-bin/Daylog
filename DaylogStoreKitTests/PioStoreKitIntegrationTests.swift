import XCTest
import StoreKit
import StoreKitTest
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import Daylog

/// Serial, isolated tests of the real StoreKit 2 adapter against Apple's local ledger.
/// Run with DaylogStoreKitTests (Mac) or DaylogiOSStoreKit (iOS simulator).
/// Other schemes skip these tests so ordinary testing cannot enable purchases.
@MainActor
final class PioStoreKitIntegrationTests: XCTestCase {
    private var session: SKTestSession!
    private var managers: [PioPurchaseManager] = []

    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-pio-storekit-testing"),
                          "Use a dedicated StoreKit testing scheme.")
        #if DEBUG
        XCTAssertEqual(StoreKitPioClient.debugActiveRawListenerCount, 0,
                       "A previous test must join its StoreKit listener before resetting the shared ledger")
        StoreKitPioClient.resetDebugEvents()
        #endif
        let configuration = Bundle(for: Self.self).url(forResource: "Routimori", withExtension: "storekit")
            ?? URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Routimori.storekit")
        let data = try Data(contentsOf: configuration)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let configuredProducts = try XCTUnwrap(json["products"] as? [[String: Any]])
        XCTAssertEqual(Set(configuredProducts.compactMap { $0["productID"] as? String }), PioProductRegistry.productIDs)
        for product in configuredProducts {
            let configuredPrice = try XCTUnwrap(product["displayPrice"] as? String)
            XCTAssertEqual(Decimal(string: configuredPrice, locale: Locale(identifier: "en_US_POSIX")), Decimal(2500))
            XCTAssertEqual(product["type"] as? String, "NonConsumable")
        }
        session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        session.askToBuyEnabled = false
        session.interruptedPurchasesEnabled = false
        try await clearInjectedErrors()
        session.clearTransactions()
        XCTAssertTrue(session.allTransactions().isEmpty, "Each test must begin with an empty StoreKitTest ledger")
        session.disableDialogs = true
        session.locale = Locale(identifier: "ko_KR")
        session.storefront = "KOR"
        XCTAssertEqual(session.storefront, "KOR", "StoreKitTest must accept storefront overrides")
        XCTAssertTrue(session.disableDialogs, "Local StoreKit automation must suppress purchase authentication dialogs")
        let setup = XCTAttachment(string: "Test: \(name)\nProcess ID: \(ProcessInfo.processInfo.processIdentifier)\nConfiguration: \(configuration.path)\nProducts: \(configuredProducts.count)\nStorefront: \(session.storefront)\nLocale: \(session.locale.identifier)\nDisable dialogs: \(session.disableDialogs)")
        setup.name = "Local StoreKit session setup"
        setup.lifetime = .keepAlways
        add(setup)
    }

    override func tearDown() async throws {
        guard let session else { return }
        defer { self.session = nil }
        // StoreKitTest controls one shared ledger. Join both listener layers and
        // their current processing before changing it for the next test.
        for manager in managers { await manager.stop() }
        managers.removeAll()
        #if DEBUG
        XCTAssertEqual(StoreKitPioClient.debugActiveRawListenerCount, 0,
                       "No StoreKit subscriptions may survive fixture teardown")
        let adapter = XCTAttachment(string: StoreKitPioClient.debugEvents.joined(separator: "\n"))
        adapter.name = "Local StoreKit adapter acknowledgement and updates"
        adapter.lifetime = .keepAlways
        add(adapter)
        #endif
        let ledger = session.allTransactions().map {
            "id=\($0.identifier) product=\($0.productIdentifier) state=\($0.state.rawValue) pending=\($0.pendingAskToBuyConfirmation) issue=\($0.hasPurchaseIssue)"
        }.joined(separator: "\n")
        let artifact = XCTAttachment(string: ledger.isEmpty ? "Local StoreKit ledger is empty" : ledger)
        artifact.name = "Local StoreKit transaction ledger"
        artifact.lifetime = .keepAlways
        add(artifact)
        session.clearTransactions()
        session.resetToDefaultState()
        session.askToBuyEnabled = false
        session.interruptedPurchasesEnabled = false
        try await clearInjectedErrors()
    }

    private func clearInjectedErrors() async throws {
        // Error injection is asynchronous API state. Explicitly undo every API
        // fault used by this suite rather than relying on property reset alone.
        // Attempt all three resets even when one fails, then fail the fixture.
        var firstError: Error?
        do { try await session.setSimulatedError(nil, forAPI: .verification) }
        catch { firstError = error }
        do { try await session.setSimulatedError(nil, forAPI: .purchase) }
        catch { if firstError == nil { firstError = error } }
        do { try await session.setSimulatedError(nil, forAPI: .loadProducts) }
        catch { if firstError == nil { firstError = error } }
        let verificationError = await session.simulatedError(forAPI: .verification)
        let purchaseError = await session.simulatedError(forAPI: .purchase)
        let loadError = await session.simulatedError(forAPI: .loadProducts)
        XCTAssertNil(verificationError, "Verification fault must not leak between tests")
        XCTAssertNil(purchaseError, "Purchase fault must not leak between tests")
        XCTAssertNil(loadError, "Product-loading fault must not leak between tests")
        XCTAssertFalse(session.askToBuyEnabled)
        XCTAssertFalse(session.interruptedPurchasesEnabled)
        if let firstError { throw firstError }
    }

    private func makeManager() -> PioPurchaseManager {
        let manager = PioPurchaseManager(availability: .localTesting)
        managers.append(manager)
        return manager
    }

    private func manager() async throws -> PioPurchaseManager {
        let manager = makeManager()
        await manager.start()
        XCTAssertEqual(manager.productLoadState, .available, "Local StoreKit preflight/product loading failed")
        XCTAssertEqual(manager.products.count, 13)
        return manager
    }

    private func transaction(for outfit: PioOutfitID) throws -> SKTestTransaction {
        let id = try XCTUnwrap(PioProductRegistry.productID(for: outfit))
        return try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == id })
    }

    func testConfigurationLoadsThirteenNonConsumablesAtKoreanDisplayPrice() async throws {
        // Probe StoreKit directly first: distinguish session configuration from
        // application preflight, without ever initiating payment/authentication.
        let products = try await Product.products(for: PioProductRegistry.productIDs)
        let prices = products.sorted { $0.id < $1.id }.map {
            "\($0.id): price=\($0.price) displayPrice=\($0.displayPrice) currency=\($0.priceFormatStyle.currencyCode)\njson=\(String(data: $0.jsonRepresentation, encoding: .utf8) ?? "")"
        }.joined(separator: "\n")
        let catalogArtifact = XCTAttachment(string: prices)
        catalogArtifact.name = "StoreKit product prices and JSON"
        catalogArtifact.lifetime = .keepAlways
        add(catalogArtifact)
        XCTAssertEqual(Set(products.map(\.id)), PioProductRegistry.productIDs)
        XCTAssertEqual(products.count, 13)
        for product in products {
            XCTAssertEqual(product.type, .nonConsumable)
            XCTAssertEqual(product.priceFormatStyle.currencyCode, "KRW")
            XCTAssertEqual(product.displayPrice, "₩2,500")
            // Xcode 27/macOS 27 local StoreKit currently returns price=2.5 while
            // displayPrice=₩2,500 and JSON priceString=2,500. Preserve the raw
            // evidence above; do not "fix" app prices or inflate configuration.
        }
        let manager = try await manager()
        XCTAssertNil(manager.products[.basic])
        XCTAssertTrue(manager.owns(.basic))
        guard case .verified(let app) = try await AppTransaction.shared else {
            return XCTFail("Xcode AppTransaction must verify")
        }
        XCTAssertEqual(app.environment, .xcode)
    }

    func testPurchaseDuplicateRelaunchAndRepeatedEquipmentUseVerifiedLedger() async throws {
        let manager = try await manager()
        let suite = "PioStoreKitIntegrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let wardrobe = PioWardrobeStore(defaults: defaults, purchases: manager)
        XCTAssertFalse(wardrobe.equip(.cafe))
        let purchased = await manager.purchase(.cafe)
        XCTAssertEqual(purchased, .purchased(.cafe))
        XCTAssertTrue(manager.owns(.cafe))
        XCTAssertTrue(wardrobe.equip(.cafe))
        for _ in 0..<3 {
            XCTAssertTrue(wardrobe.equip(.basic))
            XCTAssertTrue(wardrobe.equip(.cafe))
        }
        let count = session.allTransactions().count
        let duplicate = await manager.purchase(.cafe)
        XCTAssertEqual(duplicate, .purchased(.cafe))
        XCTAssertEqual(session.allTransactions().count, count, "Owned non-consumables must not purchase again")
        // A fresh manager has no in-memory ownership. It recovers from Apple's ledger.
        let reopened = makeManager()
        let reopenedWardrobe = PioWardrobeStore(defaults: defaults, purchases: reopened)
        XCTAssertFalse(reopened.owns(.cafe))
        await reopened.start()
        XCTAssertTrue(reopened.owns(.cafe))
        XCTAssertEqual(reopenedWardrobe.equippedOutfit, .cafe)
        let productID = try XCTUnwrap(PioProductRegistry.productID(for: .cafe))
        guard case .verified(let transaction) = await Transaction.latest(for: productID) else {
            return XCTFail("Purchase must produce a verified StoreKit transaction")
        }
        XCTAssertEqual(transaction.environment, .xcode)
        XCTAssertNil(transaction.revocationDate)
    }

    func testPendingAskToBuyDoesNotUnlockUntilApprovedUpdate() async throws {
        let manager = try await manager()
        session.askToBuyEnabled = true
        let result = await manager.purchase(.hanbok)
        XCTAssertEqual(result, .pending)
        XCTAssertFalse(manager.owns(.hanbok))
        XCTAssertFalse(manager.isBusy)
        let pending = try transaction(for: .hanbok)
        XCTAssertTrue(pending.pendingAskToBuyConfirmation)
        let approved = expectation(description: "Verified Ask to Buy update grants ownership")
        defer { manager.ownershipDidChange = nil }
        manager.ownershipDidChange = { _ in
            if manager.owns(.hanbok) { approved.fulfill() }
        }
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        await fulfillment(of: [approved], timeout: 10)
        manager.ownershipDidChange = nil
        XCTAssertTrue(manager.owns(.hanbok))
    }

    func testRefundUpdateRevokesAccessAndRefreshResetsEquipment() async throws {
        let manager = try await manager()
        let result = await manager.purchase(.winter)
        XCTAssertEqual(result, .purchased(.winter))
        let suite = "PioStoreKitRefundTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let wardrobe = PioWardrobeStore(defaults: defaults, purchases: manager)
        XCTAssertTrue(wardrobe.equip(.winter))
        let repairSelections = manager.ownershipDidChange
        let revoked = expectation(description: "Refund transaction update removes ownership")
        defer { manager.ownershipDidChange = nil }
        manager.ownershipDidChange = { invalidated in
            repairSelections?(invalidated)
            if !manager.owns(.winter) { revoked.fulfill() }
        }
        try session.refundTransaction(identifier: try transaction(for: .winter).identifier)
        await fulfillment(of: [revoked], timeout: 10)
        manager.ownershipDidChange = nil
        XCTAssertFalse(manager.owns(.winter))
        XCTAssertEqual(wardrobe.equippedOutfit, .basic)
        XCTAssertFalse(wardrobe.equip(.winter))
        let refreshed = await manager.refreshEntitlements()
        XCTAssertTrue(refreshed)
        XCTAssertFalse(manager.owns(.winter))
        XCTAssertTrue(manager.owns(.basic))
    }

    func testEveryPremiumOutfitPurchasesEquipsAndLoadsApprovedArtwork() async throws {
        let manager = try await manager()
        let suite = "PioStoreKitAllOutfits.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let wardrobe = PioWardrobeStore(defaults: defaults, purchases: manager)
        var purchased = Set<PioOutfitID>()
        for entry in PioProductRegistry.entries {
            XCTAssertEqual(PioProductRegistry.outfit(for: entry.productID), entry.outfit)
            XCTAssertEqual(manager.product(for: entry.outfit)?.id, entry.productID)
            XCTAssertFalse(wardrobe.equip(entry.outfit), "Unpurchased \(entry.outfit.rawValue) must remain locked")
            let artwork = try XCTUnwrap(entry.artworkReference)
            XCTAssertEqual(artwork, entry.outfit.artAssetName)
            #if os(macOS)
            let image = try XCTUnwrap(NSImage(named: NSImage.Name(artwork)), "Approved artwork missing: \(artwork)")
            #else
            let image = try XCTUnwrap(UIImage(named: artwork), "Approved artwork missing: \(artwork)")
            #endif
            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertGreaterThan(image.size.height, 0)
            let result = await manager.purchase(entry.outfit)
            XCTAssertEqual(result, .purchased(entry.outfit))
            XCTAssertTrue(wardrobe.equip(entry.outfit))
            XCTAssertEqual(wardrobe.equippedOutfit, entry.outfit)
            #if DEBUG
            // Real purchased/equipped costume must resolve the existing genuine
            // rig for every action; never modify artwork or animation timings.
            let rig = PioOverhaulRig()
            XCTAssertNotNil(PioOverhaulResources.manifest(wardrobe.equippedOutfit))
            for action in PioOverhaulAction.allCases {
                rig.configure(wardrobe.equippedOutfit, action: action)
                rig.setActive(true)
                XCTAssertGreaterThan(rig.animationCount, 0)
                XCTAssertNotNil(rig.layers["body"])
                XCTAssertNotNil(rig.layers["eyeLeft"])
                rig.setActive(false)
                XCTAssertEqual(rig.animationCount, 0)
            }
            #endif
            purchased.insert(entry.outfit)
            XCTAssertEqual(manager.ownedOutfits, purchased.union([.basic]))
            guard case .verified(let transaction) = await Transaction.latest(for: entry.productID) else {
                XCTFail("Missing verified transaction for \(entry.productID)")
                continue
            }
            XCTAssertEqual(transaction.productID, entry.productID)
            XCTAssertEqual(transaction.productType, .nonConsumable)
            XCTAssertEqual(transaction.environment, .xcode)
        }
        XCTAssertEqual(purchased.count, 13)
        XCTAssertEqual(session.allTransactions().count, 13)
        // Observe acknowledgement only: never finish, sync, or clear from this
        // check. Preserve the immediate ledger even if a later snapshot settles.
        let clock = ContinuousClock()
        let observationStarted = clock.now
        let deadline = observationStarted.advanced(by: .seconds(3))
        var observations: [String] = []
        var acknowledged = false
        repeat {
            var diagnostics: [String] = []
            var registeredUnfinishedIDs: [UInt64] = []
            for await result in Transaction.unfinished {
                // Unverified payloads are diagnostic data, never ownership proof.
                let transaction = result.unsafePayloadValue
                let verification: String
                switch result {
                case .verified: verification = "verified"
                case .unverified: verification = "unverified"
                }
                diagnostics.append("id=\(transaction.id) product=\(transaction.productID) verification=\(verification) environment=\(transaction.environment) purchased=\(transaction.purchaseDate)")
                if PioProductRegistry.productIDs.contains(transaction.productID) {
                    registeredUnfinishedIDs.append(transaction.id)
                }
            }
            let observedAt = clock.now
            let elapsed = observationStarted.duration(to: observedAt)
            let snapshot = "elapsed=\(elapsed) registeredUnfinishedIDs=\(registeredUnfinishedIDs)\n"
                + (diagnostics.isEmpty ? "No unfinished transactions" : diagnostics.joined(separator: "\n"))
            if observations.isEmpty {
                let initial = XCTAttachment(string: snapshot)
                initial.name = "Initial unfinished transaction snapshot"
                initial.lifetime = .keepAlways
                add(initial)
            }
            observations.append(snapshot)
            acknowledged = registeredUnfinishedIDs.isEmpty && observedAt <= deadline
            if acknowledged || observedAt >= deadline { break }
            try await clock.sleep(until: min(observedAt.advanced(by: .milliseconds(100)), deadline))
        } while clock.now < deadline
        let evidence = observations.joined(separator: "\n\n")
        let acknowledgement = XCTAttachment(string: evidence)
        acknowledgement.name = "StoreKit acknowledgement observation (3 second deadline)"
        acknowledgement.lifetime = .keepAlways
        add(acknowledgement)
        print("PioStoreKit: acknowledgement observed=\(acknowledged) elapsed=\(observationStarted.duration(to: clock.now)) snapshots=\(observations.count)")
        XCTAssertTrue(acknowledged,
                      "All registered wardrobe transactions must disappear from Transaction.unfinished within 3 seconds without test-side acknowledgement.\n\(evidence)")
    }

    func testExplicitRestoreRecoversExternalPurchase() async throws {
        let productID = try XCTUnwrap(PioProductRegistry.productID(for: .astronaut))
        _ = try await session.buyProduct(identifier: productID)
        let manager = makeManager()
        XCTAssertFalse(manager.owns(.astronaut))
        let restored = await manager.restore()
        XCTAssertEqual(restored, .restored([.astronaut]))
        XCTAssertTrue(manager.owns(.astronaut))
        XCTAssertFalse(manager.isBusy)
    }

    func testCancellationFromStoreKitDoesNotUnlockOrShowFailure() async throws {
        let manager = try await manager()
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        let result = await manager.purchase(.student)
        XCTAssertEqual(result, .cancelled)
        XCTAssertFalse(manager.owns(.student))
        XCTAssertFalse(manager.isBusy)
    }

    func testPurchaseFailureLeavesLockedAndAllowsRetry() async throws {
        let manager = try await manager()
        try await session.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: .purchase)
        let result = await manager.purchase(.fitness)
        guard case .failed = result else { return XCTFail("Expected StoreKit purchase failure, got \(result)") }
        XCTAssertFalse(manager.owns(.fitness))
        XCTAssertFalse(manager.isBusy)
        try await session.setSimulatedError(nil, forAPI: .purchase)
        let retried = await manager.purchase(.fitness)
        XCTAssertEqual(retried, .purchased(.fitness))
    }

    func testProductLoadFailureAndRetryUseRealStoreKitAPI() async throws {
        let manager = try await manager()
        try await session.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: .loadProducts)
        await manager.loadProducts()
        guard case .failed = manager.productLoadState else { return XCTFail("Expected failed product loading") }
        XCTAssertTrue(manager.products.isEmpty)
        let purchase = await manager.purchase(.pajamas)
        guard case .unavailable = purchase else { return XCTFail("Missing product must disable purchase") }
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        await manager.loadProducts()
        XCTAssertEqual(manager.productLoadState, .available)
    }

    func testVerificationFailureNeverGrantsFreshManagerOwnership() async throws {
        let productID = try XCTUnwrap(PioProductRegistry.productID(for: .christmas))
        // Inject before receipt creation. A receipt already verified and cached
        // by StoreKit cannot prove that verification-error injection is active.
        try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)
        let seeded = try await session.buyProduct(identifier: productID)
        XCTAssertEqual(seeded.productID, productID)
        XCTAssertEqual(session.allTransactions().count, 1)
        let manager = makeManager()
        let refreshed = await manager.refreshEntitlements()
        XCTAssertFalse(refreshed)
        XCTAssertFalse(manager.owns(.christmas))
        XCTAssertTrue(manager.owns(.basic))
    }

    func testInterruptedPurchaseOnlyUnlocksAfterResolution() async throws {
        let manager = try await manager()
        session.interruptedPurchasesEnabled = true
        var ownershipDuringInterruption = false
        var resolving = false
        let resolved = expectation(description: "Resolved interrupted purchase updates verified ownership")
        defer { manager.ownershipDidChange = nil }
        manager.ownershipDidChange = { _ in
            if manager.owns(.rainyDay) {
                if resolving { resolved.fulfill() }
                else { ownershipDuringInterruption = true }
            }
        }
        let result = await manager.purchase(.rainyDay)
        XCTAssertFalse(manager.owns(.rainyDay))
        XCTAssertFalse(ownershipDuringInterruption,"No verified ownership may arrive before issue resolution")
        XCTAssertFalse(manager.isBusy)
        XCTAssertNotEqual(result, .purchased(.rainyDay))
        let interrupted = try transaction(for: .rainyDay)
        XCTAssertTrue(interrupted.hasPurchaseIssue)
        resolving = true
        try session.resolveIssueForTransaction(identifier: interrupted.identifier)
        await fulfillment(of: [resolved], timeout: 10)
        manager.ownershipDidChange = nil
        XCTAssertTrue(manager.owns(.rainyDay))
    }
}
