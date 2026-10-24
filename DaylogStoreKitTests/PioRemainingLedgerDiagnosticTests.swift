#if DEBUG
import XCTest
import StoreKit
import StoreKitTest
@testable import Daylog

/// Isolated Xcode ledger diagnostics, never evidence of Product.purchase or Sandbox.
@MainActor final class PioRemainingLedgerDiagnosticTests: XCTestCase {
    private var session: SKTestSession!
    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-pio-storekit-ledger-fixture"))
        let url = Bundle(for: Self.self).url(forResource: "Routimori", withExtension: "storekit") ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Routimori.storekit")
        session = try SKTestSession(contentsOf: url)
        guard case .verified(let app) = try await AppTransaction.shared, app.environment == .xcode else { throw PioStoreClientError.wrongEnvironment }
        session.resetToDefaultState(); session.clearTransactions(); session.disableDialogs = true
        session.askToBuyEnabled = false; session.interruptedPurchasesEnabled = false
        try await session.setSimulatedError(nil, forAPI: .verification)
        try await session.setSimulatedError(nil, forAPI: .purchase)
    }
    override func tearDown() async throws {
        session?.clearTransactions(); session?.resetToDefaultState(); session = nil
    }
    private func snapshot(_ product: String) async -> Transaction? {
        var match: Transaction?
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let t):
                print("PIO_MINIMAL entitlement verified product=\(t.productID) id=\(t.id) environment=\(t.environment)")
                if t.productID == product { match = t }
            case .unverified(let t, let error):
                print("PIO_MINIMAL entitlement UNVERIFIED product=\(t.productID) error=\(error)")
            }
        }
        return match
    }
    private func individual(_ outfit: PioOutfitID) async throws {
        let product = try XCTUnwrap(PioProductRegistry.productID(for: outfit))
        let seeded = try await session.buyProduct(identifier: product)
        print("PIO_MINIMAL isolated buyProduct returned product=\(product) id=\(seeded.id) time=\(Date().timeIntervalSince1970)")
        let immediate = await snapshot(product)
        // Record other SDK views after the immediate snapshot; they cannot alter its assertion.
        if let latest = await Transaction.latest(for: product) {
            switch latest {
            case .verified(let t): print("PIO_MINIMAL latest verified product=\(t.productID) id=\(t.id)")
            case .unverified(let t, _): print("PIO_MINIMAL latest UNVERIFIED product=\(t.productID)")
            }
        }
        for await result in Transaction.unfinished {
            if case .verified(let t) = result { print("PIO_MINIMAL unfinished verified product=\(t.productID) id=\(t.id)") }
        }
        let verified = try XCTUnwrap(immediate, "Immediate currentEntitlements missing in isolated minimal harness")
        XCTAssertEqual(verified.id, seeded.id); XCTAssertEqual(verified.environment, .xcode)
        let suite = "PioRemaining.\(UUID())"; let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = PioPurchaseManager(availability: .localTesting)
        let wardrobe = PioWardrobeStore(defaults: defaults, purchases: manager)
        XCTAssertFalse(wardrobe.equip(outfit))
        let refreshed = await manager.refreshEntitlements(); XCTAssertTrue(refreshed)
        XCTAssertTrue(wardrobe.equip(outfit)); assertEquippedSceneConsistency(wardrobe, expected: outfit)
        let rig = PioOverhaulRig()
        for action in PioOverhaulAction.allCases {
            rig.configure(outfit, action: action); rig.setActive(true)
            XCTAssertGreaterThan(rig.animationCount, 0); XCTAssertNotNil(rig.layers["body"])
            rig.setActive(false); XCTAssertEqual(rig.animationCount, 0)
        }
        await verified.finish()
        print("PIO_MINIMAL finish completed product=\(product) id=\(verified.id)")
    }
    func testIsolatedRainyVerifiedSceneFlow() async throws { try await individual(.rainyDay) }
    func testIsolatedPajamasVerifiedSceneFlow() async throws { try await individual(.pajamas) }
    func testIsolatedSpaceVerifiedSceneFlow() async throws { try await individual(.astronaut) }
    func testMinimalSequentialImmediateReadback() async throws {
        // No manager, wardrobe or animation work in this SDK-only sequence.
        for entry in PioProductRegistry.entries {
            let seeded = try await session.buyProduct(identifier: entry.productID)
            let immediate = await snapshot(entry.productID)
            print("PIO_MINIMAL sequential product=\(entry.productID) seeded=\(seeded.id) immediate=\(immediate?.id.description ?? "MISSING")")
            XCTAssertEqual(immediate?.id, seeded.id, "SDK-only immediate readback: \(entry.productID)")
        }
    }
}
#endif
