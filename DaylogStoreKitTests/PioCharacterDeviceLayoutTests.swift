#if DEBUG && os(iOS)
import XCTest
import SwiftUI
import UIKit
@testable import Daylog

/// Isolated real SwiftUI screens. Programmatic scrolling/orientation is not a
/// VoiceOver usability test, a purchase flow, or a production user-data session.
@MainActor final class PioCharacterDeviceLayoutTests: XCTestCase {
    private final class Host: UIHostingController<AnyView> {
        override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
    }

    private struct Fixture {
        let store: AppStore
        let preferences: DevicePreferences
        let decor: DashboardDecor
        let sync: CloudSyncMonitor
        let suite: String
        let defaults: UserDefaults
    }

    private func fixture() throws -> Fixture {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioCharacterDeviceReview"))
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
        let store = AppStore(container: try DaylogStore.makeContainer(.inMemory))
        store.start()
        let suite = "PioCharacterDeviceLayout.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        return Fixture(store: store, preferences: DevicePreferences(defaults: defaults,
            isPhone: UIDevice.current.userInterfaceIdiom == .phone),
            decor: DashboardDecor(defaults: defaults), sync: CloudSyncMonitor(containerIdentifier: nil),
            suite: suite, defaults: defaults)
    }

    private func screen(_ name: String, fixture: Fixture, large: Bool) -> AnyView {
        let content: AnyView
        switch name {
        case "home": content = AnyView(DashboardView())
        case "cloud-ready": content = AnyView(FirstSyncView(gate: FirstSyncGate(), preview: .found))
        case "cloud-trouble": content = AnyView(FirstSyncView(gate: FirstSyncGate(), preview: .stalled(nil)))
        default: content = AnyView(VacationRestView())
        }
        return AnyView(content.environment(fixture.store).environment(fixture.preferences)
            .environment(fixture.decor).environment(fixture.sync).environment(\.scenePhase, .active)
            .environment(\.colorScheme, name.hasSuffix("night") || name == "cloud-trouble" ? .dark : .light)
            .environment(\.dynamicTypeSize, large ? .accessibility5 : .large))
    }

    private func descendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(descendants)
    }

    private func waitFor(_ message: String, condition: () -> Bool) async throws {
        let deadline = CACurrentMediaTime() + 8
        repeat {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(16))
        } while CACurrentMediaTime() < deadline
        XCTFail(message)
        throw NSError(domain: "PioCharacterDeviceLayout", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func capture(_ controller: UIViewController, name: String) {
        let image = UIGraphicsImageRenderer(size: controller.view.bounds.size).image {
            _ in controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    /// Explicit live-window exposure for simctl's framebuffer screenshot. The
    /// interval is for an external camera, never an entitlement/assertion retry.
    func testLiveVacationScreensForExternalFrameBufferCapture() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioCharacterLiveScreenReview"))
        let fixture = try fixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil }
        for name in ["vacation-day", "vacation-night"] {
            let host = Host(rootView: screen(name, fixture: fixture, large: false))
            window.rootViewController = host; window.makeKeyAndVisible()
            try await waitFor("Live scene needs a displayed native host") {
                host.view.layoutIfNeeded()
                return host.view.window === window && host.view.layer.presentation() != nil
            }
            capture(host, name: "live-camera-\(name)-renderer-snapshot")
            FileHandle.standardOutput.write(Data("PIO_LIVE_FRAMEBUFFER_READY \(name)\n".utf8))
            try await Task.sleep(for: .seconds(15))
        }
    }

    func testLargeTextScreensCanScrollToTheirContentEnd() async throws {
        let fixture = try fixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil }
        var rows: [[String: Any]] = []
        for name in ["home", "cloud-ready", "cloud-trouble", "vacation-day", "vacation-night"] {
            let host = Host(rootView: screen(name, fixture: fixture, large: true))
            window.rootViewController = host; window.makeKeyAndVisible()
            try await waitFor("Native scroll content must finish initial layout") {
                host.view.layoutIfNeeded()
                return self.descendants(host.view).compactMap { $0 as? UIScrollView }
                    .contains { $0.bounds.width > 200 && $0.contentSize.height > 0 }
            }
            let scroll = try XCTUnwrap(descendants(host.view).compactMap { $0 as? UIScrollView }
                .filter { $0.bounds.width > 200 }.max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height })
            XCTAssertLessThanOrEqual(scroll.contentSize.width, scroll.bounds.width + 1,
                                     "\(name): unexpected horizontal scrolling")
            capture(host, name: "AX5-\(name)-before-scroll")
            let bottom = max(-scroll.adjustedContentInset.top,
                             scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: bottom), animated: false)
            host.view.layoutIfNeeded(); CATransaction.flush()
            XCTAssertEqual(scroll.contentOffset.y, bottom, accuracy: 1, "\(name): content end is unreachable")
            capture(host, name: "AX5-\(name)-content-end")
            rows.append(["scene": name, "viewport": [scroll.bounds.width, scroll.bounds.height],
                         "content": [scroll.contentSize.width, scroll.contentSize.height],
                         "bottomOffset": bottom, "actualOffset": scroll.contentOffset.y,
                         "method": "public UIScrollView.setContentOffset(animated:false), actual screen capture",
                         "VoiceOverOperated": false, "reduceMotionOS": UIAccessibility.isReduceMotionEnabled])
            window.rootViewController = nil
        }
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: rows,
            options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "large-text-content-end-observations"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testIPadActualPortraitLandscapeAndReturn() async throws {
        let fixture = try fixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suite) }
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "Run this method on the dedicated iPad simulator")
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; window.rootViewController = nil }
        var observations: [[String: Any]] = []
        for landscape in [false, true, false] {
            let host = Host(rootView: screen("home", fixture: fixture, large: false))
            window.rootViewController = host; window.makeKeyAndVisible()
            host.setNeedsUpdateOfSupportedInterfaceOrientations()
            var geometryError: String?
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: landscape ? .landscapeRight : .portrait)) {
                geometryError = $0.localizedDescription
            }
            // Observe the actual scene orientation before sizing this auxiliary
            // test window. Looking only at a reused hosting controller's bounds
            // could not distinguish scene geometry from fixture reuse.
            try await waitFor("iPad scene must actually change orientation") {
                scene.interfaceOrientation.isLandscape == landscape
            }
            window.frame = scene.coordinateSpace.bounds
            host.view.frame = window.bounds; host.view.layoutIfNeeded()
            XCTAssertEqual(host.view.bounds.size, window.bounds.size)
            observations.append(["landscapeRequested": landscape,
                "actualSceneOrientation": scene.interfaceOrientation.rawValue,
                "actualSceneSize": [scene.coordinateSpace.bounds.width, scene.coordinateSpace.bounds.height],
                "auxiliaryWindowSize": [window.bounds.width, window.bounds.height],
                "geometryError": geometryError ?? "none"])
            for name in ["home", "cloud-ready", "vacation-day", "vacation-night"] {
                let content = Host(rootView: screen(name, fixture: fixture, large: false))
                window.rootViewController = content; content.view.frame = window.bounds
                try await waitFor("Rotated native content must have a window") {
                    content.view.layoutIfNeeded()
                    return content.view.window === window && content.view.bounds.width > 300
                }
                XCTAssertEqual(content.view.bounds.size, window.bounds.size)
                capture(content, name: "iPad-\(landscape ? "landscape" : "portrait")-\(name)")
            }
        }
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: observations,
            options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "actual-iPad-scene-orientation-observations"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
#endif
