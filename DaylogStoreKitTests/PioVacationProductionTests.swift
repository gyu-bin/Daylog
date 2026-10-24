#if os(iOS)
import XCTest
import UIKit
import QuartzCore
@testable import Daylog

/// Local artwork/lifecycle checks; no StoreKit transaction or entitlement writes.
@MainActor final class PioVacationProductionTests: XCTestCase {
    func testBasicDayEyeResourcesAndLifecycle() throws {
        let rig = RoutimoriVacationRig(outfit: .basic)
        let bounds = CGRect(x: 0, y: 0, width: 220, height: 330)
        rig.layout(in: bounds, slot: nil, isDark: false, displayScale: 3)
        let eyes = try XCTUnwrap(rig.independentEyes)
        XCTAssertEqual(eyes.root.sublayers?.count, 6)
        XCTAssertTrue(eyes.root.superlayer === rig.hammock)
        XCTAssertFalse(eyes.root.isHidden)
        for eye in eyes.openEyes { XCTAssertNotNil(eye.contents) }
        rig.setAnimating(true); rig.setAnimating(true)
        XCTAssertEqual(eyes.animationCount, 4)
        rig.layout(in: bounds, slot: nil, isDark: true, displayScale: 3)
        XCTAssertTrue(eyes.root.isHidden); XCTAssertEqual(eyes.animationCount, 0)
        rig.layout(in: bounds, slot: nil, isDark: false, displayScale: 3)
        XCTAssertEqual(eyes.animationCount, 4)
        rig.setAnimating(false) // Existing Reduce Motion/offscreen path.
        XCTAssertEqual(eyes.animationCount, 0); XCTAssertNil(rig.hammock.animationKeys())
        XCTAssertTrue(eyes.openEyes.allSatisfy { $0.opacity == 0 })
        XCTAssertTrue(eyes.closedEyes.allSatisfy { $0.opacity == 1 })
        rig.setAnimating(true); rig.setCharacterVisible(false)
        XCTAssertEqual(eyes.animationCount, 0); XCTAssertNil(rig.hammock.animationKeys())
        for outfit in PioOutfitID.allCases where outfit != .basic {
            XCTAssertNil(RoutimoriVacationRig(outfit: outfit).independentEyes)
        }
    }

    func testBasicDayEyesActualUIKitPresentationAt64And220() async throws {
        let args = ProcessInfo.processInfo.arguments
        try XCTSkipUnless(args.contains("-PioVacationProductionReview") || args.contains("-PioCloudProductionReview"))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        for width: CGFloat in [64, 220] {
            let window = UIWindow(windowScene: scene)
            let controller = UIViewController(); window.rootViewController = controller; window.makeKeyAndVisible()
            let host = UIView(frame: CGRect(x: 0, y: 80, width: width, height: width * 1.5))
            controller.view.addSubview(host)
            let rig = RoutimoriVacationRig(outfit: .basic)
            host.layer.addSublayer(rig.root)
            defer { rig.setAnimating(false); rig.root.removeFromSuperlayer(); window.isHidden = true }
            let slot = CGRect(x: 0, y: width * 0.44, width: width, height: width * 0.56)
            rig.layout(in: host.bounds, slot: slot, isDark: false, displayScale: 3)
            let eyes = try XCTUnwrap(rig.independentEyes)
            CATransaction.flush()
            let closed = try capture(rig.root, bounds: host.bounds, name: "vacation-production-iOS-\(Int(width))pt-day-closed")
            rig.setAnimating(true); CATransaction.flush()
            let deadline = Date().addingTimeInterval(4)
            while (eyes.openEyes.first?.presentation()?.opacity ?? 0) < 0.95 && Date() < deadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTAssertGreaterThan(try XCTUnwrap(eyes.openEyes.first?.presentation()?.opacity), 0.95)
            let open = try capture(rig.root, bounds: host.bounds, name: "vacation-production-iOS-\(Int(width))pt-day-open")
            XCTAssertNotEqual(open, closed)
            XCTAssertFalse(window.isHidden); XCTAssertNotNil(host.window)
            rig.setAnimating(false); CATransaction.flush()
            XCTAssertEqual(eyes.animationCount, 0)
            let stopDeadline = Date().addingTimeInterval(1)
            while (eyes.openEyes.first?.presentation()?.opacity ?? 0) > 0.05 && Date() < stopDeadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTAssertLessThanOrEqual(eyes.openEyes.first?.presentation()?.opacity ?? 0, 0.05)
            _ = try capture(rig.root, bounds: host.bounds, name: "vacation-production-iOS-\(Int(width))pt-day-stopped")
            rig.layout(in: host.bounds, slot: slot, isDark: true, displayScale: 3)
            CATransaction.flush()
            XCTAssertTrue(eyes.root.isHidden)
            let nightDeadline = Date().addingTimeInterval(1)
            while eyes.root.presentation()?.isHidden == false && Date() < nightDeadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            _ = try capture(rig.root, bounds: host.bounds, name: "vacation-production-iOS-\(Int(width))pt-night-fallback")
        }
    }

    private func freeze(_ layer: CALayer) -> CALayer {
        let observed = layer.presentation() ?? layer
        let copy: CALayer
        if let gradient = layer as? CAGradientLayer {
            let g = CAGradientLayer()
            g.colors = gradient.colors; g.locations = gradient.locations
            g.startPoint = gradient.startPoint; g.endPoint = gradient.endPoint; g.type = gradient.type
            copy = g
        } else { copy = CALayer() }
        copy.bounds = observed.bounds; copy.position = observed.position
        copy.anchorPoint = observed.anchorPoint; copy.anchorPointZ = observed.anchorPointZ
        copy.transform = observed.transform; copy.sublayerTransform = observed.sublayerTransform
        copy.opacity = observed.opacity; copy.isHidden = observed.isHidden; copy.zPosition = observed.zPosition
        copy.contents = layer.contents; copy.contentsRect = layer.contentsRect
        copy.contentsGravity = layer.contentsGravity; copy.contentsScale = layer.contentsScale
        copy.isGeometryFlipped = layer.isGeometryFlipped; copy.masksToBounds = layer.masksToBounds
        copy.backgroundColor = layer.backgroundColor; copy.cornerRadius = layer.cornerRadius
        copy.minificationFilter = layer.minificationFilter; copy.magnificationFilter = layer.magnificationFilter
        copy.sublayers = layer.sublayers?.map { freeze($0) }
        copy.mask = layer.mask.map { freeze($0) }
        return copy
    }

    private func capture(_ layer: CALayer, bounds: CGRect, name: String) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: Int(bounds.width * 3), height: Int(bounds.height * 3),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.scaleBy(x: 3, y: 3)
        context.translateBy(x: 0, y: bounds.height); context.scaleBy(x: 1, y: -1)
        freeze(layer).render(in: context)
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let visible = stride(from: 3, to: context.height * context.bytesPerRow, by: 4)
            .reduce(0) { $0 + (bytes[$1] > 0 ? 1 : 0) }
        XCTAssertGreaterThan(visible, context.width * context.height / 2, "Reject transparent snapshot failures")
        let png = try XCTUnwrap(UIImage(cgImage: try XCTUnwrap(context.makeImage())).pngData())
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        if let directory = ProcessInfo.processInfo.environment["PIO_VACATION_PRODUCTION_REVIEW_OUTPUT"] {
            let url = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try png.write(to: url.appendingPathComponent(name + ".png"), options: .atomic)
        }
        return png
    }
}
#endif
