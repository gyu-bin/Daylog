#if DEBUG
import XCTest
import StoreKit
import StoreKitTest
@testable import Daylog

/// TEST-DRIVEN LOCAL LEDGER only. This cannot certify Product.purchase(), payment
/// UI, cancellation, pending purchases, or Apple's Sandbox/App Store deployment.
@MainActor final class PioStoreKitLedgerFixtureTests: XCTestCase {
    private var session: SKTestSession!
    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-pio-storekit-ledger-fixture"))
        let url=Bundle(for:Self.self).url(forResource:"Routimori",withExtension:"storekit")
            ?? URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Routimori.storekit")
        session=try SKTestSession(contentsOf:url)
        guard case .verified(let app)=try await AppTransaction.shared,app.environment == .xcode else { throw PioStoreClientError.wrongEnvironment }
        session.resetToDefaultState();session.clearTransactions();session.disableDialogs=true
        session.askToBuyEnabled=false;session.interruptedPurchasesEnabled=false
        try await session.setSimulatedError(nil,forAPI:.verification)
        try await session.setSimulatedError(nil,forAPI:.purchase)
        try await session.setSimulatedError(nil,forAPI:.loadProducts)
        session.storefront="KOR";session.locale=Locale(identifier:"ko_KR")
    }
    override func tearDown() async throws {
        session?.clearTransactions();session?.resetToDefaultState();session=nil
    }
    private func seed(_ outfit: PioOutfitID) async throws -> Transaction {
        let product=try XCTUnwrap(PioProductRegistry.productID(for:outfit))
        let seeded=try await session.buyProduct(identifier:product)
        var rows=["Method=SKTestSession.buyProduct(identifier:), NOT Product.purchase()", "Seeded product=\(seeded.productID) id=\(seeded.id) environment=\(seeded.environment)"]
        var matching:Transaction?
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                rows.append("currentEntitlements VERIFIED product=\(transaction.productID) id=\(transaction.id) environment=\(transaction.environment)")
                if transaction.productID == product { matching=transaction }
            case .unverified(let payload,let error):
                // Diagnostic payload never grants access. Never log signed data.
                rows.append("currentEntitlements UNVERIFIED product=\(payload.productID) environment=\(payload.environment) error=\(error)")
            }
        }
        let attachment=XCTAttachment(string:rows.joined(separator:"\n"));attachment.name="TEST-DRIVEN ledger seed verification";attachment.lifetime = .keepAlways;add(attachment)
        print("PIO_LEDGER_PROBE \(rows.joined(separator:" | "))")
        XCTAssertEqual(seeded.environment,.xcode,"Seed itself must remain local")
        let verified=try XCTUnwrap(matching,"No verified currentEntitlements receipt for test-driven seed")
        XCTAssertEqual(verified.environment,.xcode)
        XCTAssertEqual(verified.id,seeded.id)
        XCTAssertNil(verified.revocationDate)
        guard seeded.environment == .xcode,verified.environment == .xcode else { throw PioStoreClientError.wrongEnvironment }
        return verified
    }
    func testSeededLedgerRequiresVerifiedXcodeReceipt() async throws {
        _ = try await seed(.cafe)
        let manager=PioPurchaseManager(availability:.localTesting)
        let refreshed=await manager.refreshEntitlements()
        XCTAssertTrue(refreshed)
        XCTAssertTrue(manager.owns(.cafe))
    }
    func testAllThirteenSeededEntitlementsEquipAndKeepTenMotionActions() async throws {
        let suite="PioStoreKitLedgerFixture.\(UUID())";let defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
        defer { defaults.removePersistentDomain(forName:suite) }
        let manager=PioPurchaseManager(availability:.localTesting)
        let wardrobe=PioWardrobeStore(defaults:defaults,purchases:manager)
        var expected:Set<PioOutfitID>=[.basic]
        assertEquippedSceneConsistency(wardrobe, expected: .basic)
        for entry in PioProductRegistry.entries {
            XCTAssertFalse(wardrobe.equip(entry.outfit))
            _ = try await seed(entry.outfit)
            let refreshed=await manager.refreshEntitlements();XCTAssertTrue(refreshed)
            expected.insert(entry.outfit);XCTAssertEqual(manager.ownedOutfits,expected)
            XCTAssertTrue(wardrobe.equip(entry.outfit));XCTAssertEqual(wardrobe.equippedOutfit,entry.outfit)
            assertEquippedSceneConsistency(wardrobe, expected: entry.outfit)
            XCTAssertNotNil(PioOverhaulResources.manifest(entry.outfit))
            let rig=PioOverhaulRig()
            for action in PioOverhaulAction.allCases {
                rig.configure(entry.outfit,action:action);rig.setActive(true)
                XCTAssertGreaterThan(rig.animationCount,0);XCTAssertNotNil(rig.layers["body"])
                rig.setActive(false);XCTAssertEqual(rig.animationCount,0)
            }
        }
    }
    func testSeededRefundRevokesOwnershipAndResetsEquipment() async throws {
        _ = try await seed(.winter)
        let manager=PioPurchaseManager(availability:.localTesting);await manager.start()
        let suite="PioStoreKitLedgerRefundFixture.\(UUID())";let defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
        defer { defaults.removePersistentDomain(forName:suite) }
        let wardrobe=PioWardrobeStore(defaults:defaults,purchases:manager);XCTAssertTrue(wardrobe.equip(.winter))
        let product=try XCTUnwrap(PioProductRegistry.productID(for:.winter))
        let transaction=try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == product })
        try session.refundTransaction(identifier:transaction.identifier)
        let refreshed=await manager.refreshEntitlements();XCTAssertTrue(refreshed)
        XCTAssertFalse(manager.owns(.winter));XCTAssertEqual(wardrobe.equippedOutfit,.basic)
    }
}
#endif
