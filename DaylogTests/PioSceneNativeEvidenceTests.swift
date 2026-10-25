#if DEBUG && os(macOS)
import XCTest
import AppKit
import QuartzCore
@testable import Daylog

/// Native scene snapshots, not reconstructed artwork; runs only when explicitly selected.
@MainActor final class PioSceneNativeEvidenceTests: XCTestCase {
    func testSustainedNativeLifecycleObservations() async throws {
        let stage = RoutimoriSyncStage()
        var records: [[String: Any]] = []
        func rss() -> UInt64 {
            var info = mach_task_basic_info();var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
            let result = withUnsafeMutablePointer(to: &info) { p in p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count) } }
            return result == KERN_SUCCESS ? UInt64(info.resident_size) : 0
        }
        let start = Date(); let initial = rss()
        var cycles = 0
        while Date().timeIntervalSince(start) < 60 {
            let outfit = PioOutfitID.allCases[cycles % PioOutfitID.allCases.count]
            stage.update(.init(kind: .receiving, height: 220, dark: false, scale: 2, reduceMotion: false, outfit: outfit, usesIndependentCharacter: true), isAnimating: true)
            CATransaction.flush()
            // Yield to the native run loop while observing a bounded stress interval, not waiting for an assertion by elapsed time.
            await Task.yield()
            stage.halt();cycles += 1
            if cycles % 100 == 0 { records.append(["cycles": cycles, "elapsed": Date().timeIntervalSince(start), "rss": rss()]) }
        }
        func count(_ layer: CALayer) -> Int { (layer.animationKeys()?.count ?? 0) + (layer.sublayers ?? []).reduce(0) { $0 + count($1) } }
        XCTAssertEqual(count(stage.root), 0)
        let report: [String: Any] = ["duration": Date().timeIntervalSince(start), "cycles": cycles, "initialRSS": initial, "finalRSS": rss(), "samples": records, "limits": "60-second retained-layer reconfiguration stress; not sustained visible animation, GPU energy, or long-term leak certification"]
        let a = XCTAttachment(data: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted,.sortedKeys]), uniformTypeIdentifier: "public.json");a.name = "scene-lifecycle-60s";a.lifetime = .keepAlways;add(a)
    }
    func testVacationNativeSnapshots() throws {
        for outfit in PioOutfitID.allCases {
            let rig = RoutimoriVacationRig(outfit: outfit)
            for dark in [false, true] {
                let bounds = CGRect(x: 0,y: 0,width: 402,height: 780)
                rig.layout(in: bounds, slot: CGRect(x: 20,y: 260,width: 362,height: 260), isDark: dark, displayScale: 2)
                rig.setAnimating(false)
                if outfit == .hanbok && dark {
                    let host = NSView(frame: bounds);host.wantsLayer = true
                    let window = NSWindow(contentRect: bounds, styleMask: [.titled], backing: .buffered, defer: false);window.isReleasedWhenClosed = false
                    window.contentView = host;host.layer!.addSublayer(rig.root);window.orderFront(nil)
                    host.layoutSubtreeIfNeeded();CATransaction.flush()
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds));host.cacheDisplay(in: host.bounds, to: bitmap)
                    let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]));let proof = XCTAttachment(data: png, uniformTypeIdentifier: "public.png");proof.name = "vacation-hanbok-night-AppKit-host";proof.lifetime = .keepAlways;add(proof)
                    rig.root.removeFromSuperlayer();window.orderOut(nil);window.close()
                }
                let context = try XCTUnwrap(CGContext(data: nil, width: 804, height: 1560, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.translateBy(x: 0,y: 1560);context.scaleBy(x: 2,y: -2);rig.root.render(in: context)
                let data = try XCTUnwrap(NSBitmapImageRep(cgImage: XCTUnwrap(context.makeImage())).representation(using: .png, properties: [:]))
                let a = XCTAttachment(data: data, uniformTypeIdentifier: "public.png");a.name = "vacation-\(outfit.rawValue)-\(dark ? "night" : "day")-native";a.lifetime = .keepAlways;add(a)
                CATransaction.begin();CATransaction.setDisableActions(true)
                for sign: CGFloat in [-1,1] {
                    rig.hammock.transform = CATransform3DMakeRotation(sign * rig.currentRegistration.swingDegrees * .pi / 180, 0,0,1)
                    let c = try XCTUnwrap(CGContext(data:nil,width:804,height:1560,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue))
                    c.translateBy(x:0,y:1560);c.scaleBy(x:2,y:-2);rig.root.render(in:c)
                    let d = try XCTUnwrap(NSBitmapImageRep(cgImage:XCTUnwrap(c.makeImage())).representation(using:.png,properties:[:]))
                    let e = XCTAttachment(data:d,uniformTypeIdentifier:"public.png");e.name = "vacation-\(outfit.rawValue)-\(dark ? "night" : "day")-model-extreme-\(Int(sign))";e.lifetime = .keepAlways;add(e)
                }
                rig.hammock.transform = CATransform3DIdentity
                CATransaction.commit()
                XCTAssertNil(rig.hammock.animationKeys())
            }
        }
    }
    func testCloudNativeSnapshotsAndStop() throws {
        for outfit in PioOutfitID.allCases {
        for kind in SyncSceneKind.allCases {
            for dark in [false, true] {
                let stage = RoutimoriSyncStage()
                stage.update(.init(kind: kind, height: 340, dark: dark, scale: 2, reduceMotion: true, outfit: outfit,
                    usesIndependentCharacter: kind == .ready || PioCloudSceneResources.hasSeatedLayers(outfit)), isAnimating: true)
                let context = try XCTUnwrap(CGContext(data: nil, width: 680, height: 680, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.setFillColor(CGColor(gray: dark ? 0.09 : 0.97, alpha: 1)); context.fill(CGRect(x: 0,y: 0,width:680,height:680));context.scaleBy(x: 2,y: 2)
                stage.root.render(in: context)
                let data = try XCTUnwrap(NSBitmapImageRep(cgImage: XCTUnwrap(context.makeImage())).representation(using: .png, properties: [:]))
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
                attachment.name = "cloud-\(outfit.rawValue)-\(kind)-\(dark ? "dark" : "light")-reduce-motion";attachment.lifetime = .keepAlways;add(attachment)
                stage.halt()
                func count(_ layer: CALayer) -> Int { (layer.animationKeys()?.count ?? 0) + (layer.sublayers ?? []).reduce(0) { $0 + count($1) } }
                XCTAssertEqual(count(stage.root), 0)
            }
        }
        }
    }
}
#endif
