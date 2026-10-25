import XCTest
import QuartzCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import Daylog

/// Opt-in artwork QA. Does not grant ownership or modify production records.
@MainActor final class PioVacationNightArtworkTests: XCTestCase {
    func testNightCandidateResourcesAndLifecycle() throws {
        let rig = RoutimoriVacationRig(outfit: .basic)
        let eyes = try XCTUnwrap(rig.independentNightEyes)
        let dayEyes = try XCTUnwrap(rig.independentEyes)
        let bounds = CGRect(x: 0, y: 0, width: 220, height: 330)
        rig.layout(in: bounds, slot: nil, isDark: true, displayScale: 3)
        XCTAssertFalse(eyes.root.isHidden); XCTAssertTrue(dayEyes.root.isHidden)
        XCTAssertEqual(eyes.root.sublayers?.count, 8)
        XCTAssertTrue(eyes.root.superlayer === rig.hammock)
        rig.setAnimating(true); rig.setAnimating(true)
        XCTAssertEqual(eyes.animationCount, 6); XCTAssertEqual(dayEyes.animationCount, 0)
        rig.layout(in: bounds, slot: nil, isDark: false, displayScale: 3)
        XCTAssertTrue(eyes.root.isHidden); XCTAssertEqual(eyes.animationCount, 0)
        XCTAssertEqual(dayEyes.animationCount, 4)
        rig.layout(in: bounds, slot: nil, isDark: true, displayScale: 3)
        XCTAssertEqual(eyes.animationCount, 6)
        rig.setAnimating(false)
        XCTAssertEqual(eyes.animationCount, 0)
        XCTAssertTrue(eyes.openEyes.allSatisfy { $0.opacity == 0 })
        XCTAssertTrue(eyes.halfEyes.allSatisfy { $0.opacity == 0 })
        XCTAssertTrue(eyes.closedEyes.allSatisfy { $0.opacity == 1 })
        rig.setAnimating(true); rig.setCharacterVisible(false)
        XCTAssertEqual(eyes.animationCount, 0)
        for outfit in PioOutfitID.allCases where outfit != .basic && outfit != .christmas && outfit != .winter {
            XCTAssertNil(RoutimoriVacationRig(outfit: outfit, independentlyAnimatesBasicNightEyes: true).independentNightEyes)
        }
        XCTAssertNil(RoutimoriVacationRig(outfit: .basic, independentlyAnimatesBasicNightEyes: false).independentNightEyes)
        XCTAssertNil(RoutimoriVacationRig(outfit: .christmas, independentlyAnimatesChristmasNightEyes: false).independentNightEyes)
    }

    func testNightCandidateNativePresentationAt64And220() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioVacationNightReview"))
        for width: CGFloat in [64, 220] {
            let bounds = CGRect(x: 0, y: 0, width: width, height: width * 1.5)
            #if os(macOS)
            let host = NSView(frame: bounds); host.wantsLayer = true
            let window = NSWindow(contentRect: bounds, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.contentView = host; window.orderFront(nil)
            let hostLayer = try XCTUnwrap(host.layer)
            #else
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            let controller = UIViewController(); window.rootViewController = controller; window.makeKeyAndVisible()
            let host = UIView(frame: bounds.offsetBy(dx: 0, dy: 80)); controller.view.addSubview(host)
            let hostLayer = host.layer
            #endif
            let rig = RoutimoriVacationRig(outfit: .basic)
            hostLayer.addSublayer(rig.root)
            defer {
                rig.setAnimating(false); rig.root.removeFromSuperlayer()
                #if os(macOS)
                window.close()
                #else
                window.isHidden = true
                #endif
            }
            rig.layout(in: bounds, slot: CGRect(x: 0, y: width * 0.5, width: width, height: width * 0.52), isDark: true, displayScale: 3)
            let eyes = try XCTUnwrap(rig.independentNightEyes)
            CATransaction.flush()
            let closed = try capture(rig.root, bounds: bounds, name: "vacation-night-\(Int(width))pt-closed")
            rig.setAnimating(true); CATransaction.flush()
            for (name, target) in [("half", eyes.halfEyes), ("open", eyes.openEyes)] {
                let deadline = Date().addingTimeInterval(4)
                while (target.first?.presentation()?.opacity ?? 0) < 0.95 && Date() < deadline {
                    try await Task.sleep(for: .milliseconds(10))
                }
                XCTAssertGreaterThan(try XCTUnwrap(target.first?.presentation()?.opacity), 0.95)
                let frame = try capture(rig.root, bounds: bounds, name: "vacation-night-\(Int(width))pt-" + name)
                XCTAssertNotEqual(frame, closed)
            }
            rig.setAnimating(false); CATransaction.flush()
            let deadline = Date().addingTimeInterval(1)
            while (eyes.openEyes.first?.presentation()?.opacity ?? 0) > 0.05 && Date() < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertEqual(eyes.animationCount, 0)
            _ = try capture(rig.root, bounds: bounds, name: "vacation-night-\(Int(width))pt-stopped")
        }
    }

