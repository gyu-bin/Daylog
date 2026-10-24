import XCTest
import StoreKit
import StoreKitTest
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import Daylog

/// Bounded diagnostic, not a replacement for the original acceptance test.
/// Setup and adapter API order match PioStoreKitIntegrationTests exactly, with
/// no extra AppTransaction preflight. Only the pre-refund native readback varies.
/// Requires the local scheme flag AND PIO_STOREKIT_SDK_PROBE=1; run serially.
@MainActor
final class PioStoreKitRefundReadbackTests: XCTestCase {
    private var session: SKTestSession!
    private var managers: [PioPurchaseManager] = []

    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-pio-storekit-testing")
                          && ProcessInfo.processInfo.environment["PIO_STOREKIT_SDK_PROBE"] == "1",
                          "Opt-in local StoreKit readback discriminator only.")
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

    private enum Readback: String {
        case none, currentEntitlements, unfinished, both
    }

    private func record(_ value: String) {
        let message = "time=\(Date().timeIntervalSince1970) pid=\(ProcessInfo.processInfo.processIdentifier) test=\(name) \(value)"
        print("PIO_REFUND_READBACK \(message)")
        let attachment = XCTAttachment(string: message)
        attachment.name = "Refund readback discriminator"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func nativeEntitlements() async -> [String] {
        var values: [String] = []
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                values.append("verified id=\(transaction.id) product=\(transaction.productID) environment=\(transaction.environment) revoked=\(transaction.revocationDate != nil)")
            case .unverified(_, let error):
                values.append("unverified error=\(error)")
            }
        }
        return values
    }

    private func nativeUnfinished() async -> [String] {
        var values: [String] = []
        for await result in Transaction.unfinished {
            switch result {
            case .verified(let transaction):
                values.append("verified id=\(transaction.id) product=\(transaction.productID) environment=\(transaction.environment) revoked=\(transaction.revocationDate != nil)")
            case .unverified(_, let error):
                values.append("unverified error=\(error)")
            }
        }
        return values
    }

    private func probe(_ readback: Readback) async throws {
        record("begin condition=\(readback.rawValue)")
        let manager = try await manager()
        let result = await manager.purchase(.winter)
        XCTAssertEqual(result, .purchased(.winter))
        record("purchase returned=\(result)")
        let suite = "PioStoreKitRefundReadbackTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let wardrobe = PioWardrobeStore(defaults: defaults, purchases: manager)
        XCTAssertTrue(wardrobe.equip(.winter))
        let repairSelections = manager.ownershipDidChange
        let revoked = expectation(description: "Refund transaction update removes ownership")
        var liveRevocation = false
        defer { manager.ownershipDidChange = nil }
        manager.ownershipDidChange = { invalidated in
            repairSelections?(invalidated)
            if !manager.owns(.winter), !liveRevocation {
                liveRevocation = true
                self.record("live ownership revocation delivered")
                revoked.fulfill()
            }
        }

        // The ONLY factor varied across these four probes. Never refresh the
        // manager before the original live-delivery expectation is evaluated.
        if readback == .currentEntitlements || readback == .both {
            let native = await nativeEntitlements()
            record("BEFORE refund native currentEntitlements=\(native)")
        }
        if readback == .unfinished || readback == .both {
            let native = await nativeUnfinished()
            record("BEFORE refund native unfinished=\(native)")
        }
        let driverTransaction = try transaction(for: .winter)
        record("refund request driverID=\(driverTransaction.identifier) product=\(driverTransaction.productIdentifier) state=\(driverTransaction.state.rawValue) pending=\(driverTransaction.pendingAskToBuyConfirmation) issue=\(driverTransaction.hasPurchaseIssue)")
        try session.refundTransaction(identifier: driverTransaction.identifier)
        await fulfillment(of: [revoked], timeout: 10)
        manager.ownershipDidChange = nil
        record("AFTER original ten-second live expectation liveRevocation=\(liveRevocation) ownsWinter=\(manager.owns(.winter)) effective=\(wardrobe.equippedOutfit.rawValue)")
        #if DEBUG
        record("raw/verification/finish diagnostics:\n" + StoreKitPioClient.debugEvents.joined(separator: "\n"))
        #endif
        record("native driver ledger after live expectation=" + session.allTransactions().map {
            "id=\($0.identifier) product=\($0.productIdentifier) state=\($0.state.rawValue) pending=\($0.pendingAskToBuyConfirmation) issue=\($0.hasPurchaseIssue)"
        }.joined(separator: "; "))
        // These remain failures when live delivery fails. A later snapshot must
        // never turn the live-update expectation into a reported PASS.
        XCTAssertTrue(liveRevocation, "Live refund delivery is independent of explicit reconciliation")
        XCTAssertFalse(manager.owns(.winter))
        XCTAssertEqual(wardrobe.equippedOutfit, .basic)
        XCTAssertFalse(wardrobe.equip(.winter))

        // Restore the wardrobe's real repair callback for the independent
        // reconciliation check; the live-delivery assertions above stay failed.
        manager.ownershipDidChange = repairSelections
        let refreshed = await manager.refreshEntitlements()
        record("EXPLICIT later reconciliation success=\(refreshed) ownsWinter=\(manager.owns(.winter)) effective=\(wardrobe.equippedOutfit.rawValue)")
        XCTAssertTrue(refreshed)
        XCTAssertFalse(manager.owns(.winter))
        XCTAssertTrue(manager.owns(.basic))
        XCTAssertEqual(wardrobe.equippedOutfit, .basic)
        XCTAssertFalse(wardrobe.equip(.winter))
        XCTAssertEqual(defaults.string(forKey: PioWardrobeStore.equippedKey), "basic")
    }

    func testRefundWithNoPreRefundReadback() async throws { try await probe(.none) }
    func testRefundWithCurrentEntitlementsReadback() async throws { try await probe(.currentEntitlements) }
    func testRefundWithUnfinishedReadback() async throws { try await probe(.unfinished) }
    func testRefundWithBothReadbacks() async throws { try await probe(.both) }
}
