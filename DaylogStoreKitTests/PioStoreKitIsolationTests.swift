import XCTest
import StoreKit
import StoreKitTest
@testable import Daylog

/// Bounded, opt-in forensic harness. Never substitutes for the 11 acceptance
/// cases and never imports diagnostic receipt identities as purchase permission.
@MainActor final class PioStoreKitIsolationTests: XCTestCase {
    private var session: SKTestSession?
    private var manager: PioPurchaseManager?
    private var wardrobe: PioWardrobeStore?
    private var defaults: UserDefaults?
    private var listener: Task<Void,Never>?
    private var products: [String:Product] = [:]
    private var verifiedPurchases: [Transaction] = []
    private var events: [[String:Any]] = []
    private let started = ContinuousClock.now
    private var expectation: XCTestExpectation?
    private var waitingForRevocation = false
    private var waitingForResolution = false
    private var expectationDelivered = false
    private var watchedProduct = ""
    private var mode: String { ProcessInfo.processInfo.environment["PIO_ISOLATION_MODE"]! }
    private var scenario: String { ProcessInfo.processInfo.environment["PIO_ISOLATION_SCENARIO"]! }
    private var run: String { ProcessInfo.processInfo.environment["PIO_ISOLATION_RUN_ID"]! }
    private var phase: String { ProcessInfo.processInfo.environment["PIO_ISOLATION_PHASE"]! }

