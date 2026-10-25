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

/// Opt-in component evidence. This never equips a costume or changes ownership.
/// Captures use real wall-time presentation layers, not interpolated model poses.
@MainActor final class PioProductionFinalVisualTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioProductionFinalVisualReview"))
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
        XCTAssertFalse(PioOverhaulTrial.isEnabled, "Review the ordinary production renderer")
    }

    func testFourteenHomeProductionMotionFrames() async throws {
        let host = try Host(size: CGSize(width: 260, height: 260))
        defer { host.close() }
        var rows: [[String: Any]] = []
        for outfit in PioOutfitID.allCases {
            let rig = PioOutfitMotionRig()
            host.layer.addSublayer(rig.root)
            rig.configure(outfit: outfit, stage: 1, motion: .idle)
            rig.layout(in: host.bounds, displayScale: 2)
            XCTAssertNotNil(rig.artwork.contents, "Missing original home artwork: \(outfit)")
            rig.setAnimating(true); CATransaction.flush()
            try await Task.sleep(for: .milliseconds(100))
            try capture(host, name: "home-\(outfit.rawValue)-idle")
            rig.configure(outfit: outfit, stage: 1, motion: .jump)
            rig.setAnimating(true); CATransaction.flush()
            try await Task.sleep(for: .milliseconds(550))
            let active = try XCTUnwrap(rig.artwork.presentation())
            XCTAssertGreaterThan(rig.animationCount, 0)
            try capture(host, name: "home-\(outfit.rawValue)-jump")
            let activeY = active.transform.m42
            rig.setAnimating(false)
            rig.configure(outfit: outfit, stage: 1, motion: .idle)
            rig.setAnimating(true, reduceMotion: true); CATransaction.flush()
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertEqual(rig.animationCount, 0)
            XCTAssertTrue(CATransform3DIsIdentity(rig.artwork.transform))
            try capture(host, name: "home-\(outfit.rawValue)-returned-reduce-motion")
            rows.append(["outfit": outfit.rawValue, "jumpPresentationY": Double(activeY),
                         "stoppedTracks": rig.animationCount, "scope": "ordinary home rig, flattened costume motion; not independent home wing approval"])
            rig.root.removeFromSuperlayer()
        }
        try report(rows, name: "fourteen-home-production-observations")
    }

    func testFourteenVacationDayNightActualMotionFrames() async throws {
        let host = try Host(size: CGSize(width: 375, height: 667))
        defer { host.close() }
        var rows: [[String: Any]] = []
        for outfit in PioOutfitID.allCases {
            let rig = RoutimoriVacationRig(outfit: outfit)
            host.layer.addSublayer(rig.root)
            for dark in [false, true] {
                let mode = dark ? "night" : "day"
                rig.layout(in: host.bounds, slot: CGRect(x: 18, y: 230, width: 339, height: 240), isDark: dark, displayScale: 2)
                XCTAssertNotNil(rig.hammock.contents)
                XCTAssertNotNil(rig.beach.contents)
                rig.setAnimating(true); CATransaction.flush()
                var angles: [Double] = []
                for (index, interval) in [0.1, 1.8, 1.9].enumerated() {
                    try await Task.sleep(for: .seconds(interval))
                    let pose = try XCTUnwrap(rig.hammock.presentation())
                    angles.append(atan2(Double(pose.transform.m12), Double(pose.transform.m11)))
                    try capture(host, name: "vacation-\(outfit.rawValue)-\(mode)-actual-\(index)")
                }
                XCTAssertGreaterThan((angles.max() ?? 0) - (angles.min() ?? 0), 0.0001)
                rig.setAnimating(false); CATransaction.flush()
                XCTAssertNil(rig.hammock.animationKeys())
                XCTAssertTrue(CATransform3DIsIdentity(rig.hammock.transform))
                rows.append(["outfit": outfit.rawValue, "mode": mode, "anglesRadians": angles,
                             "pivot": [rig.currentRegistration.attachment.x, rig.currentRegistration.attachment.y],
                             "scope": "existing rigid foreground sway, not two fixed rope endpoints or independent sip"])
            }
            rig.root.removeFromSuperlayer()
        }
        try report(rows, name: "fourteen-vacation-day-night-observations")
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
