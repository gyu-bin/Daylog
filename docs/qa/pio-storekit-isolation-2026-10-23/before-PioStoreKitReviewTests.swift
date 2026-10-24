import XCTest
import StoreKitTest
import SwiftUI
@testable import Daylog
#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if DEBUG
/// Opt-in wardrobe playground. It never creates a purchase session or unlocks
/// transactions; the separate Debug wear permission is visible in the UI.
@MainActor
final class PioWardrobePlaygroundReviewTests: XCTestCase {
    func testInteractiveWardrobePlayground() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-pio-wardrobe-review"))
        XCTAssertTrue(PioWardrobeStore.shared.isOutfitTestingEnabled)
        XCTAssertFalse(PioWardrobeStore.shared.purchases.availability.isEnabled)
        let app = try XCTUnwrap(AppRuntime.shared?.store)
        DevicePreferences.shared.completeOnboarding()
        PioAppearanceCoordinator.shared.bindGrowthSource { [weak app] in app?.growth.level ?? 1 }
        app.section = .wardrobe
        #if os(macOS)
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows where window.styleMask.contains(.titled) {
            window.makeKeyAndOrderFront(nil)
        }
        #endif
        let stop = FileManager.default.temporaryDirectory.appendingPathComponent("routimori-wardrobe-playground.stop")
        if FileManager.default.fileExists(atPath: stop.path) { try FileManager.default.removeItem(at: stop) }
        print("PIO_WARDROBE_PLAYGROUND_READY stop=\(stop.path)")
        let until = Date().addingTimeInterval(7200)
        while Date() < until && !FileManager.default.fileExists(atPath: stop.path) {
            try await Task.sleep(for: .seconds(1))
        }
    }
}
#endif

/// Opt-in native UI review. No ownership is injected: use the wardrobe's Apple
/// purchase sheet. The host uses RuntimeEnvironment's in-memory routine store.
@MainActor
final class PioStoreKitReviewTests: XCTestCase {
    func testInteractivePurchaseReview() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-pio-storekit-review"))
        let globalReview = ProcessInfo.processInfo.arguments.contains("-pio-global-review")
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Routimori", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        // Reset explicit failure injection left by a different test scheme.
        try await session.setSimulatedError(nil, forAPI: .verification)
        try await session.setSimulatedError(nil, forAPI: .purchase)
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        if globalReview { session.clearTransactions() }
        session.locale = Locale(identifier: "ko_KR")
        session.storefront = "KOR"
        session.disableDialogs = false
        var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        arguments["DaylogDebugCharacter"] = "routimori"
        arguments["DaylogDebugSplash"] = "off"
        UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        await PioWardrobeStore.shared.start()
        await PioWardrobeStore.shared.purchases.loadProducts()
        await PioWardrobeStore.shared.refreshEntitlements()
        XCTAssertEqual(PioWardrobeStore.shared.purchases.products.count, 13)
        let startup = XCTAttachment(string: "Process: \(ProcessInfo.processInfo.processIdentifier)\nVerified owned: \(PioWardrobeStore.shared.purchases.ownedOutfits.map(\.rawValue).sorted())\nEquipped: \(PioWardrobeStore.shared.equippedOutfit.rawValue)")
        startup.name = "Review startup verified ledger and equipment"
        startup.lifetime = .keepAlways
        add(startup)
        let app = try XCTUnwrap(AppRuntime.shared?.store)
        app.section = .dashboard
        PioAppearanceCoordinator.shared.bindGrowthSource { [weak app] in app?.growth.level ?? 1 }
        #if os(macOS)
        var reviewWindow: NSWindow?
        #else
        var reviewController: UIViewController?
        #endif
        if globalReview {
            // Real local StoreKit transactions seed scene QA, never an ownership
            // boolean. This opt-in fixture is not purchase-sheet verification.
            session.disableDialogs = true
            for outfit: PioOutfitID in [.christmas, .halloween, .hanbok, .astronaut] {
                if !PioWardrobeStore.shared.purchases.owns(outfit) {
                    let result = await PioWardrobeStore.shared.purchase(outfit)
                    XCTAssertEqual(result, .purchased(outfit))
                }
            }
            await PioWardrobeStore.shared.refreshEntitlements()
            for outfit: PioOutfitID in [.christmas, .halloween, .hanbok, .astronaut] {
                XCTAssertTrue(PioWardrobeStore.shared.purchases.owns(outfit))
            }
            XCTAssertTrue(PioWardrobeStore.shared.equip(.christmas))
            arguments["DaylogDebugSplashHold"] = "routimori"
            UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            #if os(macOS)
            let window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 600, height: 900),
                                  styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = "Pio Global Appearance — Local QA"
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: PioGlobalReviewView(store: app)
                .frame(minWidth: 560, minHeight: 820))
            window.center()
            window.makeKeyAndOrderFront(nil)
            reviewWindow = window
            #else
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            var presenter = try XCTUnwrap(scene.windows.first(where: \.isKeyWindow)?.rootViewController)
            while let presented = presenter.presentedViewController { presenter = presented }
            let controller = UIHostingController(rootView: PioGlobalReviewView(store: app))
            controller.modalPresentationStyle = .fullScreen
            presenter.present(controller, animated: false)
            reviewController = controller
            #endif
        }
        #if os(macOS)
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows where window.styleMask.contains(.titled) {
            window.makeKeyAndOrderFront(nil)
        }
        #endif
        let stop = FileManager.default.temporaryDirectory.appendingPathComponent("routimori-storekit-review.done")
        if FileManager.default.fileExists(atPath: stop.path) { try FileManager.default.removeItem(at: stop) }
        print("PIO_STOREKIT_REVIEW_READY stop=\(stop.path)")
        let until = Date().addingTimeInterval(600)
        while Date() < until && !FileManager.default.fileExists(atPath: stop.path) {
            try await Task.sleep(for: .seconds(1))
        }
        let ledger = session.allTransactions().map { "\($0.productIdentifier): \($0.state.rawValue)" }.joined(separator: "\n")
        let evidence = XCTAttachment(string: ledger)
        evidence.name = "Interactive review real local ledger"
        evidence.lifetime = .keepAlways
        add(evidence)
        #if os(macOS)
        reviewWindow?.close()
        #else
        reviewController?.dismiss(animated: false)
        #endif
        // Keep local receipts for explicit relaunch/restore review; no production ledger is touched.
        withExtendedLifetime(session) {}
    }
}
