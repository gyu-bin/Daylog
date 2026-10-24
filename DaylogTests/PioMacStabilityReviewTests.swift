#if DEBUG && os(macOS)
import XCTest
import AppKit
import QuartzCore
import Darwin
@testable import Daylog

/// Explicitly selected, isolated native host. No app data, StoreKit session, or
/// normal user window is used. Measurements never treat an occluded host as visible.
@MainActor final class PioMacStabilityReviewTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioMacStabilityReview"))
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
    }

    func testActualWindowVisibilityTransitions() async throws {
        let host = PioCloudSceneHost(frame: CGRect(x: 0, y: 0, width: 340, height: 340))
        host.wantsLayer = true
        let window = makeWindow(host)
        let oldPolicy = NSApp.activationPolicy()
        defer { window.orderOut(nil); window.close(); NSApp.setActivationPolicy(oldPolicy) }
        var rows: [[String: Any]] = []
        let start = Date()
        func record(_ event: String, callback: Bool? = nil) {
            var row = Self.windowState(window, host: host)
            row["event"] = event; row["elapsed"] = Date().timeIntervalSince(start)
            if let callback { row["callback"] = callback }
            rows.append(row)
            print("PIO_MAC_VISIBILITY \(row)")
        }
        var desired = true
        var fulfilled = false
        var next = expectation(description: "actual native visible callback")
        host.visibilityChanged = { value in
            record("host-callback", callback: value)
            if value == desired && !fulfilled { fulfilled = true; next.fulfill() }
        }
        let names: [Notification.Name] = [NSApplication.didBecomeActiveNotification,
            NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification, NSWindow.didBecomeKeyNotification,
            NSWindow.didExposeNotification]
        let tokens = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { notification in
                MainActor.assumeIsolated {
                    if name == NSApplication.didBecomeActiveNotification || (notification.object as? NSWindow) === window {
                        record(notification.name.rawValue)
                    }
                }
            }
        }
        defer {
            tokens.forEach(NotificationCenter.default.removeObserver)
            attach(rows, name: "mac-window-native-transitions")
        }
        record("before-front")
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        await fulfillment(of: [next], timeout: 5)
        record("after-front")
        guard window.occlusionState.contains(.visible) else {
            XCTFail("WindowServer never reported public visible bit 2. The positive desktop lifecycle remains unverified; see raw state attachment.")
            return
        }
        XCTAssertTrue(fulfilled)
        desired = false; fulfilled = false
        next = expectation(description: "automatic orderOut callback")
        window.orderOut(nil)
        await fulfillment(of: [next], timeout: 5)
        record("after-orderOut")
        XCTAssertFalse(window.isVisible)
        desired = true; fulfilled = false
        next = expectation(description: "automatic restored callback")
        window.makeKeyAndOrderFront(nil); window.orderFrontRegardless()
        await fulfillment(of: [next], timeout: 5)
        record("after-restore")
        XCTAssertTrue(window.occlusionState.contains(.visible))
        desired = false; fulfilled = false
        next = expectation(description: "automatic minimized callback")
        window.miniaturize(nil)
        await fulfillment(of: [next], timeout: 5)
        record("after-miniaturize")
        XCTAssertTrue(window.isMiniaturized)
        desired = true; fulfilled = false
        next = expectation(description: "automatic deminiaturized callback")
        window.deminiaturize(nil)
        await fulfillment(of: [next], timeout: 5)
        record("after-deminiaturize")
        XCTAssertTrue(window.occlusionState.contains(.visible))
        host.isHidden = true
        XCTAssertFalse(window.isMiniaturized)
        host.refreshVisibility()
        XCTAssertFalse(Self.windowState(window, host: host)["expectedGate"] as? Bool ?? true)
    }

    func testColdThenIdenticalWarmCloudPasses() async throws {
        let host = NSView(frame: CGRect(x: 0, y: 0, width: 340, height: 340)); host.wantsLayer = true
        let window = makeWindow(host)
        defer { window.orderOut(nil); window.close() }
        window.orderFrontRegardless()
        var samples: [[String: Any]] = []
        var phases: [[String: Any]] = []
        var released: [Bool] = []
        let start = Date(), cpuStart = Self.cpu()
        func sample(_ phase: String, outfit: String = "", kind: String = "", tracks: Int = 0) {
            samples.append(["phase": phase, "outfit": outfit, "kind": kind,
                "elapsed": Date().timeIntervalSince(start), "cpuSeconds": Self.cpu() - cpuStart,
                "rss": Self.rss(), "tracks": tracks,
                "windowVisible": window.isVisible, "occlusion": window.occlusionState.rawValue,
                "publicVisible": window.occlusionState.contains(.visible)])
        }
        sample("baseline")
        for pass in 0..<4 {
            let name = pass == 0 ? "cold" : "warm-\(pass)"
            let begin = Date(), beginCPU = Self.cpu(), beginRSS = Self.rss()
            var stage: RoutimoriSyncStage? = RoutimoriSyncStage()
            weak var weakStage = stage
            host.layer!.addSublayer(stage!.root); stage!.root.position = CGPoint(x: 170, y: 170)
            for outfit in PioOutfitID.allCases {
                for kind in SyncSceneKind.allCases {
                    autoreleasepool {
                        stage!.update(.init(kind: kind, height: 340, dark: false, scale: 2,
                            reduceMotion: false, outfit: outfit, usesIndependentCharacter: kind == .ready || PioCloudSceneResources.hasSeatedLayers(outfit)), isAnimating: true)
                        CATransaction.flush()
                    }
                    // Fixed observation dwell, not an increased assertion timeout.
                    try await Task.sleep(for: .milliseconds(500))
                    sample(name, outfit: outfit.rawValue, kind: kind.rawValue, tracks: Self.tracks(stage!.root))
                }
            }
            stage!.halt()
            XCTAssertEqual(Self.tracks(stage!.root), 0)
            sample(name + "-stopped")
            stage!.root.removeFromSuperlayer(); stage = nil; CATransaction.flush()
            released.append(weakStage == nil)
            XCTAssertNil(weakStage, "The scene stage must release; image/OS caches are evaluated separately")
            try await Task.sleep(for: .seconds(2))
            sample(name + "-released")
            phases.append(["phase": name, "seconds": Date().timeIntervalSince(begin),
                "cpuSeconds": Self.cpu() - beginCPU, "initialRSS": beginRSS, "finalRSS": Self.rss()])
        }
        let stoppedBegin = Date(), stoppedCPU = Self.cpu()
        for _ in 0..<10 { try await Task.sleep(for: .seconds(1)); sample("cooldown-no-scene") }
        let report: [String: Any] = ["samples": samples, "phases": phases, "allSceneInstancesReleased": released,
            "cooldownSeconds": Date().timeIntervalSince(stoppedBegin), "cooldownCPUSeconds": Self.cpu() - stoppedCPU,
            "seconds": Date().timeIntervalSince(start), "pid": ProcessInfo.processInfo.processIdentifier,
            "scope": "Mac Debug, same 14 outfits x 3 cloud states, 500ms per state, one cold and three identical warm passes; no concurrent builds requested",
            "limits": "Process CPU/RSS only; external WindowServer/GPU excluded. Raw visibility sampled, never assumed. Bounded observations cannot prove absence of all leaks or battery efficiency.",
            "sourceCache": "PioOverhaulResources NSCache 96MiB soft cost limit plus NSImage(named:) platform cache. No cache purge or source image changes performed."]
        attach(report, name: "mac-cloud-cold-warm-memory")
    }

    func testBasicSeatedFallbackMatchesApp() throws {
        for kind: SyncSceneKind in [.receiving, .trouble] {
            for dark in [false, true] {
                let stage = RoutimoriSyncStage()
                let independent = PioCloudSceneResources.hasSeatedLayers(.basic)
                XCTAssertTrue(independent, "The approved Basic production eye pack must now be available")
                XCTAssertNotNil(PioCloudSceneResources.productionBasicRegistration())
                let native = RoutimoriSyncStage()
                native.update(.init(kind: kind, height: 340, dark: dark, scale: 2, reduceMotion: true,
                    outfit: .basic, usesIndependentCharacter: independent), isAnimating: true)
                XCTAssertNotNil(native.character.sublayers?.first, "The current app path must attach its independent Basic rig")
                XCTAssertNil(native.character.contents)
                XCTAssertEqual(Self.tracks(native.root), 0)
                native.halt()
                // The original flattened source remains the explicit safe
                // fallback; keep verifying its actual CGImage and pixels.
                stage.update(.init(kind: kind, height: 340, dark: dark, scale: 2, reduceMotion: true,
                    outfit: .basic, usesIndependentCharacter: false), isAnimating: true)
                XCTAssertEqual(stage.root.sublayers?.count, 3)
                let contents = try XCTUnwrap(stage.root.sublayers?.last?.contents,
                    "The approved Basic fallback must actually load")
                guard CFGetTypeID(contents as CFTypeRef) == CGImage.typeID else {
                    XCTFail("The Basic layer must hold a CGImage"); continue
                }
                let original = contents as! CGImage
                let alpha = try XCTUnwrap(CGContext(data: nil, width: 256, height: 256, bitsPerComponent: 8,
                    bytesPerRow: 1024, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                alpha.draw(original, in: CGRect(x: 0, y: 0, width: 256, height: 256))
                let bytes = try XCTUnwrap(alpha.data).assumingMemoryBound(to: UInt8.self)
                let nonempty = stride(from: 3, to: 256 * 1024, by: 4).reduce(0) { $0 + (bytes[$1] > 0 ? 1 : 0) }
                XCTAssertGreaterThan(nonempty, 1024, "Basic source must contain genuine rendered character pixels, not an empty layer")
                let context = try XCTUnwrap(CGContext(data: nil, width: 680, height: 680, bitsPerComponent: 8,
                    bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.setFillColor(CGColor(gray: dark ? 0.09 : 0.97, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: 680, height: 680)); context.scaleBy(x: 2, y: 2)
                stage.root.render(in: context)
                let image = try XCTUnwrap(context.makeImage())
                let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
                let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
                attachment.name = "basic-\(kind.rawValue)-\(dark ? "dark" : "light")-retained-flat-fallback"
                attachment.lifetime = .keepAlways; add(attachment)
                XCTAssertEqual(Self.tracks(stage.root), 0)
            }
        }
    }

    private func makeWindow(_ view: NSView) -> NSWindow {
        let window = NSWindow(contentRect: view.bounds, styleMask: [.titled, .miniaturizable], backing: .buffered, defer: false)
        window.title = "RoutiMori · isolated stability review"; window.isReleasedWhenClosed = false
        window.contentView = view; window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        if let screen = NSScreen.main {
            window.setFrameOrigin(CGPoint(x: screen.visibleFrame.midX - 170, y: screen.visibleFrame.midY - 170))
        }
        return window
    }
    private static func windowState(_ window: NSWindow, host: NSView) -> [String: Any] {
        ["isVisible": window.isVisible, "miniaturized": window.isMiniaturized,
         "rawOcclusion": window.occlusionState.rawValue, "publicVisibleBit": NSWindow.OcclusionState.visible.rawValue,
         "containsVisible": window.occlusionState.contains(.visible), "sameWindow": host.window === window,
         "hidden": host.isHiddenOrHasHiddenAncestor, "visibleRect": NSStringFromRect(host.visibleRect),
         "bounds": NSStringFromRect(host.bounds), "windowFrame": NSStringFromRect(window.frame),
         "appActive": NSApp.isActive, "activationPolicy": NSApp.activationPolicy().rawValue,
         "expectedGate": window.isVisible && !window.isMiniaturized && window.occlusionState.contains(.visible)
             && !host.isHiddenOrHasHiddenAncestor && !host.visibleRect.isEmpty && host.visibleRect.intersects(host.bounds)]
    }
    private static func tracks(_ layer: CALayer) -> Int {
        (layer.animationKeys()?.count ?? 0) + (layer.sublayers ?? []).reduce(0) { $0 + tracks($1) }
    }
    private static func cpu() -> Double {
        var r = rusage(); getrusage(RUSAGE_SELF, &r)
        return Double(r.ru_utime.tv_sec + r.ru_stime.tv_sec) + Double(r.ru_utime.tv_usec + r.ru_stime.tv_usec) / 1e6
    }
    private static func rss() -> UInt64 {
        var info = mach_task_basic_info(); var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)
        let result = withUnsafeMutablePointer(to: &info) { p in
            p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count) }
        }
        return result == KERN_SUCCESS ? UInt64(info.resident_size) : 0
    }
    private func attach(_ value: Any, name: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) else { return XCTFail("Evidence JSON encoding failed") }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
#endif
