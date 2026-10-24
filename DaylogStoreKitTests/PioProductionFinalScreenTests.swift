#if DEBUG && os(iOS)
import XCTest
import SwiftUI
import UIKit
@testable import Daylog

/// Actual app views in an isolated in-memory native host. Not a purchase or sync E2E.
@MainActor final class PioProductionFinalScreenTests: XCTestCase {
    func testActualDeviceScreensAndAccessibilityLayouts() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioProductionFinalScreenReview"))
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
        XCTAssertTrue(PioCharacter.isEnabled)
        XCTAssertFalse(PioOverhaulTrial.isEnabled)
        let container = try DaylogStore.makeContainer(.inMemory)
        let store = AppStore(container: container); store.start()
        let suite = "PioProductionFinalScreens.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DevicePreferences(defaults: defaults, isPhone: UIDevice.current.userInterfaceIdiom == .phone)
        let decor = DashboardDecor(defaults: defaults)
        let sync = CloudSyncMonitor(containerIdentifier: nil)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil }
        var observations: [[String: Any]] = []
        let cases: [(String, AnyView, ColorScheme)] = [
            ("home", AnyView(DashboardView()), .light),
            ("cloud-receiving", AnyView(FirstSyncView(gate: FirstSyncGate(), preview: .waiting)), .light),
            ("cloud-ready", AnyView(FirstSyncView(gate: FirstSyncGate(), preview: .found)), .light),
            ("cloud-trouble", AnyView(FirstSyncView(gate: FirstSyncGate(), preview: .stalled(nil))), .dark),
            ("vacation-day", AnyView(VacationRestView()), .light),
            ("vacation-night", AnyView(VacationRestView()), .dark)
        ]
        for (label, view, scheme) in cases {
            for large in [false, true] {
                // A new host gives every fixture its own SwiftUI identity.
                // Replacing AnyView in one host retained the prior sync scene
                // during its opacity transition and captured stale phase/text.
                let controller = UIHostingController(rootView: AnyView(view.environment(store).environment(preferences)
                    .environment(decor).environment(sync).environment(\.scenePhase, .active)
                    .environment(\.colorScheme, scheme)
                    .environment(\.dynamicTypeSize, large ? .accessibility5 : .large)))
                controller.view.backgroundColor = .systemBackground
                window.rootViewController = controller; window.makeKeyAndVisible()
                controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
                // Await real UIKit layout/display turns, not an entitlement delay.
                for _ in 0..<3 {
                    let laidOut = expectation(description: "layout/display turn")
                    DispatchQueue.main.async { laidOut.fulfill() }
                    await fulfillment(of: [laidOut], timeout: 5)
                    controller.view.layoutIfNeeded()
                }
                if let expected = expectedKind(label) {
                    try await waitForCloudGlyph(expected, dark: scheme == .dark, controller: controller)
                }
                XCTAssertTrue(controller.view.window === window)
                XCTAssertGreaterThan(controller.view.bounds.width, 300)
                let image = UIGraphicsImageRenderer(size: controller.view.bounds.size).image {
                    _ in controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "screen-\(label)-\(large ? "AX5" : "normal")"
                attachment.lifetime = .keepAlways; add(attachment)
                observations.append(["scene": label, "largeText": large, "reduceMotionEnvironmentOverride": false,
                                     "width": controller.view.bounds.width, "height": controller.view.bounds.height,
                                     "safeArea": [controller.view.safeAreaInsets.top, controller.view.safeAreaInsets.bottom],
                                     "idiom": UIDevice.current.userInterfaceIdiom.rawValue,
                                     "scope": "actual app view, in-memory data, ordinary renderer; no forced owned outfit, real sync, purchase or OS VoiceOver operation"])
                window.rootViewController = nil
            }
        }
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: observations, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "actual-device-screen-observations"; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func expectedKind(_ label: String) -> SyncSceneKind? {
        switch label {
        case "cloud-receiving": .receiving
        case "cloud-ready": .ready
        case "cloud-trouble": .trouble
        default: nil
        }
    }

    /// The expected glyph is rendered by the same native stage API, but with
    /// the requested fixture state. Compare actual rendered bytes, not merely
    /// the fixture label or elapsed time, before accepting a screenshot.
    private func waitForCloudGlyph(_ kind: SyncSceneKind, dark: Bool,
                                   controller: UIViewController) async throws {
        let deadline = CACurrentMediaTime() + 5
        var expectedPixels: Data?
        var actualPixels: Data?
        repeat {
            controller.view.layoutIfNeeded(); CATransaction.flush()
            if let host = descendants(controller.view).compactMap({ $0 as? PioCloudSceneHost })
                .first(where: { $0.layer.sublayers?.first?.sublayers?.count == 3 }),
               let root = host.layer.sublayers?.first,
               let glyph = root.sublayers?[1],
               let contents = glyph.contents,
               CFGetTypeID(contents as CFTypeRef) == CGImage.typeID, root.bounds.height > 0 {
                let actual = contents as! CGImage
                if expectedPixels == nil {
                    let expected = RoutimoriSyncStage()
                    expected.update(.init(kind: kind, height: root.bounds.height, dark: dark,
                        scale: glyph.contentsScale, reduceMotion: true), isAnimating: false)
                    if let pixels = expected.glyph.contents,
                       CFGetTypeID(pixels as CFTypeRef) == CGImage.typeID {
                        let image = pixels as! CGImage
                        expectedPixels = image.dataProvider?.data.map { $0 as Data }
                    }
                }
                actualPixels = actual.dataProvider?.data.map { $0 as Data }
                if let expectedPixels, actualPixels == expectedPixels { return }
            }
            try await Task.sleep(for: .milliseconds(16))
        } while CACurrentMediaTime() < deadline
        XCTFail("Actual native cloud glyph did not reach requested \(kind.rawValue) state")
        throw NSError(domain: "PioProductionFinalScreenReadiness", code: 1)
    }

    private func descendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(descendants)
    }
}
#endif
