import XCTest
import StoreKit
import StoreKitTest
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
        XCTAssertNil(defaults.object(forKey:PioWardrobeStore.equippedKey))
        let selection = try selectionFile()
        XCTAssertNil(selection.load(), "A fresh run must not import a pre-seeded selection")
        let manager=PioPurchaseManager(availability:.localTesting)
        let wardrobe=PioWardrobeStore(defaults:defaults,purchases:manager,selectionPersistence:selection)
        XCTAssertTrue(wardrobe.equip(.basic))
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
        let product=try XCTUnwrap(PioProductRegistry.productID(for:.cafe))
        guard case .verified(let transaction)=await Transaction.latest(for:product) else { return XCTFail("Verified cafe transaction required") }
        XCTAssertEqual(transaction.environment,.xcode);XCTAssertNil(transaction.revocationDate)
        let pid=Int(ProcessInfo.processInfo.processIdentifier)
        // Expected receipt identity belongs to the test harness, not the user's
        // preference domain. No wardrobe value/ownership is imported from it.
        let manifest:[String:Any]=["phase":"seed","suite":suite,"pid":pid,"productID":product,"transactionID":String(transaction.id),"environment":"Xcode","seedMethod":method,"seedTime":Date().timeIntervalSince1970]
        let manifestURL=try diagnosticManifestURL()
        try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:manifestURL,options:.atomic)
        await manager.stop()
        // Exercise rapid selection changes, then exit without any sleep, direct
        // preference-file observation, synchronize call or custom flush. Apple
        // documents UserDefaults' backing files as asynchronous implementation
        // details. The next OS process asserts the real persisted selection.
        XCTAssertTrue(wardrobe.equip(.cafe))
        XCTAssertTrue(wardrobe.equip(.basic))
        XCTAssertTrue(wardrobe.equip(.cafe))
        XCTAssertEqual(defaults.string(forKey:PioWardrobeStore.equippedKey),"cafe")
        XCTAssertEqual(selection.load(),.cafe)
        #if DEBUG
        assertEquippedSceneConsistency(wardrobe, expected: .cafe)
        #endif
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
            if let selection=try? selectionFile() { try? FileManager.default.removeItem(at:selection.url) }
        }
        let manifestURL=try diagnosticManifestURL()
        let manifestData=try? Data(contentsOf:manifestURL)
        let manifest=(manifestData.flatMap { try? JSONSerialization.jsonObject(with:$0) }) as? [String:Any]
        evidence(["phase":"verify-before-ledger","storage":storageEvidence(suite,defaults:defaults),"diagnosticManifestExists":manifest != nil,"seedManifest":manifest ?? [:]])
        let seedPID=try XCTUnwrap((manifest?["pid"] as? NSNumber)?.intValue)
        XCTAssertGreaterThan(seedPID,0)
        XCTAssertNotEqual(seedPID,Int(ProcessInfo.processInfo.processIdentifier),"Must prove a fresh OS process")
        let product=PioProductRegistry.productID(for:.cafe)!
        XCTAssertEqual(manifest?["productID"] as? String,product)
        let previousID=manifest?["transactionID"] as? String
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
        let selection=try selectionFile()
        XCTAssertEqual(selection.load(),.cafe,"Last acknowledged equip must survive immediate process exit")
        let manager=PioPurchaseManager(availability:.localTesting)
        let wardrobe=PioWardrobeStore(defaults:defaults,purchases:manager,selectionPersistence:selection)
        XCTAssertEqual(manager.ownedOutfits,[.basic],"Fresh manager cannot begin with a cached ownership grant")
        XCTAssertEqual(wardrobe.equippedOutfit,.basic,"A saved paid preference must remain locked before verification")
        await manager.start()
        XCTAssertTrue(manager.owns(.cafe))
        XCTAssertEqual(wardrobe.equippedOutfit,.cafe)
        XCTAssertEqual(wardrobe.preferredAppearanceOutfit,.cafe)
        XCTAssertEqual(selection.load(),.cafe)
        #if DEBUG
        assertEquippedSceneConsistency(wardrobe, expected: .cafe)
        #endif
        await manager.stop()
        evidence(["phase":"verify","suite":suite,"seedPID":seedPID,"pid":ProcessInfo.processInfo.processIdentifier,"verifiedTransactionID":verifiedID ?? "missing","expectedTransactionID":previousID ?? "missing","ownedCafe":manager.owns(.cafe),"equipped":wardrobe.equippedOutfit.rawValue,"secondsSinceSeed":Date().timeIntervalSince1970-(manifest?["seedTime"] as? Double ?? 0),"cleanup":"local ledger and UUID preference domain after checks","seedMethod":manifest?["seedMethod"] as? String ?? "missing","scope":"fresh OS process, same verified receipt, persisted actual wardrobe selection; no ownership or preference injection"])
    }
    private func diagnosticManifestURL() throws -> URL {
        let run=try XCTUnwrap(ProcessInfo.processInfo.environment["PIO_RELAUNCH_RUN_ID"])
        let support=try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
        let folder=support.appendingPathComponent("PioStoreKitProcessRelaunch",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        return folder.appendingPathComponent(run+".json")
    }
    private func selectionFile() throws -> PioWardrobeSelectionFile {
        let manifest=try diagnosticManifestURL()
        return PioWardrobeSelectionFile(url:manifest.deletingPathExtension().appendingPathExtension("selection.json"))
    }
    private func storageEvidence(_ suite:String,defaults:UserDefaults) -> [String:Any] {
        let home=NSHomeDirectory()
        return ["home":home,"bundleID":Bundle.main.bundleIdentifier ?? "missing","bundlePath":Bundle.main.bundlePath,
                "applicationSupport":FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first?.path ?? "missing",
                "suite":suite,"persistentDomain":defaults.persistentDomain(forName:suite) ?? [:],
                "freshDefaultsDomain":UserDefaults(suiteName:suite)?.persistentDomain(forName:suite) ?? [:]]
    }
    private func evidence(_ value: [String:Any]) {
        let data=try! JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys])
        let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json");attachment.name="Cross-process verified StoreKit ledger";attachment.lifetime = .keepAlways;add(attachment)
        print("PIO_PROCESS_RELAUNCH \(String(decoding:data,as:UTF8.self))")
    }
}
