import XCTest
import StoreKit
import StoreKitTest
import CoreFoundation
@testable import Daylog

/// Two separate test-without-building invocations are required. No normal test
/// scheme supplies both this opt-in argument and a valid UUID/phase environment.
@MainActor final class PioStoreKitProcessRelaunchTests: XCTestCase {
    private func context(phase: String) throws -> (String, UserDefaults, SKTestSession) {
        let process=ProcessInfo.processInfo
        try XCTSkipUnless(process.arguments.contains("-pio-storekit-process-relaunch") && process.arguments.contains("-pio-storekit-testing"))
        guard process.environment["PIO_RELAUNCH_PHASE"] == phase else { throw NSError(domain:"PioRelaunch.missingPhase",code:2) }
        let run=try XCTUnwrap(process.environment["PIO_RELAUNCH_RUN_ID"])
        XCTAssertNotNil(UUID(uuidString:run))
        guard UUID(uuidString:run) != nil else { throw NSError(domain:"PioRelaunch.invalidRunID",code:1) }
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
        let suite="PioStoreKitProcessRelaunchTests.\(run)"
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
        let url=Bundle(for:Self.self).url(forResource:"Routimori",withExtension:"storekit")
            ?? URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Routimori.storekit")
        let session=try SKTestSession(contentsOf:url)
        // Identity/environment is checked before any purchase or reset. Never
        // transform this local fixture into an Apple Sandbox or App Store test.
        return (suite,defaults,session)
    }
    private func requireXcode() async throws {
        guard case .verified(let app)=try await AppTransaction.shared else { throw PioStoreClientError.wrongEnvironment }
        XCTAssertEqual(app.environment,.xcode)
        guard app.environment == .xcode else { throw PioStoreClientError.wrongEnvironment }
    }
    func testSeedVerifiedLedgerInFirstProcess() async throws {
        let (suite,defaults,session)=try context(phase:"seed")
        try await requireXcode()
        session.resetToDefaultState();session.clearTransactions();session.disableDialogs=true
        session.askToBuyEnabled=false;session.interruptedPurchasesEnabled=false
        try await session.setSimulatedError(nil,forAPI:.verification)
        try await session.setSimulatedError(nil,forAPI:.purchase)
        try await session.setSimulatedError(nil,forAPI:.loadProducts)
        session.storefront="KOR";session.locale=Locale(identifier:"ko_KR")
        // The run ID is fresh. Removing an already-empty domain is unnecessary
        // and can obscure diagnostics about asynchronous preference flushing.
        XCTAssertNil(defaults.object(forKey:"seedPID"))
        let manager=PioPurchaseManager(availability:.localTesting)
        let wardrobe=PioWardrobeStore(defaults:defaults,purchases:manager)
        await manager.start()
        let method=try XCTUnwrap(ProcessInfo.processInfo.environment["PIO_RELAUNCH_SEED_METHOD"])
        if method == "storekit-test" {
            // Explicit test-driver setup; never reported as app purchase/UI proof.
            let product=try XCTUnwrap(PioProductRegistry.productID(for:.cafe))
            let seeded=try await session.buyProduct(identifier:product)
            XCTAssertEqual(seeded.environment,.xcode)
            guard seeded.environment == .xcode else { throw PioStoreClientError.wrongEnvironment }
            let refreshed=await manager.refreshEntitlements();XCTAssertTrue(refreshed)
            XCTAssertTrue(manager.owns(.cafe))
        } else if method == "product-purchase" {
            let purchased=await manager.purchase(.cafe)
            XCTAssertEqual(purchased,.purchased(.cafe))
        } else { throw NSError(domain:"PioRelaunch.invalidSeedMethod",code:3) }
        defaults.set(method,forKey:"seedMethod")
        XCTAssertTrue(wardrobe.equip(.cafe))
        let product=try XCTUnwrap(PioProductRegistry.productID(for:.cafe))
        guard case .verified(let transaction)=await Transaction.latest(for:product) else { return XCTFail("Verified cafe transaction required") }
        XCTAssertEqual(transaction.environment,.xcode);XCTAssertNil(transaction.revocationDate)
        defaults.set(ProcessInfo.processInfo.processIdentifier,forKey:"seedPID")
        defaults.set(String(transaction.id),forKey:"seedTransactionID")
        defaults.set(product,forKey:"seedProductID")
        let nsFlushed=defaults.synchronize()
        XCTAssertTrue(nsFlushed)
        // Test-only bounded diagnosis of the Foundation/CFPreferences flush
        // discrepancy. Never write the plist externally or rehydrate a cached
        // ownership/equipment dictionary to manufacture persistence.
        let cfAppFlushed=CFPreferencesAppSynchronize(suite as CFString)
        let cfScopeFlushed=CFPreferencesSynchronize(suite as CFString,kCFPreferencesCurrentUser,kCFPreferencesAnyHost)
        let pid=Int(ProcessInfo.processInfo.processIdentifier)
        for _ in 0..<100 {
            if (preferenceDiskDomain(suite)["seedPID"] as? NSNumber)?.intValue == pid { break }
            try await Task.sleep(for:.milliseconds(50))
        }
        let disk=preferenceDiskDomain(suite)
        XCTAssertEqual((disk["seedPID"] as? NSNumber)?.intValue,pid,"Fixture must prove its seed metadata reached disk before ending the process")
        XCTAssertEqual(defaults.persistentDomain(forName:suite)?["seedProductID"] as? String,product)
        var manifest:[String:Any]=["phase":"seed","suite":suite,"pid":pid,"productID":product,"transactionID":String(transaction.id),"environment":"Xcode","equipped":wardrobe.equippedOutfit.rawValue,"seedMethod":method,"appPurchaseUI":method == "storekit-test" ? "NOT_TESTED" : "Product.purchase result asserted"]
        manifest["storage"]=storageEvidence(suite,defaults:defaults)
        manifest["flushDiagnostics"]=["UserDefaultsSynchronize":nsFlushed,"CFPreferencesAppSynchronize":cfAppFlushed,"CFPreferencesScopedSynchronize":cfScopeFlushed,"maximumDiskWaitSeconds":5]
        // Diagnostic metadata is not an ownership cache and is never imported
        // into the manager or preference suite in the verification process.
        let manifestURL=try diagnosticManifestURL()
        try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:manifestURL,options:.atomic)
        evidence(manifest)
        // Intentionally retain Apple's local ledger and this UUID preference
        // domain. No ownership list is persisted or injected by this fixture.
    }
    func testVerifyLedgerAndEquipmentInFreshProcess() async throws {
        let (suite,defaults,session)=try context(phase:"verify")
        try await requireXcode()
        // Do not reset, repurchase or restore before checking the previous ledger.
        defer {
            session.clearTransactions();session.resetToDefaultState();defaults.removePersistentDomain(forName:suite)
            if let url=try? diagnosticManifestURL() { try? FileManager.default.removeItem(at:url) }
        }
        let manifestURL=try diagnosticManifestURL()
        let manifestData=try? Data(contentsOf:manifestURL)
        let manifest=(manifestData.flatMap { try? JSONSerialization.jsonObject(with:$0) }) as? [String:Any]
        evidence(["phase":"verify-before-ledger","storage":storageEvidence(suite,defaults:defaults),"diagnosticManifestExists":manifest != nil,"seedManifest":manifest ?? [:]])
        let storedPID=defaults.integer(forKey:"seedPID")
        let seedPID=(manifest?["pid"] as? NSNumber)?.intValue ?? storedPID
        XCTAssertGreaterThan(seedPID,0)
        XCTAssertEqual(storedPID,seedPID,"The UUID preference domain must persist across processes independently of diagnostic metadata")
        XCTAssertNotEqual(seedPID,Int(ProcessInfo.processInfo.processIdentifier),"Must prove a fresh OS process")
        let product=PioProductRegistry.productID(for:.cafe)!
        XCTAssertEqual(defaults.string(forKey:"seedProductID"),product)
        let previousID=manifest?["transactionID"] as? String ?? defaults.string(forKey:"seedTransactionID")
        XCTAssertNotNil(previousID,"The first process must provide transaction identity evidence")
        var verifiedID:String?
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction)=result, transaction.productID == product {
                XCTAssertEqual(transaction.environment,.xcode);XCTAssertNil(transaction.revocationDate)
                verifiedID=String(transaction.id)
            }
        }
        XCTAssertNotNil(verifiedID,"Fresh process must find a verified cafe receipt independently of preference metadata")
        XCTAssertEqual(verifiedID,previousID,"Apple's local ledger must survive process relaunch")
        let manager=PioPurchaseManager(availability:.localTesting)
        let wardrobe=PioWardrobeStore(defaults:defaults,purchases:manager)
        XCTAssertEqual(manager.ownedOutfits,[.basic],"Fresh manager cannot begin with a cached ownership grant")
        await manager.start()
        XCTAssertTrue(manager.owns(.cafe))
        XCTAssertEqual(wardrobe.equippedOutfit,.cafe)
        XCTAssertEqual(defaults.string(forKey:PioWardrobeStore.equippedKey),"cafe")
        evidence(["phase":"verify","suite":suite,"seedPID":seedPID,"pid":ProcessInfo.processInfo.processIdentifier,"verifiedTransactionID":verifiedID ?? "missing","expectedTransactionID":previousID ?? "missing","ownedCafe":manager.owns(.cafe),"equipped":wardrobe.equippedOutfit.rawValue,"cleanup":"local ledger and UUID preference domain after checks","seedMethod":defaults.string(forKey:"seedMethod") ?? "missing","scope":"verified ledger and equipment persistence only; test-driven seed does not certify app purchase UI"])
    }
    private func preferenceURL(_ suite:String) -> URL {
        URL(fileURLWithPath:NSHomeDirectory()).appendingPathComponent("Library/Preferences").appendingPathComponent(suite+".plist")
    }
    private func preferenceDiskDomain(_ suite:String) -> [String:Any] {
        guard let data=try? Data(contentsOf:preferenceURL(suite)),
              let value=try? PropertyListSerialization.propertyList(from:data,options:[],format:nil) as? [String:Any] else { return [:] }
        return value
    }
    private func diagnosticManifestURL() throws -> URL {
        let run=try XCTUnwrap(ProcessInfo.processInfo.environment["PIO_RELAUNCH_RUN_ID"])
        let support=try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
        let folder=support.appendingPathComponent("PioStoreKitProcessRelaunch",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        return folder.appendingPathComponent(run+".json")
    }
    private func storageEvidence(_ suite:String,defaults:UserDefaults) -> [String:Any] {
        let home=NSHomeDirectory(),prefs=preferenceURL(suite)
        return ["home":home,"bundleID":Bundle.main.bundleIdentifier ?? "missing","bundlePath":Bundle.main.bundlePath,
                "applicationSupport":FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first?.path ?? "missing",
                "suite":suite,"preferencePath":prefs.path,"preferenceFileExists":FileManager.default.fileExists(atPath:prefs.path),
                "persistentDomain":defaults.persistentDomain(forName:suite) ?? [:],"diskDomain":preferenceDiskDomain(suite),
                "cfPreferencesDomain":CFPreferencesCopyMultiple(nil,suite as CFString,kCFPreferencesCurrentUser,kCFPreferencesAnyHost) as? [String:Any] ?? [:],
                "freshDefaultsDomain":UserDefaults(suiteName:suite)?.persistentDomain(forName:suite) ?? [:]]
    }
    private func evidence(_ value: [String:Any]) {
        let data=try! JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys])
        let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json");attachment.name="Cross-process verified StoreKit ledger";attachment.lifetime = .keepAlways;add(attachment)
        print("PIO_PROCESS_RELAUNCH \(String(decoding:data,as:UTF8.self))")
    }
}
