#if DEBUG && os(macOS)
import XCTest
import AppKit
import QuartzCore
@testable import Daylog

/// Diagnostic only: never substitutes candidate artwork in the running app.
@MainActor final class PioVacationCandidateArtworkTests: XCTestCase {
    func testNativeEyePatchRegistrationCandidates() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioVacationCandidateReview"))
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let file = project.appendingPathComponent("output/pio-independent-2026-10-24/vacation/basic-day-eye-fur-patches-candidate-v3.png")
        let image = try XCTUnwrap(NSImage(contentsOf: file)?.cgImage(forProposedRect: nil, context: nil, hints: nil))
        XCTAssertEqual(image.width, 1024); XCTAssertEqual(image.height, 1536)
        for width: CGFloat in [64, 220, 1024] {
            for mode in ["original", "raw-patch", "registered-patch", "registered-open-eyes"] {
                let bounds = CGRect(x: 0, y: 0, width: width, height: width * 1.5)
                let rig = RoutimoriVacationRig(outfit: .basic)
                // Keep approved day artwork/registration and actual existing compositing tree.
                rig.layout(in: bounds, slot: CGRect(x: 0, y: width * 0.44, width: width, height: width * 0.56), isDark: false, displayScale: 2)
                rig.setAnimating(false)
                if mode != "original" {
                    let patch = CALayer(); patch.contents = image; patch.contentsGravity = .resize
                    if mode == "raw-patch" { patch.frame = CGRect(x: 0, y: 0, width: 1024, height: 1536) }
                    else { patch.frame = CGRect(x: 112, y: 122, width: 1024 * 0.77, height: 1536 * 0.77) }
                    rig.hammock.addSublayer(patch)
                    if mode == "registered-open-eyes" {
                        for (name, frame) in [("pio_overhaul_basic_eyeLeft", CGRect(x: 431, y: 689, width: 40, height: 44)), ("pio_overhaul_basic_eyeRight", CGRect(x: 538, y: 649, width: 38, height: 43))] {
                            let eye = CALayer(); eye.frame = frame
                            eye.contents = try XCTUnwrap(NSImage(named: name)?.cgImage(forProposedRect: nil, context: nil, hints: nil))
                            eye.contentsGravity = .resizeAspect; rig.hammock.addSublayer(eye)
                        }
                    }
                }
                let host = NSView(frame: bounds); host.wantsLayer = true
                let window = NSWindow(contentRect: bounds, styleMask: [.titled], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false; window.contentView = host
                host.layer!.addSublayer(rig.root); window.orderFront(nil)
                host.layoutSubtreeIfNeeded(); CATransaction.flush()
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
                attachment.name = "vacation-day-\(Int(width))pt-\(mode)-diagnostic"
                attachment.lifetime = .keepAlways; add(attachment)
                rig.root.removeFromSuperlayer(); window.orderOut(nil); window.close()
                XCTAssertNil(rig.hammock.animationKeys())
            }
        }
    }
}
#endif