    func testNightCandidate1024StaticRegistration() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioVacationNightReview"))
        let rig = RoutimoriVacationRig(outfit: .basic)
        let bounds = CGRect(x: 0, y: 0, width: 1024, height: 1536)
        rig.layout(in: bounds, slot: CGRect(x: 0, y: 589, width: 1024, height: 512), isDark: true, displayScale: 1)
        let eyes = try XCTUnwrap(rig.independentNightEyes)
        for mode in ["original", "clean", "open", "half", "closed"] {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            eyes.root.isHidden = mode == "original"
            for layer in eyes.openEyes { layer.opacity = mode == "open" ? 1 : 0 }
            for layer in eyes.halfEyes { layer.opacity = mode == "half" ? 1 : 0 }
            for layer in eyes.closedEyes { layer.opacity = mode == "closed" ? 1 : 0 }
            CATransaction.commit()
            _ = try capture(rig.root, bounds: bounds, name: "vacation-night-1024pt-" + mode, scale: 1)
        }
    }
    func testChristmasNightProductionLifecycleAndPresentation() async throws {
        try await reviewProduction(outfit: .christmas, night: true, rootName: "christmasNightIndependentEyes", stem: "christmas")
    }

    func testChristmasDayProductionLifecycleAndPresentation() async throws {
        XCTAssertNil(RoutimoriVacationRig(outfit: .christmas, independentlyAnimatesChristmasDayEyes: false).independentEyes)
        try await reviewProduction(outfit: .christmas, night: false, rootName: "christmasDayIndependentEyes", stem: "christmas-day")
    }

    func testWinterNightProductionLifecycleAndPresentation() async throws {
        XCTAssertNil(RoutimoriVacationRig(outfit: .winter, independentlyAnimatesWinterNightEyes: false).independentNightEyes)
        try await reviewProduction(outfit: .winter, night: true, rootName: "winterNightIndependentEyes", stem: "winter-night")
    }

    private func reviewProduction(outfit: PioOutfitID, night: Bool, rootName: String, stem: String) async throws {
        let resources = RoutimoriVacationRig(outfit: outfit)
        let registered = try XCTUnwrap(night ? resources.independentNightEyes : resources.independentEyes)
        XCTAssertEqual(registered.root.name, rootName)
        XCTAssertEqual(registered.root.sublayers?.count, 6)
        XCTAssertTrue(registered.halfEyes.isEmpty)
        resources.layout(in: CGRect(x: 0, y: 0, width: 220, height: 330), slot: nil, isDark: night, displayScale: 3)
        resources.setAnimating(true)
        XCTAssertEqual(registered.animationCount, 4)
        resources.layout(in: CGRect(x: 0, y: 0, width: 220, height: 330), slot: nil, isDark: !night, displayScale: 3)
        XCTAssertTrue(registered.root.isHidden); XCTAssertEqual(registered.animationCount, 0)
        resources.setAnimating(false)
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioVacationNightReview"))
        for width: CGFloat in [64, 220] {
            let bounds = CGRect(x: 0, y: 0, width: width, height: width * 1.5)
            #if os(macOS)
            let host = NSView(frame: bounds); host.wantsLayer = true
            let window = NSWindow(contentRect: bounds, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.contentView = host; window.orderFront(nil)
            let hostLayer = try XCTUnwrap(host.layer)
            #else
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            let controller = UIViewController(); window.rootViewController = controller; window.makeKeyAndVisible()
            let host = UIView(frame: bounds.offsetBy(dx: 0, dy: 80)); controller.view.addSubview(host)
            let hostLayer = host.layer
            #endif
            let rig = RoutimoriVacationRig(outfit: outfit)
            hostLayer.addSublayer(rig.root)
            defer {
                rig.setAnimating(false); rig.root.removeFromSuperlayer()
                #if os(macOS)
                window.close()
                #else
                window.isHidden = true
                #endif
            }
            rig.layout(in: bounds, slot: CGRect(x: 0, y: width * 0.5, width: width, height: width * 0.52), isDark: night, displayScale: 3)
            let eyes = try XCTUnwrap(night ? rig.independentNightEyes : rig.independentEyes)
            CATransaction.flush()
            let closed = try capture(rig.root, bounds: bounds, name: "vacation-\(stem)-production-\(Int(width))pt-closed")
            rig.setAnimating(true); CATransaction.flush()
            let deadline = Date().addingTimeInterval(4)
            while (eyes.openEyes.first?.presentation()?.opacity ?? 0) < 0.95 && Date() < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertGreaterThan(try XCTUnwrap(eyes.openEyes.first?.presentation()?.opacity), 0.95)
            XCTAssertEqual(eyes.animationCount, 4)
            let open = try capture(rig.root, bounds: bounds, name: "vacation-\(stem)-production-\(Int(width))pt-open")
            XCTAssertNotEqual(open, closed)
            rig.setAnimating(false); CATransaction.flush()
            let stopDeadline = Date().addingTimeInterval(1)
            while (eyes.openEyes.first?.presentation()?.opacity ?? 0) > 0.05 && Date() < stopDeadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertEqual(eyes.animationCount, 0)
            XCTAssertTrue(eyes.openEyes.allSatisfy { $0.opacity == 0 })
            XCTAssertTrue(eyes.closedEyes.allSatisfy { $0.opacity == 1 })
            _ = try capture(rig.root, bounds: bounds, name: "vacation-\(stem)-production-\(Int(width))pt-stopped")
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

    private func capture(_ layer: CALayer, bounds: CGRect, name: String, scale: CGFloat = 3) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: Int(bounds.width * scale), height: Int(bounds.height * scale),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: 0, y: bounds.height); context.scaleBy(x: 1, y: -1)
        freeze(layer).render(in: context)
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let visible = stride(from: 3, to: context.height * context.bytesPerRow, by: 4)
            .reduce(0) { $0 + (bytes[$1] > 0 ? 1 : 0) }
        XCTAssertGreaterThan(visible, context.width * context.height / 2, "Reject transparent snapshot failures")
        let image = try XCTUnwrap(context.makeImage())
        #if os(macOS)
        let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        #else
        let png = try XCTUnwrap(UIImage(cgImage: image).pngData())
        #endif
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        if let directory = ProcessInfo.processInfo.environment["PIO_VACATION_NIGHT_REVIEW_OUTPUT"] {
            let url = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try png.write(to: url.appendingPathComponent(name + ".png"), options: .atomic)
        }
        return png
    }
}
