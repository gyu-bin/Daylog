#if os(macOS)
import XCTest
import QuartzCore
import AppKit
@testable import Daylog

/// Source-art registration review only. Never grants an outfit entitlement.
@MainActor final class PioVacationComponentArtworkTests: XCTestCase {
    func testChristmasNightEyeRegistration() throws {
        try review(outfit: .christmas, night: true, stem: "christmas-night",
            cleanRects: [CGRect(x: 435, y: 743, width: 78, height: 72), CGRect(x: 574, y: 704, width: 71, height: 62)],
            sources: [CGRect(x: 452, y: 749, width: 45, height: 53), CGRect(x: 576, y: 708, width: 40, height: 51)],
            targets: [CGRect(x: 450.5, y: 755, width: 45, height: 53), CGRect(x: 588, y: 712, width: 40, height: 51)])
    }

    func testChristmasDayEyeRegistration() throws {
        try review(outfit: .christmas, night: false, stem: "christmas-day",
            cleanRects: [CGRect(x: 441, y: 720, width: 65, height: 57), CGRect(x: 553, y: 682, width: 61, height: 50)],
            sources: [CGRect(x: 450, y: 723, width: 48, height: 48), CGRect(x: 557, y: 686, width: 43, height: 46)],
            targets: [CGRect(x: 450, y: 727.5, width: 48, height: 48), CGRect(x: 562.5, y: 686, width: 43, height: 46)])
    }

    func testWinterNightEyeRegistration() throws {
        try review(outfit: .winter, night: true, stem: "winter-night",
            cleanRects: [CGRect(x: 446, y: 802, width: 77, height: 65), CGRect(x: 588, y: 756, width: 69, height: 57)],
            sources: [CGRect(x: 458, y: 803, width: 58, height: 60), CGRect(x: 592, y: 761, width: 47, height: 51)],
            targets: [CGRect(x: 455.5, y: 806.5, width: 58, height: 60), CGRect(x: 599, y: 758.5, width: 47, height: 51)])
    }

    private func review(outfit: PioOutfitID, night: Bool, stem: String,
                        cleanRects: [CGRect], sources: [CGRect], targets: [CGRect]) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioVacationComponentReview"))
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let output = project.appendingPathComponent("output/pio-character-final-pass-2026-10-24/vacation")
        func load(_ name: String) throws -> CGImage {
            let image = try XCTUnwrap(NSImage(contentsOf: output.appendingPathComponent(name)))
            return try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        }
        let clean = try load(stem + "-clean-eyes-v1.png")
        let open = try load(stem + "-open-eyes-v1.png")
        XCTAssertEqual(clean.width, 1024); XCTAssertEqual(clean.height, 1536)
        XCTAssertEqual(open.width, 1024); XCTAssertEqual(open.height, 1536)
        func sample(_ image: CGImage, source: CGRect, target: CGRect? = nil) -> CALayer {
            let layer = CALayer(); layer.contents = image; layer.frame = target ?? source
            layer.contentsGravity = .resize; layer.minificationFilter = .trilinear
            layer.contentsRect = CGRect(x: source.minX / 1024, y: source.minY / 1536,
                width: source.width / 1024, height: source.height / 1536)
            return layer
        }
        for width: CGFloat in [64, 220, 1024] {
            let rig = RoutimoriVacationRig(outfit: outfit, independentlyAnimatesBasicDayEyes: false,
                independentlyAnimatesBasicNightEyes: false, independentlyAnimatesChristmasNightEyes: false,
                independentlyAnimatesChristmasDayEyes: false, independentlyAnimatesWinterNightEyes: false,
                independentlyAnchorsBasicRopes: false)
            let bounds = CGRect(x: 0, y: 0, width: width, height: width * 1.5)
            rig.layout(in: bounds, slot: CGRect(x: 0, y: width * 0.5, width: width, height: width * 0.52),
                isDark: night, displayScale: width == 1024 ? 1 : 3)
            let patches = CALayer(); patches.frame = CGRect(x: 0, y: 0, width: 1024, height: 1536)
            let cleanLayers = cleanRects.map { sample(clean, source: $0) }
            let openLayers = zip(sources, targets).map { sample(open, source: $0.0, target: $0.1) }
            for layer in cleanLayers + openLayers { patches.addSublayer(layer) }
            rig.hammock.addSublayer(patches)
            var original: Data?
            for mode in ["original", "clean", "open"] {
                CATransaction.begin(); CATransaction.setDisableActions(true)
                patches.isHidden = mode == "original"
                for layer in openLayers { layer.isHidden = mode != "open" }
                CATransaction.commit()
                let frame = try capture(rig.root, bounds: bounds,
                    name: "vacation-" + stem + "-\(Int(width))pt-" + mode,
                    scale: width == 1024 ? 1 : 3)
                if mode == "original" { original = frame } else { XCTAssertNotEqual(frame, original) }
            }
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
        if let directory = ProcessInfo.processInfo.environment["PIO_VACATION_COMPONENT_REVIEW_OUTPUT"] {
            let url = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try png.write(to: url.appendingPathComponent(name + ".png"), options: .atomic)
        }
        return png
    }
}
#endif
