#if DEBUG && os(iOS)
import XCTest
import UIKit
import SwiftUI
import QuartzCore
@testable import Daylog

/// Opt-in native evidence only. The test host has an in-memory data store.
@MainActor final class PioOverhaulIOSReviewTests: XCTestCase {
    func testNativeOutfitsAndMotionReview() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioIOSMotionReview"))
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController(); controller.view.backgroundColor = .systemBackground
        window.rootViewController = controller; window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let host = UIView(frame: CGRect(x: 0, y: 100, width: 220, height: 220))
        controller.view.addSubview(host)
        let rig = PioOverhaulRig(); host.layer.addSublayer(rig.root); rig.layout(host.bounds)
        var results: [[String: Any]] = []
        for outfit in PioOutfitID.allCases {
            XCTAssertNotNil(PioOverhaulResources.manifest(outfit))
        }
        for outfit in [PioOutfitID.basic, .christmas, .hanbok, .astronaut] {
            rig.configure(outfit, action: .jump); rig.setActive(true); CATransaction.flush()
            var positions: [Double] = []
            for (index, delay) in [0.15, 0.85].enumerated() {
                try await Task.sleep(for: .seconds(delay))
                CATransaction.flush()
                let presentation = try XCTUnwrap(rig.root.presentation())
                positions.append(Double(rig.movement.presentation()?.transform.m42 ?? 0))
                let image = UIGraphicsImageRenderer(size: host.bounds.size).image { context in
                    presentation.render(in: context.cgContext)
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "ios-\(outfit.rawValue)-jump-220pt-\(index)"; attachment.lifetime = .keepAlways; add(attachment)
            }
            XCTAssertNotEqual(positions[0], positions[1])
            results.append(["outfit": outfit.rawValue, "actualPresentationTranslationY": positions])
            rig.setActive(false); XCTAssertEqual(rig.animationCount, 0)
        }
        host.removeFromSuperview()
        let gallery = UIHostingController(rootView: AnyView(PioOverhaulMotionReview(outfit: .hanbok).environment(\.scenePhase, .active)))
        controller.addChild(gallery); controller.view.addSubview(gallery.view)
        gallery.view.frame = controller.view.bounds; gallery.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gallery.didMove(toParent: controller)
        try await Task.sleep(for: .seconds(2))
        let image = UIGraphicsImageRenderer(size: gallery.view.bounds.size).image { _ in
            gallery.view.drawHierarchy(in: gallery.view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image); attachment.name = "ios-native-motion-review-gallery"; attachment.lifetime = .keepAlways; add(attachment)
        print("PIO_IOS_MOTION_GALLERY_READY")
        try await Task.sleep(for: .seconds(15))
        gallery.rootView = AnyView(PioOverhaulCharacterView(outfit: .hanbok, action: .greet, isAnimating: false).environment(\.scenePhase, .active))
        try await Task.sleep(for: .seconds(1))
        func pioTrackCount(_ layer: CALayer) -> Int {
            let own = ["body", "eyeLeft", "eyeRight", "wingLeft", "wingRight"].contains(layer.name ?? "") ? (layer.animationKeys()?.count ?? 0) : 0
            return own + (layer.sublayers ?? []).reduce(0) { $0 + pioTrackCount($1) }
        }
        let tracks = pioTrackCount(gallery.view.layer)
        XCTAssertEqual(tracks, 0)
        let report: [String: Any] = ["status": "NATIVE_PILOT_PRESENTATION_ONLY", "platform": "iPhone simulator", "outfitsResolved": 14, "pilots": results, "pausedPartTracks": tracks, "limits": ["No iPhone CPU/memory profiling", "Native layer pilot evidence, not full application screen compatibility", "Reduce Motion OS setting was not toggled; NOT_TESTED"]]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        let evidence = XCTAttachment(data: data, uniformTypeIdentifier: "public.json"); evidence.name = "ios-native-motion-observations"; evidence.lifetime = .keepAlways; add(evidence)
    }
}
#endif
