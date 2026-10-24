import XCTest
import StoreKit
import StoreKitTest
@testable import Daylog

/// Opt-in control experiment. No Pio manager, wardrobe, acknowledgement cache,
/// ownership flags or application update stream participates in these probes.
/// They never replace the eleven application acceptance tests.
@MainActor final class PioStoreKitSDKContractTests: XCTestCase {
    private var session: SKTestSession!
    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-pio-storekit-testing")
                          && ProcessInfo.processInfo.environment["PIO_STOREKIT_SDK_PROBE"] == "1")
        let url = Bundle(for:Self.self).url(forResource:"Routimori",withExtension:"storekit")
            ?? URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Routimori.storekit")
        session = try SKTestSession(contentsOf:url)
        guard case .verified(let app) = try await AppTransaction.shared, app.environment == .xcode else {
            throw PioStoreClientError.wrongEnvironment
        }
        session.resetToDefaultState(); session.clearTransactions()
        session.disableDialogs = true; session.askToBuyEnabled = false; session.interruptedPurchasesEnabled = false
        session.locale = Locale(identifier:"ko_KR"); session.storefront = "KOR"
        try await session.setSimulatedError(nil,forAPI:.purchase)
        try await session.setSimulatedError(nil,forAPI:.verification)
        try await session.setSimulatedError(nil,forAPI:.loadProducts)
    }
    override func tearDown() async throws {
        session?.clearTransactions(); session?.resetToDefaultState(); session = nil
    }
    private func product(_ outfit:PioOutfitID) async throws -> Product {
        let id = try XCTUnwrap(PioProductRegistry.productID(for:outfit))
        let products = try await Product.products(for:[id])
        return try XCTUnwrap(products.first)
    }
    private func receipt(_ product:Product) async throws -> Transaction {
        guard case .success(.verified(let transaction)) = try await product.purchase(), transaction.environment == .xcode else {
            throw PioStoreClientError.unavailable
        }
        return transaction
    }
    private func unfinished() async -> [UInt64] {
        var ids:[UInt64] = []
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result { ids.append(transaction.id) }
        }
        return ids
    }
    private func record(_ value:String) {
        print("PIO_SDK_CONTROL \(value)")
        let attachment = XCTAttachment(string:value); attachment.name = "Direct Apple SDK control"
        attachment.lifetime = .keepAlways; add(attachment)
    }
    func testDirectSDKFinishReadbackWithSpaceFirstAndCafeLast() async throws {
        let first = try await receipt(try await product(.astronaut))
        await first.finish()
        let afterFirst = await unfinished()
        let last = try await receipt(try await product(.cafe))
        await last.finish()
        let clock = ContinuousClock(); let end = clock.now.advanced(by:.seconds(3))
        var snapshots:[[UInt64]] = []
        repeat {
            let ids = await unfinished(); snapshots.append(ids)
            if ids.isEmpty { break }
            try await clock.sleep(until:min(clock.now.advanced(by:.milliseconds(100)),end))
        } while clock.now < end
        record("Direct SDK only. spaceFirst=\(first.id) afterFirstFinish=\(afterFirst) cafeLast=\(last.id) afterLastFinish=\(snapshots)")
        XCTAssertTrue(snapshots.last?.isEmpty == true,"Even without Pio code, each awaited finish must clear the last transaction within the original three-second acceptance limit")
    }
    func testDirectSDKCancellationErrorInjection() async throws {
        let item = try await product(.student)
        try await session.setSimulatedError(.generic(.userCancelled),forAPI:.purchase)
        let injected = await session.simulatedError(forAPI:.purchase)
        XCTAssertEqual(injected,.generic(.userCancelled))
        do {
            let result = try await item.purchase()
            if case .userCancelled = result { record("Public Product.PurchaseResult.userCancelled"); return }
            record("Unexpected result \(result)"); XCTFail("The cancellation control did not return cancellation")
        } catch {
            let ns = error as NSError
            record("type=\(String(reflecting:type(of:error))) error=\(error) domain=\(ns.domain) code=\(ns.code) underlying=\(String(describing:ns.userInfo[NSUnderlyingErrorKey]))")
            if case StoreKitError.userCancelled = error { return }
            XCTFail("The public cancellation injection did not surface as a public cancellation result/error")
        }
    }
    func testDirectSDKInterruptedReceiptBeforeResolution() async throws {
        session.interruptedPurchasesEnabled = true
        let item = try await product(.rainyDay)
        do { record("Interrupted purchase result=\(try await item.purchase())") }
        catch { record("Interrupted purchase error=\(error)") }
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == item.id })
        var verifiedBefore:[UInt64] = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let receipt) = result, receipt.productID == item.id { verifiedBefore.append(receipt.id) }
        }
        record("Before resolve: driverID=\(transaction.identifier) hasPurchaseIssue=\(transaction.hasPurchaseIssue) verifiedEntitlements=\(verifiedBefore)")
        XCTAssertTrue(transaction.hasPurchaseIssue)
        XCTAssertTrue(verifiedBefore.isEmpty,"An unresolved interrupted purchase must not already have a verified entitlement")
        try session.resolveIssueForTransaction(identifier:transaction.identifier)
    }

    func testDirectSDKRefundNotificationAndEntitlements() async throws {
        // No Pio adapter/manager and no previous subscriber in this test process.
        // Compare the public raw notification with the independently read ledger.
        let item = try await product(.winter)
        let received = expectation(description:"Direct SDK verified revocation update")
        let subscribed = expectation(description:"Direct raw subscriber started")
        var receiptID:UInt64?
        var observed:[String] = []
        var fulfilled = false
        let listener = Task { @MainActor in
            subscribed.fulfill()
            for await result in Transaction.updates {
                guard !Task.isCancelled else { break }
                if case .verified(let update) = result {
                    observed.append("id=\(update.id) product=\(update.productID) revoked=\(update.revocationDate != nil)")
                    if update.id == receiptID, update.revocationDate != nil, !fulfilled {
                        fulfilled = true; received.fulfill()
                    }
                }
            }
        }
        await fulfillment(of:[subscribed],timeout:1)
        let purchased = try await receipt(item)
        receiptID = purchased.id
        await purchased.finish()
        try session.refundTransaction(identifier:UInt(purchased.id))
        await fulfillment(of:[received],timeout:10)
        var stillEntitled:[UInt64] = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let current) = result, current.productID == item.id { stillEntitled.append(current.id) }
        }
        listener.cancel(); await listener.value
        record("Direct SDK refund id=\(purchased.id) rawUpdates=\(observed) verifiedCurrentEntitlements=\(stillEntitled) receivedRevocation=\(fulfilled)")
        XCTAssertFalse(stillEntitled.contains(purchased.id),"Refund must remove the verified current entitlement")
    }
}