    override func setUp() async throws {
        let env=ProcessInfo.processInfo.environment
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-pio-storekit-testing") && env["PIO_ISOLATION_RUN_ID"].flatMap(UUID.init(uuidString:)) != nil,
                          "Run the explicit local StoreKit isolation harness")
        XCTAssertTrue(["direct","manager"].contains(mode)); XCTAssertTrue(["cancel","interrupt","refund","finish"].contains(scenario))
        guard case .verified(let app)=try await AppTransaction.shared,app.environment == .xcode else { throw PioStoreClientError.wrongEnvironment }
        record("environment",["os":ProcessInfo.processInfo.operatingSystemVersionString,"pid":ProcessInfo.processInfo.processIdentifier,"appEnvironment":String(describing:app.environment),"mode":mode,"scenario":scenario,"phase":phase,"run":run])
        StoreKitPioClient.resetDebugEvents()
        if phase == "verify" { return } // Observe first; no session reset/clear/reinitialization.
        session=try SKTestSession(contentsOf:configuration())
        record("SKTestSession.init.return")
        session!.resetToDefaultState();record("resetToDefaultState.return")
        session!.clearTransactions();record("clearTransactions.return")
        session!.disableDialogs=true; session!.askToBuyEnabled=false; session!.interruptedPurchasesEnabled=false
        session!.locale=Locale(identifier:"ko_KR");session!.storefront="KOR"
        try await session!.setSimulatedError(nil,forAPI:.purchase)
        try await session!.setSimulatedError(nil,forAPI:.verification)
        try await session!.setSimulatedError(nil,forAPI:.loadProducts)
        XCTAssertTrue(session!.allTransactions().isEmpty)
        record("fixture.ready",["storefront":session!.storefront,"dialogsDisabled":session!.disableDialogs,"purchaseError":String(describing:await session!.simulatedError(forAPI:.purchase))])
    }
    override func tearDown() async throws {
        await manager?.stop(); listener?.cancel(); await listener?.value
        if mode == "manager" { record("adapter.trace",["events":StoreKitPioClient.debugEvents,"remainingListeners":StoreKitPioClient.debugActiveRawListenerCount]) }
        manager=nil;wardrobe=nil
        if let defaults { defaults.removePersistentDomain(forName:"PioIsolation."+run) }
        // Finish seed intentionally retains the same real SDK ledger for the
        // immediately following OS process. No ownership/selection is serialized.
        if scenario != "finish" || phase == "verify" {
            if session == nil { session=try? SKTestSession(contentsOf:configuration()) }
            session?.clearTransactions();session?.resetToDefaultState()
            if let url=try? manifestURL() { try? FileManager.default.removeItem(at:url) }
        }
        let data=try JSONSerialization.data(withJSONObject:events,options:[.prettyPrinted,.sortedKeys])
        let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
        attachment.name="StoreKit isolation ordered timeline";attachment.lifetime = .keepAlways;add(attachment)
        session=nil
    }
    private func record(_ event:String,_ payload:[String:Any]=[:]) {
        var value=payload;value["event"]=event;value["wallTime"]=Date().timeIntervalSince1970
        value["elapsed"]=String(describing:started.duration(to:.now));events.append(value)
        if let data=try? JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]) { print("PIO_ISOLATION "+String(decoding:data,as:UTF8.self)) }
    }
    private func describe(_ result:VerificationResult<Transaction>) -> [String:Any] {
        let transaction=result.unsafePayloadValue // diagnostic only; never a grant
        var value:[String:Any]=["id":String(transaction.id),"product":transaction.productID,"environment":String(describing:transaction.environment),"revoked":transaction.revocationDate != nil]
        switch result { case .verified:value["verification"]="verified"
        case .unverified(_,let error):value["verification"]="unverified";value["error"]=String(describing:error) }
        return value
    }
    private func snapshot(_ label:String) async -> ([String],[String]) {
        record("snapshot.begin",["label":label])
        var current:[[String:Any]]=[];var unfinished:[[String:Any]]=[]
        for await value in Transaction.currentEntitlements { current.append(describe(value)) }
        for await value in Transaction.unfinished { unfinished.append(describe(value)) }
        let ledger=session?.allTransactions().map { ["id":String($0.identifier),"product":$0.productIdentifier,"state":String(describing:$0.state),"issue":$0.hasPurchaseIssue,"pending":$0.pendingAskToBuyConfirmation] as [String:Any] } ?? []
        record("snapshot.return",["label":label,"currentEntitlements":current,"unfinished":unfinished,"driverLedger":ledger,"managerOwned":manager?.ownedOutfits.map(\.rawValue).sorted() ?? [],"equipped":wardrobe?.equippedOutfit.rawValue ?? "not-applicable"])
        return (current.filter{$0["verification"] as? String == "verified"}.compactMap{$0["id"] as? String},
                unfinished.compactMap{$0["id"] as? String})
    }
    private func prepare() async throws {
        if mode == "manager" {
            let sut=PioPurchaseManager(availability:.localTesting);manager=sut
            let preferences=try XCTUnwrap(UserDefaults(suiteName:"PioIsolation."+run));defaults=preferences
            wardrobe=PioWardrobeStore(defaults:preferences,purchases:sut)
            let repair=sut.ownershipDidChange
            sut.ownershipDidChange={ [weak self,weak sut] invalidated in
                repair?(invalidated)
                guard let self,let sut else { return }
                self.record("manager.ownership",["owned":sut.ownedOutfits.map(\.rawValue).sorted()])
                let outfit=PioProductRegistry.outfit(for:self.watchedProduct)
                if let outfit,self.waitingForRevocation,!sut.owns(outfit),!self.expectationDelivered {
                    self.expectationDelivered=true;self.expectation?.fulfill()
                }
                if let outfit,self.waitingForResolution,sut.owns(outfit),!self.expectationDelivered {
                    self.expectationDelivered=true;self.expectation?.fulfill()
                }
            }
            record("manager.start.begin");await sut.start();record("manager.start.return")
        } else {
            record("Product.products.begin",["requested":PioProductRegistry.productIDs.sorted()])
            let loaded=try await Product.products(for:Array(PioProductRegistry.productIDs).sorted())
            products=Dictionary(uniqueKeysWithValues:loaded.map{($0.id,$0)})
            record("Product.products.return",["returned":loaded.map(\.id).sorted()])
            let ready=expectation(description:"Diagnostic raw iterator begins")
            listener=Task { @MainActor [weak self] in
                ready.fulfill()
                for await value in Transaction.updates {
                    guard !Task.isCancelled,let self else { break }
                    self.record("Transaction.updates",self.describe(value))
                    if case .verified(let receipt)=value,receipt.productID==self.watchedProduct,self.waitingForRevocation,receipt.revocationDate != nil,!self.expectationDelivered {
                        self.expectationDelivered=true;self.expectation?.fulfill()
                    }
                    if case .verified(let receipt)=value,receipt.productID==self.watchedProduct,self.waitingForResolution,receipt.revocationDate == nil,!self.expectationDelivered {
                        self.expectationDelivered=true;self.expectation?.fulfill()
                    }
                }
            }
            await fulfillment(of:[ready],timeout:1)
            record("raw.iterator.started") // Not a claim of an SDK subscription-ready acknowledgement.
        }
    }
    private func purchase(_ outfit:PioOutfitID) async -> String {
        let id=PioProductRegistry.productID(for:outfit)!;record("purchase.begin",["product":id])
        if let manager {
            let result=await manager.purchase(outfit);record("manager.purchase.return",["result":String(describing:result),"busy":manager.isBusy])
            switch result { case .purchased:return "purchased";case .cancelled:return "cancelled";case .pending:return "pending";default:return "other" }
        }
        do {
            switch try await products[id]!.purchase() {
            case .success(let value):
                record("Product.purchase.return",describe(value))
                guard case .verified(let receipt)=value,receipt.environment == .xcode else { return "unverified" }
                verifiedPurchases.append(receipt)
                record("finish.begin",["id":String(receipt.id),"product":receipt.productID]);await receipt.finish()
                record("finish.return",["id":String(receipt.id),"product":receipt.productID]);return "purchased"
            case .userCancelled:record("Product.purchase.return",["result":"userCancelled"]);return "cancelled"
            case .pending:record("Product.purchase.return",["result":"pending"]);return "pending"
            @unknown default:record("Product.purchase.return",["result":"unknown"]);return "unknown"
            }
        } catch {
            let ns=error as NSError
            record("Product.purchase.throw",["error":String(describing:error),"domain":ns.domain,"code":ns.code,"underlying":String(describing:ns.userInfo[NSUnderlyingErrorKey])])
            if case StoreKitError.userCancelled=error { return "cancelled" };return "threw"
        }
    }
    func testScenario() async throws {
        XCTAssertEqual(phase,"seed");try await prepare()
        _ = await snapshot("before-scenario")
        switch scenario {
        case "cancel":
            watchedProduct="outfit.student"
            try await session!.setSimulatedError(.generic(.userCancelled),forAPI:.purchase)
            let configured=await session!.simulatedError(forAPI:.purchase)
            record("setSimulatedError.return",["configured":String(describing:configured)])
            XCTAssertEqual(configured,.generic(.userCancelled))
            let result=await purchase(.student);let state=await snapshot("after-cancel")
            XCTAssertEqual(result,"cancelled");XCTAssertTrue(state.0.isEmpty)
        case "interrupt":
            watchedProduct="outfit.rainy";session!.interruptedPurchasesEnabled=true
            record("interruptedPurchasesEnabled.set",["value":true])
            _ = await purchase(.rainyDay);let before=await snapshot("before-resolve")
            let issue=try XCTUnwrap(session!.allTransactions().first{$0.productIdentifier==watchedProduct})
            XCTAssertTrue(issue.hasPurchaseIssue);XCTAssertTrue(before.0.isEmpty,"Unresolved issue must not already be entitled")
            session!.interruptedPurchasesEnabled=false
            record("interruptedPurchasesEnabled.set",["value":false])
            expectation=expectation(description:"Resolved interrupted purchase notification")
            waitingForResolution=true
            record("resolveIssue.begin",["id":String(issue.identifier)])
            try session!.resolveIssueForTransaction(identifier:issue.identifier);record("resolveIssue.return")
            await fulfillment(of:[expectation!],timeout:10)
            record("resolve.notification",["received":expectationDelivered])
            _ = await snapshot("after-resolve")
        case "refund":
            watchedProduct="outfit.winter"
            let result=await purchase(.winter);XCTAssertEqual(result,"purchased")
            if let wardrobe { XCTAssertTrue(wardrobe.equip(.winter)) }
            _ = await snapshot("before-refund")
            expectation=expectation(description:"Live refund notification without manual reconciliation")
            waitingForRevocation=true
            let receipt=try XCTUnwrap(session!.allTransactions().first{$0.productIdentifier==watchedProduct})
            record("refund.begin",["id":String(receipt.identifier),"product":watchedProduct])
            try session!.refundTransaction(identifier:receipt.identifier);record("refund.return")
            await fulfillment(of:[expectation!],timeout:10)
            record("refund.notification",["received":expectationDelivered])
            _ = await snapshot("after-notification-deadline-before-refresh")
            if let manager {
                record("manager.refresh.begin");let refreshed=await manager.refreshEntitlements();record("manager.refresh.return",["success":refreshed])
                XCTAssertTrue(refreshed);XCTAssertFalse(manager.owns(.winter));XCTAssertEqual(wardrobe?.equippedOutfit,.basic)
                XCTAssertFalse(wardrobe!.equip(.winter))
            }
            _ = await snapshot("after-explicit-refresh")
        case "finish":
            let first=await purchase(.astronaut);XCTAssertEqual(first,"purchased")
            _ = await snapshot("after-space-finish")
            let last=await purchase(.cafe);XCTAssertEqual(last,"purchased")
            let state=await snapshot("after-final-cafe-finish")
            let manifest:[String:Any]=["pid":ProcessInfo.processInfo.processIdentifier,"ids":state.0,"mode":mode,"run":run,"timestamp":Date().timeIntervalSince1970]
            try JSONSerialization.data(withJSONObject:manifest,options:[.sortedKeys]).write(to:manifestURL(),options:.atomic)
            record("handoff.ready",manifest)
            // Single immediate diagnostic assertion, NOT a replacement for the
            // retained original 3-second acceptance test.
            XCTAssertTrue(state.1.isEmpty,"Immediate SDK unfinished readback remains nonempty")
        default:XCTFail("Unknown scenario")
        }
    }
    func testFinishInFreshProcess() async throws {
        XCTAssertEqual(phase,"verify");XCTAssertEqual(scenario,"finish")
        let data=try Data(contentsOf:manifestURL())
        let manifest=try XCTUnwrap(try JSONSerialization.jsonObject(with:data) as? [String:Any])
        XCTAssertNotEqual((manifest["pid"] as? NSNumber)?.intValue,Int(ProcessInfo.processInfo.processIdentifier))
        let expected=try XCTUnwrap(manifest["ids"] as? [String]);XCTAssertEqual(expected.count,2)
        let state=await snapshot("fresh-process-before-session-init")
        XCTAssertEqual(Set(state.0),Set(expected),"Same verified receipts must survive; no purchase, sync or grants injected")
        XCTAssertTrue(state.1.isEmpty,"A new process still sees unfinished receipts after the previous process awaited finish")
    }
    private func configuration() -> URL {
        Bundle(for:Self.self).url(forResource:"Routimori",withExtension:"storekit") ?? URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Routimori.storekit")
    }
    private func manifestURL() throws -> URL {
        let support=try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
        let directory=support.appendingPathComponent("PioStoreKitIsolation",isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        return directory.appendingPathComponent(run+".json")
    }
}
