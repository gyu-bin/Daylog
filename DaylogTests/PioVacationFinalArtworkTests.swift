#if DEBUG && os(macOS)
import XCTest
import AppKit
import QuartzCore
@testable import Daylog

/// Opt-in artwork diagnostic; no production entitlement or renderer is changed.
@MainActor final class PioVacationFinalArtworkTests: XCTestCase {
    private let eyeRects = [CGRect(x: 422, y: 688, width: 58, height: 44),
                            CGRect(x: 531, y: 647, width: 54, height: 43)]
    private var project: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    func testBasicDayProductionEyesPreserveNightPaidAndLifecycle() throws {
        let rig = RoutimoriVacationRig(outfit: .basic)
        let bounds = CGRect(x: 0, y: 0, width: 220, height: 330)
        rig.layout(in: bounds, slot: nil, isDark: false, displayScale: 2)
        let eyes = try XCTUnwrap(rig.independentEyes)
        XCTAssertFalse(eyes.root.isHidden)
        XCTAssertTrue(eyes.root.superlayer === rig.hammock)
        XCTAssertEqual(eyes.root.sublayers?.count, 6)
        rig.setAnimating(true); rig.setAnimating(true)
        XCTAssertEqual(eyes.animationCount, 4)
        XCTAssertEqual(rig.hammock.animationKeys()?.count, 1)
        rig.layout(in: bounds, slot: nil, isDark: true, displayScale: 2)
        XCTAssertTrue(eyes.root.isHidden); XCTAssertEqual(eyes.animationCount, 0)
        rig.layout(in: bounds, slot: nil, isDark: false, displayScale: 2)
        XCTAssertFalse(eyes.root.isHidden); XCTAssertEqual(eyes.animationCount, 4)
        rig.setAnimating(false)
        XCTAssertEqual(eyes.animationCount, 0)
        XCTAssertTrue(eyes.openEyes.allSatisfy { $0.opacity == 0 })
        XCTAssertTrue(eyes.closedEyes.allSatisfy { $0.opacity == 1 })
        rig.setAnimating(true); rig.setCharacterVisible(false)
        XCTAssertEqual(eyes.animationCount, 0); XCTAssertNil(rig.hammock.animationKeys())
        // 기본 낮 눈 조각을 다른 의상에 쓰지 않는다. 크리스마스 낮만 자기 전용으로 검증된 눈 조각을 쓴다
        // (2026-10-24 최종 점검에서 추가, 검증: DaylogStoreKitTests/PioVacationNightArtworkTests.testChristmasDayProductionLifecycleAndPresentation).
        for outfit in PioOutfitID.allCases where outfit != .basic {
            let eyes = RoutimoriVacationRig(outfit: outfit).independentEyes
            if outfit == .christmas {
                XCTAssertNotNil(eyes, "Christmas day uses its own verified production eye patches")
            } else {
                XCTAssertNil(eyes, "No unverified Basic patches on \(outfit)")
            }
        }
    }

