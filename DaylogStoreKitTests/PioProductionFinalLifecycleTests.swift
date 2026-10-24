import XCTest
import QuartzCore
import SwiftUI
import Darwin
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import Daylog

/// Opt-in, visible native rendering observations. No receipts, preferences,
/// entitlement overrides or user-data writes. RSS is evidence, never a pass gate.
@MainActor final class PioProductionFinalLifecycleTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioProductionFinalLifecycleReview"))
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
    }

    func testTenVisibleCloudAttachDetachCycles() async throws { try await repeatedCycles(10) }
    func testTwentyVisibleCloudAttachDetachCycles() async throws { try await repeatedCycles(20) }
    func testFiftyVisibleCloudAttachDetachCycles() async throws { try await repeatedCycles(50) }

    #if os(macOS)
    /// Drop a complete scroll subtree without manually detaching its document.
    /// Explicit document removal would conceal a retained ancestor cycle.
    func testMacIntactScrollSubtreeReleasesNativeHost() async throws {
        let hostWindow = try NativeWindow()
        defer { hostWindow.close() }
        let start = snapshot()
        var scroll: NSScrollView? = NSScrollView(frame: CGRect(x: 20, y: 20, width: 280, height: 320))
        var host: PioCloudSceneHost? = PioCloudSceneHost(frame: CGRect(x: 0, y: 0, width: 260, height: 300))
        host!.wantsLayer = true
        weak var weakHost = host
        weak var weakScroll = scroll
        weak var weakClip = scroll!.contentView
        var stage: RoutimoriSyncStage? = RoutimoriSyncStage()
        weak var weakStage = stage
        host!.layer!.addSublayer(stage!.root)
        host!.hosted = stage!.root
        let visible = expectation(description: "scroll subtree really visible before ownership teardown")
        var seen = false
        let config = configuration(.basic)
        host!.visibilityChanged = { [weak scene = stage] value in
            scene?.update(config, isAnimating: value)
            if value && !seen { seen = true; visible.fulfill() }
        }
        scroll!.documentView = host
        hostWindow.parent.addSubview(scroll!)
        host!.refreshVisibility(); CATransaction.flush()
        await fulfillment(of: [visible], timeout: 3)
        XCTAssertTrue(hostWindow.actuallyVisible)
        XCTAssertGreaterThan(tracks(stage!.root), 0)
        // Equivalent to representable dismantle plus dropping an outer subtree.
        // Do NOT call removeFromSuperview on the character document itself.
        autoreleasepool {
            stage!.halt(); host!.visibilityChanged = nil
            scroll!.removeFromSuperview()
            stage = nil; host = nil; scroll = nil
            CATransaction.flush()
        }
        let row: [String: Any] = ["seenVisible": seen, "stageReleased": weakStage == nil,
            "hostReleased": weakHost == nil, "scrollReleased": weakScroll == nil,
            "clipReleased": weakClip == nil, "afterDrop": snapshot()]
        try attachReport(name: "final-mac-intact-scroll-subtree", start: start, rows: [row],
            scope: "Visible scroll subtree dropped intact after stage halt; no explicit document detach before lifetime assertions")
        XCTAssertNil(weakStage)
        XCTAssertNil(weakScroll)
        XCTAssertNil(weakHost, "Document host must not retain its owning clip ancestor")
        XCTAssertNil(weakClip, "Owning clip and document must not form a retained cycle")
        // Clean up evidence of a failed ownership assertion without altering it.
        // This only executes after the observations and assertions above.
        weakHost?.removeFromSuperview()
    }

    /// Exercise the actual private vacation NSView through its public SwiftUI
    /// scene rather than a replacement host with different ownership behavior.
    func testMacVacationSwiftUIScrollSubtreeReleasesNativeView() async throws {
        let hostWindow = try NativeWindow()
        defer { hostWindow.close() }
        let start = snapshot()
        var scroll: NSScrollView?
        var hosting: NSHostingView<AnyView>?
        // SwiftUI/AppKit creation and hierarchy inspection may autorelease
        // temporary views/arrays. The fixture must not retain its subject via
        // an enclosing test-runner autorelease pool after dropping ownership.
        autoreleasepool {
            scroll = NSScrollView(frame: CGRect(x: 20, y: 20, width: 280, height: 340))
            hosting = NSHostingView(rootView: AnyView(
                RoutimoriVacationScene(slot: CGRect(x: 0, y: 80, width: 280, height: 220))
                    .frame(width: 280, height: 400)
                    .environment(\.scenePhase, .active)))
            hosting!.frame = CGRect(x: 0, y: 0, width: 280, height: 400)
        }
        weak var weakHosting = hosting
        weak var weakScroll = scroll
        weak var weakClip = scroll!.contentView
        weak var weakNative: NSView?
        autoreleasepool {
            scroll!.documentView = hosting
            hostWindow.parent.addSubview(scroll!)
            hosting!.layoutSubtreeIfNeeded()
        }
        let rendered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated {
                autoreleasepool {
                    guard let hosting, let native = self.vacationNativeView(in: hosting) else { return false }
                    weakNative = native
                    return native.window != nil && !native.visibleRect.isEmpty && hostWindow.actuallyVisible
                }
            }
        }, object: nil)
        await fulfillment(of: [rendered], timeout: 5)
        XCTAssertNotNil(weakNative, "The actual vacation native view must exist before testing its lifetime")
        autoreleasepool {
            // Remove only the outer subtree; never explicitly detach vacation.
            scroll!.removeFromSuperview(); hosting = nil; scroll = nil
            CATransaction.flush()
        }
        // SwiftUI can schedule dismantle on its next update. Observe actual
        // release rather than sleeping for an arbitrary assumed completion time.
        let released = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated {
                weakNative == nil && weakHosting == nil && weakScroll == nil && weakClip == nil
            }
        }, object: nil)
        await fulfillment(of: [released], timeout: 3)
        let row: [String: Any] = ["nativeReleased": weakNative == nil,
            "hostingReleased": weakHosting == nil, "scrollReleased": weakScroll == nil,
            "clipReleased": weakClip == nil, "afterDrop": snapshot()]
        try attachReport(name: "final-mac-vacation-swiftui-subtree", start: start, rows: [row],
            scope: "Actual RoutimoriVacationScene via NSHostingView in a visible scroll container; drop intact outer subtree, observe SwiftUI dismantle and weak native/hosting/scroll/clip release. No purchase/appearance override")
        XCTAssertNil(weakNative); XCTAssertNil(weakHosting); XCTAssertNil(weakScroll); XCTAssertNil(weakClip)
        weakNative?.removeFromSuperview()
    }

    private func vacationNativeView(in view: NSView) -> NSView? {
        if String(describing: type(of: view)) == "RoutimoriVacationNativeView" { return view }
        for child in view.subviews {
            if let native = vacationNativeView(in: child) { return native }
        }
        return nil
    }

    func testMacPlainSwiftUIScrollSubtreeOwnershipControl() async throws {
        let hostWindow = try NativeWindow()
        defer { hostWindow.close() }
        var scroll: NSScrollView?
        var hosting: NSHostingView<AnyView>?
        autoreleasepool {
            scroll = NSScrollView(frame: CGRect(x: 20, y: 20, width: 280, height: 340))
            hosting = NSHostingView(rootView: AnyView(Text("Native ownership control")
                .frame(width: 280, height: 400).environment(\.scenePhase, .active)))
            hosting!.frame = CGRect(x: 0, y: 0, width: 280, height: 400)
            scroll!.documentView = hosting
            hostWindow.parent.addSubview(scroll!)
            hosting!.layoutSubtreeIfNeeded()
        }
        weak var weakHosting = hosting
        weak var weakClip = scroll!.contentView
        weak var weakScroll = scroll
        // Window orderFront and SwiftUI layout do not synchronously publish
        // AppKit occlusion. Match the vacation fixture's first-visible gate.
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated {
                autoreleasepool {
                    guard let hosting else { return false }
                    return hostWindow.actuallyVisible && hosting.window === hostWindow.window
                        && !hosting.bounds.isEmpty && !hosting.visibleRect.isEmpty
                }
            }
        }, object: nil)
        await fulfillment(of: [visible], timeout: 3)
        XCTAssertTrue(hostWindow.actuallyVisible)
        XCTAssertTrue(hosting?.window === hostWindow.window)
        XCTAssertFalse(hosting?.visibleRect.isEmpty ?? true)
        autoreleasepool {
            scroll!.removeFromSuperview(); hosting = nil; scroll = nil; CATransaction.flush()
        }
        let released = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { weakHosting == nil && weakClip == nil && weakScroll == nil }
        }, object: nil)
        await fulfillment(of: [released], timeout: 3)
        XCTAssertNil(weakHosting); XCTAssertNil(weakClip); XCTAssertNil(weakScroll)
    }
    #endif

    /// Three passes distinguish first resource use from repeated reuse. Every
    /// row includes the actual selected registration rather than assuming Release.
    func testFourteenOutfitsThreeVisibleSequentialPasses() async throws {
        let hostWindow = try NativeWindow()
        defer { hostWindow.close() }
        let start = snapshot()
        var rows: [[String: Any]] = []
        for pass in 1...3 {
            for outfit in PioOutfitID.allCases {
                let registration = try XCTUnwrap(PioCloudSceneResources.selectedRegistration(outfit: outfit),
                    "Missing independent registration for \(outfit.rawValue); do not measure a silent Basic fallback")
                let row = try await visibleCycle(window: hostWindow, outfit: outfit,
                    label: "pass-\(pass)-\(outfit.rawValue)")
                rows.append(row.merging(["pass": pass, "outfit": outfit.rawValue,
                                         "registration": registration.revision]) { _, new in new })
            }
        }
        XCTAssertEqual(rows.count, PioOutfitID.allCases.count * 3)
        try attachReport(name: "final-cloud-fourteen-three-passes", start: start, rows: rows,
            scope: "14 outfit registrations, three sequential passes in one native window; each visible scene starts, stops and is released")
    }

    /// Explicitly the normal home reference renderer, not the DEBUG overhaul
    /// rig. This checks image loading/lifetime, not all ten motion aesthetics.
    func testHomeReferenceFourteenOutfitsTwoVisiblePasses() async throws {
        let hostWindow = try NativeWindow()
        defer { hostWindow.close() }
        let start = snapshot()
        var rows: [[String: Any]] = []
        for pass in 1...2 {
            for outfit in PioOutfitID.allCases {
                let before = snapshot()
                var rig: PioOutfitMotionRig? = PioOutfitMotionRig()
                weak var weakRig = rig
                rig!.configure(outfit: outfit, stage: 1, motion: .idle)
                rig!.layout(in: CGRect(x: 60, y: 100, width: 220, height: 220), displayScale: 2)
                XCTAssertNotNil(rig!.artwork.contents)
                hostWindow.layer.addSublayer(rig!.root)
                rig!.setAnimating(true); CATransaction.flush()
                XCTAssertGreaterThan(rig!.animationCount, 0)
                try await Task.sleep(for: .milliseconds(150))
                XCTAssertTrue(hostWindow.actuallyVisible)
                XCTAssertNotNil(rig!.root.presentation())
                let active = snapshot()
                autoreleasepool {
                    rig!.setAnimating(false); XCTAssertEqual(rig!.animationCount, 0)
                    rig!.root.removeFromSuperlayer(); rig = nil; CATransaction.flush()
                }
                XCTAssertNil(weakRig)
                rows.append(["pass": pass, "outfit": outfit.rawValue, "before": before,
                    "active": active, "afterCleanup": snapshot(), "rigReleased": weakRig == nil])
            }
        }
        try attachReport(name: "final-home-reference-fourteen-two-passes", start: start, rows: rows,
            scope: "Normal home fallback PioOutfitMotionRig;14 outfits x2 passes, visible idle150ms and explicit stop/release. No DEBUG overhaul, wardrobe equip, ownership or actual dashboard UI")
    }

    /// Existing composed vacation art and sway only. Never describes this as
    /// independent eye/hand/drink or exact two-point rope attachment validation.
    func testVacationFourteenDayNightTwoVisiblePasses() async throws {
        let hostWindow = try NativeWindow()
        defer { hostWindow.close() }
        let start = snapshot()
        var rows: [[String: Any]] = []
        for pass in 1...2 {
            for outfit in PioOutfitID.allCases {
                let before = snapshot()
                var rig: RoutimoriVacationRig? = RoutimoriVacationRig(outfit: outfit)
                weak var weakRig = rig
                hostWindow.layer.addSublayer(rig!.root)
                var states: [[String: Any]] = []
                for night in [false, true] {
                    rig!.layout(in: CGRect(x: 0, y: 0, width: 340, height: 380), slot: nil,
                                isDark: night, displayScale: 2)
                    XCTAssertNotNil(rig!.hammock.contents)
                    XCTAssertNotNil(rig!.beach.contents)
                    let asset = PioVacationSceneResources.sourceAsset(outfit: outfit, night: night)
                    XCTAssertEqual(rig!.currentRegistration,
                        PioVacationSceneResources.registration(asset: asset, night: night))
                    rig!.setAnimating(true); CATransaction.flush()
                    XCTAssertNotNil(rig!.hammock.animation(forKey: "hammockSway"))
                    try await Task.sleep(for: .milliseconds(150))
                    XCTAssertTrue(hostWindow.actuallyVisible)
                    XCTAssertNotNil(rig!.root.presentation())
                    states.append(["night": night, "asset": asset, "memory": snapshot()])
                    rig!.setAnimating(false); XCTAssertEqual(tracks(rig!.root), 0)
                }
                autoreleasepool {
                    rig!.root.removeFromSuperlayer(); rig = nil; CATransaction.flush()
                }
                XCTAssertNil(weakRig)
                rows.append(["pass": pass, "outfit": outfit.rawValue, "before": before,
                    "dayNight": states, "afterCleanup": snapshot(), "rigReleased": weakRig == nil])
            }
        }
        try attachReport(name: "final-vacation-fourteen-day-night-two-passes", start: start, rows: rows,
            scope: "Existing composed vacation rig;14 outfits x day/night x2 passes. First-load includes two generated ambient backdrops per rig;150ms native visibility per state, explicit stop/release. Not independent vacation artwork approval")
    }

    /// Alternating order reduces simple warmup/order confounding. Five 1-second
    /// samples per phase are observation windows, not waits for a test to pass.
    func testPairedVisibleActiveStoppedProcessObservations() async throws {
        let hostWindow = try NativeWindow()
        defer { hostWindow.close() }
        let start = snapshot()
        var rows: [[String: Any]] = []
        // Empty visible host, before first resource decode in this method.
        rows.append(try await sample(window: hostWindow, label: "empty-host", seconds: 2))
        var stage: RoutimoriSyncStage? = RoutimoriSyncStage()
        weak var weakStage = stage
        hostWindow.layer.addSublayer(stage!.root)
        stage!.root.position = CGPoint(x: 170, y: 170)
        let config = configuration(.basic)
        stage!.update(config, isAnimating: true)
        CATransaction.flush()
        rows.append(try await sample(window: hostWindow, label: "first-resource-warmup", seconds: 2))
        for (pair, order) in [[true, false], [false, true], [true, false]].enumerated() {
            for active in order {
                stage!.update(config, isAnimating: active)
                CATransaction.flush()
                if active { XCTAssertGreaterThan(tracks(stage!.character), 0) }
                else { XCTAssertEqual(tracks(stage!.root), 0) }
                var row = try await sample(window: hostWindow,
                    label: active ? "active" : "stopped", seconds: 5)
                row["pair"] = pair + 1
                row["trackCount"] = tracks(stage!.root)
                row["hasNativePresentation"] = stage!.root.presentation() != nil
                rows.append(row)
            }
        }
        autoreleasepool {
            stage!.halt(); stage!.root.removeFromSuperlayer(); stage = nil
            CATransaction.flush()
        }
        XCTAssertNil(weakStage)
        rows.append(try await sample(window: hostWindow, label: "after-release", seconds: 2))
        try attachReport(name: "final-cloud-paired-active-stopped", start: start, rows: rows,
            scope: "Same Basic selected path and native window; empty2s, warmup2s, three counterbalanced active/stopped pairs of5s each, released2s. Process CPU includes XCTest; excludes GPU/compositor")
    }

    private func repeatedCycles(_ count: Int) async throws {
        let hostWindow = try NativeWindow()
        defer { hostWindow.close() }
        let start = snapshot()
        var rows: [[String: Any]] = []
        for index in 1...count {
            var row = try await visibleCycle(window: hostWindow, outfit: .basic, label: "cycle-\(index)")
            row["cycle"] = index
            rows.append(row)
        }
        try attachReport(name: "final-cloud-\(count)-cycles", start: start, rows: rows,
            scope: "\(count) Basic visible attach/150ms presentation/detach cycles. Assertions cover visibility, active tracks, detached zero tracks, weak stage and host release")
    }

    private func visibleCycle(window: NativeWindow, outfit: PioOutfitID, label: String) async throws -> [String: Any] {
        let before = snapshot()
        var stage: RoutimoriSyncStage? = RoutimoriSyncStage()
        var host: PioCloudSceneHost? = PioCloudSceneHost(frame: CGRect(x: 40, y: 80, width: 220, height: 220))
        #if os(macOS)
        host!.wantsLayer = true
        host!.layer!.addSublayer(stage!.root)
        #else
        host!.layer.addSublayer(stage!.root)
        #endif
        host!.hosted = stage!.root
        weak var weakStage = stage
        weak var weakHost = host
        let visible = expectation(description: "actually visible \(label)")
        var seenVisible = false
        let config = configuration(outfit)
        host!.visibilityChanged = { [weak scene = stage] shown in
            scene?.update(config, isAnimating: shown)
            if shown && !seenVisible { seenVisible = true; visible.fulfill() }
        }
        window.parent.addSubview(host!)
        host!.refreshVisibility()
        stage!.root.position = CGPoint(x: 110, y: 110)
        CATransaction.flush()
        await fulfillment(of: [visible], timeout: 3)
        XCTAssertTrue(window.actuallyVisible)
        let activeTracks = tracks(stage!.character)
        XCTAssertGreaterThan(activeTracks, 0)
        // A bounded presentation interval, not an increased correctness timeout.
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertNotNil(stage!.root.presentation(), "An attached but never presented layer is not a native rendering observation")
        let active = snapshot()
        let detachedTracks = autoreleasepool { () -> Int in
            host!.removeFromSuperview(); host!.refreshVisibility()
            let detached = tracks(stage!.root)
            stage!.halt(); stage!.root.removeFromSuperlayer()
            host!.hosted = nil; host!.visibilityChanged = nil
            stage = nil; host = nil
            CATransaction.flush()
            return detached
        }
        XCTAssertEqual(detachedTracks, 0, "Native detach must stop tracks before explicit cleanup")
        XCTAssertNil(weakStage)
        XCTAssertNil(weakHost)
        return ["label": label, "before": before, "active": active, "afterCleanup": snapshot(),
            "actuallyVisible": seenVisible, "activeCharacterTracks": activeTracks,
            "tracksImmediatelyAfterDetach": detachedTracks,
            "stageReleased": weakStage == nil, "hostReleased": weakHost == nil]
    }

    private func configuration(_ outfit: PioOutfitID) -> RoutimoriSyncStage.Configuration {
        .init(kind: .receiving, height: 220, dark: false, scale: 2, reduceMotion: false,
              outfit: outfit, usesIndependentCharacter: true)
    }

    private func sample(window: NativeWindow, label: String, seconds: Int) async throws -> [String: Any] {
        let started = CACurrentMediaTime(), initialCPU = cpuSeconds(), initialRSS = residentBytes()
        var samples: [[String: Any]] = []
        for _ in 0..<seconds {
            try await Task.sleep(for: .seconds(1))
            XCTAssertTrue(window.actuallyVisible, "A hidden host invalidates active/stopped performance comparison")
            samples.append(snapshot().merging(["visible": window.actuallyVisible]) { _, new in new })
        }
        let elapsed = CACurrentMediaTime() - started
        let cpu = cpuSeconds() - initialCPU
        return ["phase": label, "seconds": elapsed, "cpuSeconds": cpu, "cpuPercentOneCore": cpu / elapsed * 100,
            "initialRSS": initialRSS, "finalRSS": residentBytes(), "samples": samples]
    }

    private func attachReport(name: String, start: [String: Any], rows: [[String: Any]], scope: String) throws {
        let report: [String: Any] = ["initial": start, "final": snapshot(), "rows": rows, "scope": scope,
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "processorCount": ProcessInfo.processInfo.processorCount,
            "candidateHandsFlag": PioCloudBasicEyesTrial.handsEnabled,
            "candidateEyesFlag": PioCloudBasicEyesTrial.isEnabled,
            "basicRegistration": PioCloudSceneResources.selectedRegistration(outfit: .basic)?.revision ?? "missing",
            "limitations": "Debug XCTest host; RSS is not a leak assertion. Includes shared image/cache/allocator/renderer residency. Not app cold-launch, production entitlement flow, actual OS backgrounding, full home/vacation profiling, Instruments allocations, compositor/GPU/battery or long-term leak proof. No arbitrary memory threshold or retry sleep."]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: report,
            options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func snapshot() -> [String: Any] {
        ["monotonicSeconds": CACurrentMediaTime(), "cpuSeconds": cpuSeconds(), "rssBytes": residentBytes()]
    }
    private func tracks(_ layer: CALayer) -> Int {
        (layer.animationKeys()?.count ?? 0) + (layer.sublayers ?? []).reduce(0) { $0 + tracks($1) }
    }
    private func cpuSeconds() -> Double {
        var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1e6
    }
    private func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        XCTAssertEqual(status, KERN_SUCCESS, "RSS measurement failure must not masquerade as zero usage")
        return status == KERN_SUCCESS ? UInt64(info.resident_size) : 0
    }

    @MainActor private final class NativeWindow {
        #if os(macOS)
        let window: NSWindow
        let parent: NSView
        var layer: CALayer { parent.layer! }
        var actuallyVisible: Bool { window.isVisible && !window.isMiniaturized && window.occlusionState.contains(.visible) }
        init() throws {
            parent = NSView(frame: CGRect(x: 0, y: 0, width: 340, height: 380)); parent.wantsLayer = true
            window = NSWindow(contentRect: parent.bounds, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.contentView = parent; window.orderFrontRegardless()
        }
        func close() { window.orderOut(nil); window.close() }
        #else
        let window: UIWindow
        let parent: UIView
        let scene: UIWindowScene
        weak var priorKeyWindow: UIWindow?
        var layer: CALayer { parent.layer }
        var actuallyVisible: Bool { !window.isHidden && scene.activationState == .foregroundActive }
        init() throws {
            scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive })
            priorKeyWindow = scene.windows.first { $0.isKeyWindow }
            window = UIWindow(windowScene: scene)
            let controller = UIViewController(); window.rootViewController = controller
            parent = controller.view; window.makeKeyAndVisible()
        }
        func close() { window.isHidden = true; window.rootViewController = nil; priorKeyWindow?.makeKey() }
        #endif
    }
}
