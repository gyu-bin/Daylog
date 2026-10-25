#if os(macOS)
import XCTest
import AppKit
import SwiftUI
import QuartzCore
@testable import Daylog

/// Actual native app views in an isolated window and in-memory store.
/// No production preference, wardrobe selection, or CloudKit container is used.
@MainActor final class PioCharacterMacScreenTests: XCTestCase {
    func testOrdinaryMacScreensAtTwoActualWindowSizes() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioCharacterMacScreenReview"))
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
        let store = AppStore(container: try DaylogStore.makeContainer(.inMemory)); store.start()
        let suite = "PioCharacterMacScreens.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DevicePreferences(defaults: defaults, isPhone: false)
        let decor = DashboardDecor(defaults: defaults), sync = CloudSyncMonitor(containerIdentifier: nil)
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.orderOut(nil); window.contentView = nil; window.close() }
        let cases: [(String, AnyView, ColorScheme)] = [
            ("home", AnyView(DashboardView()), .light),
            ("cloud-receiving", AnyView(FirstSyncView(gate: FirstSyncGate(), preview: .waiting)), .light),
            ("cloud-ready", AnyView(FirstSyncView(gate: FirstSyncGate(), preview: .found)), .light),
            ("cloud-trouble", AnyView(FirstSyncView(gate: FirstSyncGate(), preview: .stalled(nil))), .dark),
            ("vacation-day", AnyView(VacationRestView()), .light),
            ("vacation-night", AnyView(VacationRestView()), .dark)]
        for size in [CGSize(width: 900, height: 650), CGSize(width: 560, height: 600)] {
            window.setContentSize(size)
            for (name, view, scheme) in cases {
                let host = NSHostingView(rootView: view.background(Theme.windowBackground)
                    .environment(store).environment(preferences)
                    .environment(decor).environment(sync).environment(\.scenePhase, .active)
                    .environment(\.colorScheme, scheme))
                host.wantsLayer = true
                window.contentView = host
                window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                window.orderFrontRegardless()
                let deadline = CACurrentMediaTime() + 8
                while (!window.occlusionState.contains(.visible) || host.bounds.width < size.width - 1)
                    && CACurrentMediaTime() < deadline {
                    try await Task.sleep(for: .milliseconds(16))
                }
                for _ in 0..<3 {
                    let next = expectation(description: "native display/layout turn")
                    DispatchQueue.main.async { next.fulfill() }
                    await fulfillment(of: [next], timeout: 5)
                    host.layoutSubtreeIfNeeded()
                }
                XCTAssertTrue(window.isVisible && window.occlusionState.contains(.visible))
                XCTAssertEqual(host.bounds.width, size.width, accuracy: 1)
                let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: rep)
                let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
                let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
                attachment.name = "mac-app-\(Int(size.width))x\(Int(size.height))-\(name)"
                attachment.lifetime = .keepAlways; add(attachment)
            }
        }
    }
}
#endif
