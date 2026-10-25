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

@MainActor final class PioVacationHingeNativeTests: XCTestCase {
    func testBasicDayNightHingeKeepsBothVisibleSourcePointsFixed() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioVacationHingeReview"))
        var rows: [[String: Any]] = []
        for width: CGFloat in [64, 220] {
            let host = try Host(size: CGSize(width: width, height: width * 1.5))
            let visibleDeadline = CACurrentMediaTime() + 8
            while !host.visible && CACurrentMediaTime() < visibleDeadline { try await Task.sleep(for: .milliseconds(16)) }
            defer { host.close() }
            let rig = RoutimoriVacationRig(outfit: .basic, independentlyAnimatesBasicNightEyes: true,
                                           independentlyAnchorsBasicRopes: true)
            host.layer.addSublayer(rig.root)
            for dark in [false, true] {
                rig.layout(in: host.bounds, slot: CGRect(x: 0, y: width * 0.5, width: width, height: width * 0.52),
                           isDark: dark, displayScale: 3)
                let hinge = try XCTUnwrap(rig.activeHinge)
                XCTAssertEqual(rig.hammock.position, hinge.fixedPoint)
                rig.setAnimating(true); CATransaction.flush()
                var motion: [Double] = []
                var maximumError: CGFloat = 0
                for (index, delay) in [0.1, 1.8, 1.9].enumerated() {
                    try await Task.sleep(for: .seconds(delay))
                    let pose = try XCTUnwrap(rig.hammock.presentation())
                    for point in [hinge.fixedPoint, hinge.otherPoint] {
                        let projected = hinge.projected(point, through: pose.transform)
                        let error = hypot(point.x - projected.x, point.y - projected.y)
                        maximumError = max(error, maximumError)
                        XCTAssertLessThan(error, 0.05, "Both visible source attachment points must stay fixed")
                    }
                    let center = hinge.projected(CGPoint(x: 512, y: 820), through: pose.transform)
                    motion.append(Double(center.x))
                    try capture(host, name: "hinge-basic-\(dark ? "night" : "day")-\(Int(width))pt-actual-\(index)")
                }
                XCTAssertGreaterThan((motion.max() ?? 0) - (motion.min() ?? 0), 0.1)
                rig.setAnimating(false); CATransaction.flush()
                XCTAssertNil(rig.hammock.animationKeys())
                XCTAssertTrue(CATransform3DIsIdentity(rig.hammock.transform))
                rows.append(["night": dark, "width": width, "maxSourcePointError": maximumError,
                             "centerPresentationX": motion, "scope": "Basic original two visible rope attachment/entry pixels; not hidden knot reconstruction or paid outfit proof"])
            }
            rig.root.removeFromSuperlayer()
        }
        try report(rows, name: "basic-two-source-point-native-projection")
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
