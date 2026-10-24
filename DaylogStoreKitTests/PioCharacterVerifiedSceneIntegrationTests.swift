#if DEBUG
import XCTest
import SwiftUI
import QuartzCore
import StoreKit
import StoreKitTest
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import Daylog

/// Real Xcode-verified receipts + real shared appearance/native scene components.
/// Not Product.purchase UI, wardrobe navigation, CloudKit, or Apple Sandbox E2E.
@MainActor final class PioCharacterVerifiedSceneIntegrationTests: XCTestCase {
    private var session: SKTestSession?
    private var defaultsBefore: [String: Any]?
    private var isolatedDefaults: UserDefaults?
    private var managers: [PioPurchaseManager] = []
    private var mayRestore = false

    override func setUp() async throws {
        let process = ProcessInfo.processInfo
        try XCTSkipUnless(process.arguments.contains("-PioCharacterVerifiedScenes") && process.arguments.contains("-pio-storekit-testing"))
        guard RuntimeEnvironment.isRunningTests,
              process.environment["PIO_CHARACTER_ISOLATED_TEST_HOST"] == "YES" else {
            throw NSError(domain: "PioCharacterQA.unsafeHost", code: 1)
        }
        #if os(macOS)
        guard Bundle.main.bundleIdentifier == "com.daylog.verify" else { throw NSError(domain: "PioCharacterQA.unsafeMacBundle", code: 2) }
        #else
        #if !targetEnvironment(simulator)
        throw NSError(domain: "PioCharacterQA.requiresSimulator", code: 3)
        #endif
        #endif
        guard !process.arguments.contains("-pio-wardrobe-testing"), !PioOverhaulTrial.isEnabled else {
            throw NSError(domain: "PioCharacterQA.forcedPreviewMode", code: 4)
        }
        guard PioPurchaseManager.shared.availability == .localTesting else { throw PioStoreClientError.wrongEnvironment }
        let url = Bundle(for: Self.self).url(forResource: "Routimori", withExtension: "storekit")
            ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Routimori.storekit")
        let local = try SKTestSession(contentsOf: url)
        guard case .verified(let app) = try await AppTransaction.shared, app.environment == .xcode else { throw PioStoreClientError.wrongEnvironment }
        // No reset, equip or preference write is allowed before the verified
        // environment and explicit isolated test host guards above succeed.
        session = local
        await PioPurchaseManager.shared.stop()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: PioWardrobeStore.localTestingPreferencesSuite))
        defaultsBefore = defaults.persistentDomain(forName: PioWardrobeStore.localTestingPreferencesSuite)
        isolatedDefaults = defaults; mayRestore = true
        // XCTest deliberately disables the normal selection-file singleton.
        XCTAssertNil(PioWardrobeSelectionFile.current(for: .localTesting, outfitTesting: false))
        local.resetToDefaultState(); local.clearTransactions(); local.disableDialogs = true
        local.askToBuyEnabled = false; local.interruptedPurchasesEnabled = false
        try await local.setSimulatedError(nil, forAPI: .verification)
        try await local.setSimulatedError(nil, forAPI: .purchase)
        try await local.setSimulatedError(nil, forAPI: .loadProducts)
        local.storefront = "KOR"; local.locale = Locale(identifier: "ko_KR")
        XCTAssertFalse(PioWardrobeStore.shared.isOutfitTestingEnabled)
        XCTAssertTrue(PioWardrobeStore.shared.equip(.basic))
        let refreshed = await PioPurchaseManager.shared.refreshEntitlements()
        XCTAssertTrue(refreshed)
        XCTAssertEqual(PioPurchaseManager.shared.ownedOutfits, [.basic])
    }

    override func tearDown() async throws {
        for manager in managers { await manager.stop() }
        managers.removeAll()
        if mayRestore {
            await PioPurchaseManager.shared.stop()
            session?.clearTransactions(); session?.resetToDefaultState()
            if let defaultsBefore {
                isolatedDefaults?.setPersistentDomain(defaultsBefore, forName: PioWardrobeStore.localTestingPreferencesSuite)
            } else { isolatedDefaults?.removePersistentDomain(forName: PioWardrobeStore.localTestingPreferencesSuite) }
        }
        session = nil; isolatedDefaults = nil; defaultsBefore = nil; mayRestore = false
    }

    func testVerifiedSharedFourteenOutfitsAcrossFiftySixNativeScenes() async throws {
        let store = Daylog.AppStore(container: try DaylogStore.makeContainer(.inMemory)); store.start()
        var rows: [[String: Any]] = []
        var rendered = 0
        defer { attachJSON(rows, name: "verified-shared-56-scenes") }
        for outfit in PioOutfitID.allCases {
            do {
                let receipt = outfit == .basic ? nil : try await seedVerified(outfit)
                let manager = PioPurchaseManager.shared
                let refreshed = await manager.refreshEntitlements()
                XCTAssertTrue(refreshed)
                guard manager.owns(outfit), PioWardrobeStore.shared.equip(outfit) else {
                    XCTFail("Verified local wardrobe could not equip \(outfit.rawValue)")
                    rows.append(["outfit":outfit.rawValue,"result":"FAIL","stage":"verified-entitlement/equip","nativeRendered":false]); continue
                }
                for context in [PioAppearanceContext.dashboard, .cloudDownloading, .vacationDay, .vacationNight] {
                    let resolved = PioAppearanceCoordinator.shared.resolve(context: context)
                    XCTAssertEqual(resolved.outfit, outfit)
                    XCTAssertEqual(resolved.requestedOutfit, outfit)
                    XCTAssertEqual(resolved.access, outfit == .basic ? .free : .verified)
                    XCTAssertFalse(resolved.isAwaitingVerification)
                    XCTAssertFalse(resolved.isPreview)
                    XCTAssertTrue(resolved.outfitApplied)
                    let content = scene(context, store: store)
                    let native = try SceneHost(content: content, phase: .active)
                    defer { native.close() }
                    try await waitUntil("actual shared scene is visible and animating") {
                        native.layout(); CATransaction.flush()
                        return native.visible && native.characterTracks > 0
                    }
                    let activeTracks = native.characterTracks
                    native.capture(name: "verified-\(outfit.rawValue)-\(context.rawValue)-active", test: self)
                    native.update(content: content, phase: .inactive)
                    try await waitUntil("inactive shared scene has stopped native tracks") {
                        native.layout(); CATransaction.flush(); return native.characterTracks == 0
                    }
                    XCTAssertEqual(native.characterTracks, 0)
                    native.update(content: content, phase: .active)
                    try await waitUntil("scene resumes without losing verified outfit") {
                        native.layout(); CATransaction.flush(); return native.characterTracks > 0
                    }
                    XCTAssertEqual(PioAppearanceCoordinator.shared.resolve(context: context).outfit, outfit)
                    rendered += 1
                    rows.append(["outfit":outfit.rawValue,"context":context.rawValue,"result":"PASS",
                        "access":resolved.access.rawValue,"asset":resolved.artwork.assetName ?? "missing",
                        "verifiedTransactionID":receipt.map { String($0.id) } ?? "free-basic",
                        "environment":"Xcode","activeTracks":activeTracks,"inactiveTracks":0,
                        "scope":"actual shared native scene component; scenePhase injection, not OS background or full navigation E2E"])
                }
            } catch {
                XCTFail("\(outfit.rawValue) local verified integration failed: \(error)")
                rows.append(["outfit":outfit.rawValue,"result":"FAIL","error":String(describing:error),"nativeRendered":false])
            }
        }
        XCTAssertEqual(rendered, 56, "Missing verified receipts must not be replaced with preview entitlements")
    }

    func testGenuineSavedSelectionRemainsHiddenUntilFreshManagerVerifies() async throws {
        _ = try await seedVerified(.cafe)
        let suite = "PioCharacterVerifiedReload.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(suite + ".json")
        let selection = PioWardrobeSelectionFile(url: url)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: url) }
        let first = PioPurchaseManager(availability: .localTesting); managers.append(first)
        let wardrobe = PioWardrobeStore(defaults: defaults, purchases: first, selectionPersistence: selection)
        XCTAssertFalse(wardrobe.equip(.cafe))
        let firstRefresh = await first.refreshEntitlements(); XCTAssertTrue(firstRefresh)
        XCTAssertTrue(wardrobe.equip(.cafe)); XCTAssertEqual(selection.load(), .cafe)
        await first.stop()
        let fresh = PioPurchaseManager(availability: .localTesting); managers.append(fresh)
        let reopened = PioWardrobeStore(defaults: defaults, purchases: fresh, selectionPersistence: selection)
        let coordinator = PioAppearanceCoordinator(wardrobe: reopened)
        XCTAssertEqual(fresh.ownedOutfits, [.basic])
        XCTAssertEqual(reopened.equippedOutfit, .basic)
        let contexts: [PioAppearanceContext] = [.dashboard, .cloudDownloading, .vacationDay, .vacationNight]
        for context in contexts {
            let pending = coordinator.resolve(context: context)
            XCTAssertEqual(pending.requestedOutfit, .cafe); XCTAssertEqual(pending.access, .checking)
            XCTAssertTrue(pending.isAwaitingVerification)
            if context == .vacationDay || context == .vacationNight {
                XCTAssertFalse(PioVacationSceneResources.shouldShowCharacter(access: pending.access))
            }
        }
        let refreshed = await fresh.refreshEntitlements(); XCTAssertTrue(refreshed)
        XCTAssertEqual(reopened.equippedOutfit, .cafe)
        for context in contexts {
            let restored = coordinator.resolve(context: context)
            XCTAssertEqual(restored.outfit, .cafe); XCTAssertEqual(restored.access, .verified)
            XCTAssertFalse(restored.isAwaitingVerification)
        }
        attachJSON([["scope":"fresh managers in same process; actual UUID selection file and verified Xcode ledger; NOT fresh OS process",
                     "selected":"cafe","pendingAccess":"checking","afterVerification":"verified"]], name: "verified-selection-reconstruction")
    }

    private func seedVerified(_ outfit: PioOutfitID) async throws -> StoreKit.Transaction {
        let local = try XCTUnwrap(session)
        let product = try XCTUnwrap(PioProductRegistry.productID(for: outfit))
        let seeded = try await local.buyProduct(identifier: product)
        guard seeded.environment == .xcode else { throw PioStoreClientError.wrongEnvironment }
        var matching: StoreKit.Transaction?
        var observed: [[String: Any]] = []
        for await result in StoreKit.Transaction.currentEntitlements {
            switch result {
            case .verified(let receipt):
                observed.append(["productID":receipt.productID,"id":String(receipt.id),"verified":true,"environment":String(describing:receipt.environment)])
                if receipt.productID == product, receipt.id == seeded.id, receipt.environment == .xcode, receipt.revocationDate == nil { matching = receipt }
            case .unverified(let payload, _):
                observed.append(["productID":payload.productID,"id":String(payload.id),"verified":false])
            }
        }
        attachJSON([["scope":"SKTestSession.buyProduct; NOT Product.purchase or Sandbox", "productID":product,"seedID":String(seeded.id),"currentEntitlements":observed]], name: "receipt-\(outfit.rawValue)")
        return try XCTUnwrap(matching, "Missing verified currentEntitlements receipt for \(product); no ownership fallback permitted")
    }

    private func scene(_ context: PioAppearanceContext, store: Daylog.AppStore) -> AnyView {
        let view: AnyView
        switch context {
        case .dashboard: view = AnyView(PioHeaderCompanion(size: 220, artworkScale: 1))
        case .cloudDownloading: view = AnyView(RoutimoriSyncScene(kind: .receiving, height: 300))
        default: view = AnyView(RoutimoriVacationScene(slot: CGRect(x: 20,y: 110,width: 300,height: 210)))
        }
        return AnyView(view.environment(store).environment(\.colorScheme, context == .vacationNight ? .dark : .light)
            .frame(width: 340,height: 380).background(context == .vacationNight ? Color.black : Color.white))
    }
    private func waitUntil(_ name: String, condition: @escaping @MainActor () -> Bool) async throws {
        let predicate = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in MainActor.assumeIsolated { condition() } }, object: nil)
        await fulfillment(of: [predicate], timeout: 5)
        guard condition() else { throw NSError(domain: "PioCharacterQA.\(name)", code: 1) }
    }
    private func attachJSON(_ rows: [[String: Any]], name: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted,.sortedKeys]) else { return XCTFail("JSON evidence encoding failed") }
        let a = XCTAttachment(data: data, uniformTypeIdentifier: "public.json"); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    @MainActor private final class SceneHost {
        #if os(macOS)
        let window: NSWindow
        let native: NSHostingView<AnyView>
        var visible: Bool { window.isVisible && window.occlusionState.contains(.visible) && !native.visibleRect.isEmpty }
        init(content: AnyView, phase: ScenePhase) throws {
            native = NSHostingView(rootView: AnyView(content.environment(\.scenePhase, phase)))
            native.frame = CGRect(x:0,y:0,width:340,height:380); native.wantsLayer = true
            window = NSWindow(contentRect:native.frame,styleMask:[.titled],backing:.buffered,defer:false)
            window.isReleasedWhenClosed = false; window.contentView = native; window.orderFrontRegardless()
        }
        func layout() { native.layoutSubtreeIfNeeded() }
        func update(content: AnyView, phase: ScenePhase) { native.rootView = AnyView(content.environment(\.scenePhase,phase)) }
        func close() { window.orderOut(nil); window.contentView = nil; window.close() }
        func capture(name: String, test: XCTestCase) {
            guard let bitmap = native.bitmapImageRepForCachingDisplay(in:native.bounds) else { return XCTFail("Unable to snapshot native shared scene") }
            native.cacheDisplay(in:native.bounds,to:bitmap)
            let image = NSImage(size:native.bounds.size); image.addRepresentation(bitmap)
            let a = XCTAttachment(image:image); a.name=name; a.lifetime = .keepAlways; test.add(a)
        }
        private func roots(_ view: NSView) -> [CALayer] {
            let name=String(describing:type(of:view))
            if name.contains("PioHome") || name.contains("PioOutfitMotion") || name.contains("RoutimoriVacationNative") || view is PioCloudSceneHost { return view.layer.map { [$0] } ?? [] }
            return view.subviews.flatMap(roots)
        }
        #else
        let window: UIWindow
        let controller: UIHostingController<AnyView>
        weak var previousKey: UIWindow?
        var visible: Bool { !window.isHidden && controller.view.window === window }
        init(content: AnyView, phase: ScenePhase) throws {
            let scene=try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.first{$0.activationState == .foregroundActive})
            previousKey=scene.windows.first{$0.isKeyWindow}; window=UIWindow(windowScene:scene)
            controller=UIHostingController(rootView:AnyView(content.environment(\.scenePhase,phase)))
            window.rootViewController=controller; window.makeKeyAndVisible()
        }
        func layout() { controller.view.layoutIfNeeded() }
        func update(content: AnyView, phase: ScenePhase) { controller.rootView=AnyView(content.environment(\.scenePhase,phase)) }
        func close() { window.isHidden=true; window.rootViewController=nil; previousKey?.makeKey() }
        func capture(name:String,test:XCTestCase) {
            let view=controller.view!
            let image=UIGraphicsImageRenderer(size:view.bounds.size).image{_ in view.drawHierarchy(in:view.bounds,afterScreenUpdates:true)}
            let a=XCTAttachment(image:image);a.name=name;a.lifetime = .keepAlways;test.add(a)
        }
        private func roots(_ view:UIView)->[CALayer] {
            let name=String(describing:type(of:view))
            if name.contains("PioHome") || name.contains("PioOutfitMotion") || name.contains("RoutimoriVacationNative") || view is PioCloudSceneHost { return [view.layer] }
            return view.subviews.flatMap(roots)
        }
        #endif
        var characterTracks: Int {
            #if os(macOS)
            roots(native).reduce(0){$0+tracks($1)}
            #else
            roots(controller.view).reduce(0){$0+tracks($1)}
            #endif
        }
        private func tracks(_ layer:CALayer)->Int { (layer.animationKeys()?.count ?? 0)+(layer.sublayers ?? []).reduce(0){$0+tracks($1)} }
    }
}
#endif