    func testBasicDayProductionEyesNativePlayback() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioVacationFinalArtworkReview"))
        let (rig, host, window) = makeNativeHost(width: 220, productionEyes: true)
        defer { rig.setAnimating(false); rig.root.removeFromSuperlayer(); window.orderOut(nil); window.close() }
        let eyes = try XCTUnwrap(rig.independentEyes)
        rig.setAnimating(true); CATransaction.flush()
        var observedOpen = false, observedClosed = false
        var frames = Set<Data>()
        for index in 0..<96 {
            try await Task.sleep(for: .milliseconds(100))
            let opacity = eyes.openEyes.first?.presentation()?.opacity ?? 0
            observedOpen = observedOpen || opacity > 0.95
            observedClosed = observedClosed || opacity < 0.05
            frames.insert(try capturePresentation(rig.root, bounds: host.bounds,
                name: String(format: "vacation-basic-day-production-%03d", index)))
        }
        XCTAssertTrue(observedOpen); XCTAssertTrue(observedClosed)
        XCTAssertGreaterThan(frames.count, 1)
        XCTAssertTrue(window.isVisible)
        rig.setAnimating(false)
        XCTAssertEqual(eyes.animationCount, 0); XCTAssertNil(rig.hammock.animationKeys())
        _ = try capturePresentation(rig.root, bounds: host.bounds, name: "vacation-basic-day-production-stopped")
    }

    func testNativePreciselyReconstructedEyeRegions() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioVacationFinalArtworkReview"))
        let candidate = try source("output/pio-production-final-2026-10-24/vacation/basic-day-eye-free-candidate-v1.png")
        let original = try source("Daylog/RoutimoriTrial.xcassets/routimori_vacation_hammock.imageset/routimori_vacation_hammock.png")
        XCTAssertEqual(candidate.width, 1024); XCTAssertEqual(candidate.height, 1536)
        for width: CGFloat in [64, 220, 1024] {
            for mode in ["original", "clean-regions", "original-closed", "open-eyes"] {
                let (rig, host, window) = makeNativeHost(width: width)
                defer { rig.setAnimating(false); rig.root.removeFromSuperlayer(); window.orderOut(nil); window.close() }
                if mode != "original" {
                    for rect in eyeRects { rig.hammock.addSublayer(sample(candidate, rect: rect)) }
                    if mode == "original-closed" {
                        for rect in eyeRects { rig.hammock.addSublayer(sample(original, rect: rect)) }
                    } else if mode == "open-eyes" {
                        for eye in try openEyes() { rig.hammock.addSublayer(eye) }
                    }
                }
                host.layoutSubtreeIfNeeded(); CATransaction.flush()
                try capture(host, name: "vacation-day-\(Int(width))pt-\(mode)-final-art-diagnostic")
                XCTAssertTrue(window.isVisible)
                XCTAssertNil(rig.hammock.animationKeys())
            }
        }
    }

    func testNativeEyeCandidateActualPresentationSequence() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioVacationFinalArtworkReview"))
        let candidate = try source("output/pio-production-final-2026-10-24/vacation/basic-day-eye-free-candidate-v1.png")
        let original = try source("Daylog/RoutimoriTrial.xcassets/routimori_vacation_hammock.imageset/routimori_vacation_hammock.png")
        let (rig, host, window) = makeNativeHost(width: 220)
        defer { rig.setAnimating(false); rig.root.removeFromSuperlayer(); window.orderOut(nil); window.close() }
        for rect in eyeRects { rig.hammock.addSublayer(sample(candidate, rect: rect)) }
        let opens = try openEyes()
        let closeds = eyeRects.map { sample(original, rect: $0) }
        for layer in opens + closeds { rig.hammock.addSublayer(layer) }
        // Authored neutral remains smiling/closed; a brief open and return proves
        // independent texture visibility, not a production timing/style approval.
        for layer in opens {
            layer.opacity = 0
            let a = CAKeyframeAnimation(keyPath: "opacity")
            a.values = [0, 0, 1, 1, 0, 0]; a.keyTimes = [0, 0.15, 0.2, 0.65, 0.7, 1]
            a.duration = 2; a.isRemovedOnCompletion = false; a.fillMode = .forwards
            layer.add(a, forKey: "diagnosticOpen")
        }
        for layer in closeds {
            let a = CAKeyframeAnimation(keyPath: "opacity")
            a.values = [1, 1, 0, 0, 1, 1]; a.keyTimes = [0, 0.15, 0.2, 0.65, 0.7, 1]
            a.duration = 2; a.isRemovedOnCompletion = false; a.fillMode = .forwards
            layer.add(a, forKey: "diagnosticClosed")
        }
        CATransaction.flush()
        var observedOpen = false, observedClosed = false
        var frames = Set<Data>()
        for index in 0..<44 {
            // A capture cadence, not a delayed assertion or production workaround.
            try await Task.sleep(for: .milliseconds(50))
            host.layoutSubtreeIfNeeded(); CATransaction.flush()
            let opacity = opens.first?.presentation()?.opacity ?? 0
            observedOpen = observedOpen || opacity > 0.95
            observedClosed = observedClosed || opacity < 0.05
            frames.insert(try capturePresentation(rig.root, bounds: host.bounds,
                                    name: String(format: "vacation-eye-presentation-%03d", index)))
        }
        XCTAssertTrue(observedOpen); XCTAssertTrue(observedClosed)
        XCTAssertGreaterThan(frames.count, 1, "A sequence of identical closed-eye frames is not animation evidence")
        XCTAssertTrue(window.isVisible)
        for layer in opens + closeds { layer.removeAllAnimations() }
        XCTAssertTrue((opens + closeds).allSatisfy { $0.animationKeys() == nil })
    }

    private func makeNativeHost(width: CGFloat, productionEyes: Bool = false) -> (RoutimoriVacationRig, NSView, NSWindow) {
        let bounds = CGRect(x: 0, y: 0, width: width, height: width * 1.5)
        let rig = RoutimoriVacationRig(outfit: .basic, independentlyAnimatesBasicDayEyes: productionEyes)
        rig.layout(in: bounds, slot: CGRect(x: 0, y: width * 0.44, width: width, height: width * 0.56), isDark: false, displayScale: 2)
        rig.setAnimating(false)
        let host = NSView(frame: bounds); host.wantsLayer = true
        let window = NSWindow(contentRect: bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        host.layer!.addSublayer(rig.root); window.orderFront(nil)
        return (rig, host, window)
    }

    private func source(_ path: String) throws -> CGImage {
        try XCTUnwrap(NSImage(contentsOf: project.appendingPathComponent(path))?
            .cgImage(forProposedRect: nil, context: nil, hints: nil))
    }

    private func sample(_ image: CGImage, rect: CGRect) -> CALayer {
        let layer = CALayer(); layer.contents = image; layer.contentsGravity = .resize
        // This vacation tree inherits root.isGeometryFlipped=true. Unlike the
        // unflipped cloud host, its texture sampler uses the source top-left Y.
        // A second Y conversion sampled mouth/straw pixels in the first capture.
        layer.contentsRect = CGRect(x: rect.minX / 1024, y: rect.minY / 1536,
                                    width: rect.width / 1024, height: rect.height / 1536)
        layer.frame = rect; layer.contentsScale = 2; layer.minificationFilter = .trilinear
        return layer
    }

    private func openEyes() throws -> [CALayer] {
        let names = ["pio_overhaul_basic_eyeLeft", "pio_overhaul_basic_eyeRight"]
        let slots = [CGRect(x: 431, y: 687, width: 37.8, height: 43.8),
                     CGRect(x: 540, y: 647, width: 35.2, height: 40.8)]
        return try zip(names, slots).map { name, slot in
            let layer = CALayer(); layer.frame = slot; layer.contentsGravity = .resizeAspect
            layer.contents = try XCTUnwrap(NSImage(named: name)?.cgImage(forProposedRect: nil, context: nil, hints: nil))
            layer.contentsScale = 2; layer.minificationFilter = .trilinear
            return layer
        }
    }

    private func capture(_ host: NSView, name: String) throws {
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try save(png, name: name)
    }

    private func capturePresentation(_ layer: CALayer, bounds: CGRect, name: String) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: Int(bounds.width * 3), height: Int(bounds.height * 3),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.scaleBy(x: 3, y: 3)
        context.translateBy(x: 0, y: bounds.height); context.scaleBy(x: 1, y: -1)
        // render(in:) does not reliably honor nested presentation animation.
        // Freeze each observed live layer into a separate diagnostic snapshot.
        freezePresentation(layer).render(in: context)
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let visible = stride(from: 3, to: context.height * context.bytesPerRow, by: 4)
            .reduce(0) { $0 + (bytes[$1] > 0 ? 1 : 0) }
        XCTAssertGreaterThan(visible, context.width * context.height / 2, "A blank capture is not rendered evidence")
        let image = try XCTUnwrap(context.makeImage())
        let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try save(png, name: name)
        return png
    }

    private func freezePresentation(_ layer: CALayer) -> CALayer {
        let current = layer.presentation() ?? layer
        let copy: CALayer
        if let gradient = layer as? CAGradientLayer {
            let g = CAGradientLayer()
            g.colors = gradient.colors; g.locations = gradient.locations
            g.startPoint = gradient.startPoint; g.endPoint = gradient.endPoint; g.type = gradient.type
            copy = g
        } else { copy = CALayer() }
        // init(layer:) is Core Animation's subclass presentation-copy hook, not
        // an application snapshot initializer. Explicitly retain static content.
        copy.bounds = current.bounds; copy.position = current.position
        copy.anchorPoint = current.anchorPoint; copy.anchorPointZ = current.anchorPointZ
        copy.transform = current.transform; copy.sublayerTransform = current.sublayerTransform
        copy.opacity = current.opacity; copy.isHidden = current.isHidden
        copy.zPosition = current.zPosition
        copy.contents = layer.contents; copy.contentsRect = layer.contentsRect
        copy.contentsGravity = layer.contentsGravity; copy.contentsScale = layer.contentsScale
        copy.isGeometryFlipped = layer.isGeometryFlipped; copy.masksToBounds = layer.masksToBounds
        copy.backgroundColor = layer.backgroundColor; copy.cornerRadius = layer.cornerRadius
        copy.minificationFilter = layer.minificationFilter; copy.magnificationFilter = layer.magnificationFilter
        copy.sublayers = layer.sublayers?.map { freezePresentation($0) }
        copy.mask = layer.mask.map { freezePresentation($0) }
        return copy
    }

    private func save(_ png: Data, name: String) throws {
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        if let directory = ProcessInfo.processInfo.environment["PIO_VACATION_FINAL_REVIEW_OUTPUT"] {
            let output = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try png.write(to: output.appendingPathComponent(name + ".png"), options: .atomic)
        }
    }
}
#endif
