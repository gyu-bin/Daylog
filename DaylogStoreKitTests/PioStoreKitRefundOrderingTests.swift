import XCTest
import StoreKit
import StoreKitTest
@testable import Daylog

/// Opt-in diagnosis of SDK setup ordering. Supplements, never replaces, the 11 acceptance tests.
@MainActor final class PioStoreKitRefundOrderingTests: XCTestCase {
    private var session: SKTestSession!
    private var manager: PioPurchaseManager?
    private var adapter: StoreKitPioClient?
    private var consumer: Task<Void,Never>?
    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-pio-storekit-testing") && ProcessInfo.processInfo.environment["PIO_STOREKIT_SDK_PROBE"] == "1")
        let url = Bundle(for:Self.self).url(forResource:"Routimori",withExtension:"storekit")
            ?? URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Routimori.storekit")
        session = try SKTestSession(contentsOf:url)
        // Match the passing direct SDK control's setup exactly before comparing
        // one subsequent API-call/finisher factor in a fresh test process.
        guard case .verified(let app)=try await AppTransaction.shared,app.environment == .xcode else { throw PioStoreClientError.wrongEnvironment }
        session.resetToDefaultState(); session.clearTransactions(); session.disableDialogs = true
        session.askToBuyEnabled = false; session.interruptedPurchasesEnabled = false
        session.locale=Locale(identifier:"ko_KR");session.storefront="KOR"
        try await session.setSimulatedError(nil,forAPI:.purchase)
        try await session.setSimulatedError(nil,forAPI:.verification)
        try await session.setSimulatedError(nil,forAPI:.loadProducts)
        StoreKitPioClient.resetDebugEvents()
    }
    override func tearDown() async throws {
        await manager?.stop()
        consumer?.cancel(); await adapter?.stopUpdates(); await consumer?.value
        consumer = nil; adapter = nil
        let log = XCTAttachment(string:StoreKitPioClient.debugEvents.joined(separator:"\n"))
        log.name = "Refund ordering adapter trace"; log.lifetime = .keepAlways; add(log)
        manager = nil; session?.clearTransactions(); session?.resetToDefaultState(); session = nil
    }
    private func verifyRefund(preload:Bool) async throws {
        guard case .verified(let app) = try await AppTransaction.shared, app.environment == .xcode else { throw PioStoreClientError.wrongEnvironment }
        let sut = PioPurchaseManager(availability:.localTesting); manager = sut
        if preload { await sut.loadProducts() }
        await sut.start()
        let result = await sut.purchase(.winter)
        XCTAssertEqual(result,.purchased(.winter))
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == "outfit.winter" })
        let revoked = expectation(description:"Prepared manager receives refund notification")
        var fulfilled = false
        sut.ownershipDidChange = { _ in
            if !sut.owns(.winter), !fulfilled { fulfilled = true; revoked.fulfill() }
        }
        try session.refundTransaction(identifier:transaction.identifier)
        await fulfillment(of:[revoked],timeout:10)
        XCTAssertFalse(sut.owns(.winter))
        print("PIO_REFUND_ORDER preload=\(preload) driverID=\(transaction.identifier) notified=\(fulfilled) owned=\(sut.owns(.winter))")
        sut.ownershipDidChange = nil
    }
    func testAppReceiptPreflightBeforeListener() async throws { try await verifyRefund(preload:false) }
    func testProductsPreparedBeforeListener() async throws { try await verifyRefund(preload:true) }

    func testAdapterOnlyAfterProductPreparation() async throws {
        let client=StoreKitPioClient(environment:.localTesting); adapter=client
        _ = try await client.loadProducts(ids:PioProductRegistry.productIDs)
        let event=expectation(description:"Adapter-only refund update")
        let ready=expectation(description:"Adapter consumer started")
        var transactionID:UInt64?
        let stream=client.updates()
        consumer=Task { @MainActor in
            ready.fulfill()
            for await update in stream {
                if case .verified(let receipt)=update,receipt.id==transactionID,receipt.revoked { event.fulfill() }
            }
        }
        await fulfillment(of:[ready],timeout:1)
        guard case .verified(let receipt)=try await client.purchase(productID:"outfit.winter") else { throw PioStoreClientError.unavailable }
        transactionID=receipt.id
        await client.finish(transactionID:receipt.id)
        try session.refundTransaction(identifier:UInt(receipt.id))
        await fulfillment(of:[event],timeout:10)
    }

    private func directProbe(fullCatalog:Bool=false,readAfterSubscription:Bool=false,childFinisher:Bool=false,appReceiptAfterSubscription:Bool=false) async throws {
        let products=try await Product.products(for:fullCatalog ? PioProductRegistry.productIDs : ["outfit.winter"])
        let item=try XCTUnwrap(products.first { $0.id=="outfit.winter" })
        let ready=expectation(description:"Direct subscriber started")
        let event=expectation(description:"Direct factor probe refund update")
        var transactionID:UInt64?
        consumer=Task { @MainActor in
            ready.fulfill()
            for await update in Transaction.updates {
                guard !Task.isCancelled else { break }
                if case .verified(let receipt)=update,receipt.id==transactionID,receipt.revocationDate != nil { event.fulfill() }
            }
        }
        await fulfillment(of:[ready],timeout:1)
        if appReceiptAfterSubscription { _ = try await AppTransaction.shared }
        if readAfterSubscription {
            for await _ in Transaction.currentEntitlements {}
        }
        guard case .success(.verified(let receipt))=try await item.purchase(),receipt.environment == .xcode else { throw PioStoreClientError.unavailable }
        transactionID=receipt.id
        if childFinisher {
            let finisher=PioTransactionFinisher()
            await finisher.finish(transactionID:receipt.id) { await receipt.finish() }
        } else { await receipt.finish() }
        try session.refundTransaction(identifier:UInt(receipt.id))
        await fulfillment(of:[event],timeout:10)
        print("PIO_REFUND_FACTOR fullCatalog=\(fullCatalog) readAfterSubscription=\(readAfterSubscription) childFinisher=\(childFinisher) appReceiptAfterSubscription=\(appReceiptAfterSubscription) id=\(receipt.id)")
    }
    func testDirectBaseline() async throws { try await directProbe() }
    func testDirectWithAppReceiptAfterSubscription() async throws { try await directProbe(appReceiptAfterSubscription:true) }
    func testDirectWithFullCatalog() async throws { try await directProbe(fullCatalog:true) }
    func testDirectWithEntitlementsReadAfterSubscription() async throws { try await directProbe(readAfterSubscription:true) }
    func testDirectWithChildTaskFinisher() async throws { try await directProbe(childFinisher:true) }
}
