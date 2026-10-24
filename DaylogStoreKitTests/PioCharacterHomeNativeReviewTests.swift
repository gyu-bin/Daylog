#if DEBUG
import XCTest
import SwiftUI
import QuartzCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import Daylog

/// Real-time production component evidence, independent of outfit ownership.
/// This diagnostic host never equips a costume or grants an entitlement.
@MainActor final class PioCharacterHomeNativeReviewTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioCharacterHomeReview"))
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
        XCTAssertFalse(PioOverhaulTrial.isEnabled)
    }

    func testAllFourteenHomeIndependentPresentationAt64And220() async throws {
        var rows: [[String: Any]] = []
        for size: CGFloat in [64, 220] {
            let host = try Host(size: CGSize(width: size, height: size))
            try await visible(host)
            for outfit in PioOutfitID.allCases {
                let stage = PioHomeProductionStage()
                host.layer.addSublayer(stage.root)
                stage.update(outfit: outfit, action: .idle, active: true, bounds: host.bounds)
                CATransaction.flush(); try await Task.sleep(for: .milliseconds(150))
                XCTAssertGreaterThan(stage.animationCount, 0)
                try capture(host, name: "home-independent-\(outfit.rawValue)-\(Int(size))pt-idle")
                stage.update(outfit: outfit, action: .greet, active: true, bounds: host.bounds)
                CATransaction.flush(); try await Task.sleep(for: .milliseconds(650))
                let wing = try XCTUnwrap(stage.rig.layers["wingRight"] ?? stage.rig.layers["handRight"])
                let pose = try XCTUnwrap(wing.presentation())
                let angle = atan2(Double(pose.transform.m12), Double(pose.transform.m11))
                try capture(host, name: "home-independent-\(outfit.rawValue)-\(Int(size))pt-greet")
                stage.halt(); CATransaction.flush()
                try await Task.sleep(for: .milliseconds(100))
                XCTAssertEqual(stage.animationCount, 0)
                try capture(host, name: "home-independent-\(outfit.rawValue)-\(Int(size))pt-stopped")
                rows.append(["outfit": outfit.rawValue, "size": size, "greetRightJointRadians": angle,
                             "stoppedTracks": stage.animationCount, "parts": stage.rig.layers.keys.sorted(),
                             "scope": "real production rig idle/greet/stopped wall-time presentation, not all ten motions visually approved"])
                stage.root.removeFromSuperlayer()
            }
            host.close()
        }
        try report(rows, name: "home-independent-fourteen-native-observations")
    }

    func testThreeAuthoredGesturesActuallySettleAfterPlayback() async throws {
        let host = try Host(size: CGSize(width: 220, height: 220))
        try await visible(host); defer { host.close() }
        var rows: [[String: Any]] = []
        for (outfit, action) in [(PioOutfitID.christmas, PioHomeProductionAction.greet),
                                 (.hanbok, .jump), (.astronaut, .encourage)] {
            let stage = PioHomeProductionStage(); host.layer.addSublayer(stage.root)
            stage.update(outfit: outfit, action: action, active: true, bounds: host.bounds)
            CATransaction.flush()
            let start = CACurrentMediaTime()
            var frame = 0
            var positions = Set<[Double]>()
            repeat {
                try await Task.sleep(for: .milliseconds(50))
                if let layer = stage.rig.movement.presentation() {
                    let t = layer.transform
                    positions.insert([Double(t.m41), Double(t.m42), Double(t.m11), Double(t.m12)])
                }
                try capture(host, name: "home-live-\(outfit.rawValue)-\(action.rawValue)-\(String(format: "%03d", frame))")
                frame += 1
            } while stage.displayedAction != .idle && CACurrentMediaTime() - start < 6
            XCTAssertEqual(stage.displayedAction, .idle, "The real completion task must return to idle")
            XCTAssertGreaterThan(frame, 10)
            // Authored jump moves Y; encourage moves X/lean; greet leans.
            // Observe the full relevant pose instead of assuming every action hops.
            XCTAssertGreaterThan(positions.count, 1)
            rows.append(["outfit": outfit.rawValue, "action": action.rawValue, "capturedFrames": frame,
                         "actualElapsed": CACurrentMediaTime() - start, "returnedToIdle": stage.displayedAction == .idle,
                         "note": "PNG capture adds overhead; chronological frames are native, not guaranteed fixed-rate video"])
            stage.halt(); XCTAssertEqual(stage.animationCount, 0); stage.root.removeFromSuperlayer()
        }
        try report(rows, name: "home-live-finite-gesture-observations")
    }

    private func visible(_ host: Host) async throws {
        let deadline = CACurrentMediaTime() + 8
        while !host.visible && CACurrentMediaTime() < deadline { try await Task.sleep(for: .milliseconds(16)) }
        XCTAssertTrue(host.visible)
    }
    private func report(_ rows: [[String: Any]], name: String) throws {
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func capture(_ host: Host, name: String) throws {
        XCTAssertTrue(host.visible, "Native capture must have a visible host")
        let presentation = try XCTUnwrap(host.layer.presentation())
        #if os(macOS)
        let context = try XCTUnwrap(CGContext(data: nil, width: Int(host.bounds.width * 2), height: Int(host.bounds.height * 2), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.scaleBy(x: 2, y: 2); presentation.render(in: context)
        let image = try XCTUnwrap(context.makeImage())
        let data = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        #else
        let format = UIGraphicsImageRendererFormat(); format.scale = 2
        let image = UIGraphicsImageRenderer(size: host.bounds.size, format: format).image { presentation.render(in: $0.cgContext) }
        let attachment = XCTAttachment(image: image)
        #endif
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private final class Host {
        let layer: CALayer
        let bounds: CGRect
        #if os(macOS)
        let window: NSWindow
        let view: NSView
        var visible: Bool { window.isVisible && window.occlusionState.contains(.visible) }
        #else
        let window: UIWindow
        let view: UIView
        var visible: Bool { !window.isHidden && view.window === window }
        #endif
        init(size: CGSize) throws {
            bounds = CGRect(origin: .zero, size: size)
            #if os(macOS)
            view = NSView(frame: bounds); view.wantsLayer = true
            window = NSWindow(contentRect: bounds, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.contentView = view
            window.orderFrontRegardless(); layer = try XCTUnwrap(view.layer)
            #else
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            window = UIWindow(windowScene: scene)
            let controller = UIViewController(); window.rootViewController = controller
            window.makeKeyAndVisible()
            view = UIView(frame: bounds); controller.view.addSubview(view); layer = view.layer
            #endif
            layer.backgroundColor = CGColor(gray: 0.97, alpha: 1)
        }
        func close() {
            layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            #if os(macOS)
            window.orderOut(nil); window.close()
            #else
            window.isHidden = true; window.rootViewController = nil
            #endif
        }
    }
}
#endif
