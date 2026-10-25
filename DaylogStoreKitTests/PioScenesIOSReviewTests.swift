#if DEBUG && os(iOS)
import XCTest
import UIKit
import QuartzCore
@testable import Daylog

/// Opt-in native scene evidence; no StoreKit session, transactions or preference writes.
@MainActor final class PioScenesIOSReviewTests: XCTestCase {
    private func tracks(_ layer: CALayer) -> Int {
        (layer.animationKeys()?.count ?? 0) + (layer.sublayers ?? []).reduce(0) { $0 + tracks($1) }
    }
    private func attach(_ view: UIView, name: String, presentation: CALayer? = nil) {
        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { context in
            if let presentation { presentation.render(in: context.cgContext) }
            else { view.layer.render(in: context.cgContext) }
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testNativeCloudAndVacationCurrentOutfits() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioIOSSceneReview"))
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
        XCTAssertTrue(PioOverhaulTrial.isEnabled)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController(); controller.view.backgroundColor = .systemBackground
        window.rootViewController = controller; window.makeKeyAndVisible()
        defer { window.isHidden = true }
        var mappings: [[String: Any]] = []
        for outfit in PioOutfitID.allCases {
            for kind in SyncSceneKind.allCases {
                let appearance = PioAppearanceCoordinator.shared.preview(outfit: outfit, stage: 1, context: kind.pioAppearanceContext)
                let expected = kind == .ready ? outfit.artAssetName : outfit == .basic ? kind.pioAppearanceContext.originalSceneAsset! : "pio_cloud_\(outfit.rawValue)_body"
                XCTAssertEqual(appearance.artwork.assetName, expected)
                XCTAssertTrue(appearance.outfitApplied)
                let stage = RoutimoriSyncStage()
                let independent = kind == .ready || outfit != .basic
                stage.update(.init(kind: kind, height: 220, dark: false, scale: 3, reduceMotion: true,
                    characterAssetName: appearance.artwork.assetName, outfit: outfit, usesIndependentCharacter: independent), isAnimating: true)
                XCTAssertEqual(tracks(stage.root), 0)
                XCTAssertFalse(stage.character.isHidden)
                if independent { XCTAssertLessThan(stage.character.frame.maxY, stage.root.bounds.maxY) }
                mappings.append(["outfit":outfit.rawValue,"state":String(describing:kind),"asset":expected,"independent":independent])
                stage.halt()
            }
        }
        let slot = UIView(frame: CGRect(x: 30, y: 150, width: 340, height: 340))
        controller.view.addSubview(slot)
        for outfit in [PioOutfitID.christmas, .hanbok, .astronaut] {
            for kind in SyncSceneKind.allCases {
                let stage = RoutimoriSyncStage()
                let dark = kind == .trouble
                slot.backgroundColor = dark ? UIColor(white:0.08,alpha:1) : UIColor(white:0.97,alpha:1)
                slot.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
                slot.layer.addSublayer(stage.root)
                stage.update(.init(kind:kind,height:340,dark:dark,scale:3,reduceMotion:false,outfit:outfit,usesIndependentCharacter:true),isAnimating:true)
                stage.root.position = CGPoint(x:170,y:170)
                CATransaction.flush()
                try await Task.sleep(for:.milliseconds(180))
                let presentation = try XCTUnwrap(slot.layer.presentation())
                XCTAssertGreaterThan(tracks(stage.root), 0)
                attach(slot,name:"ios-cloud-\(outfit.rawValue)-\(kind)-\(dark ? "dark":"light")-native",presentation:presentation)
                stage.halt(); XCTAssertEqual(tracks(stage.root),0)
            }
        }
        // Capture actual eye/lid substitutions at native presentation times.
        let blink = PioCloudCharacterRig(); blink.configure(outfit:.christmas,kind:.receiving,bounds:slot.bounds)
        slot.layer.sublayers?.forEach { $0.removeFromSuperlayer() };slot.layer.addSublayer(blink.root)
        blink.setActive(true);CATransaction.flush()
        for (index, delay) in [0.15,1.8].enumerated() {
            try await Task.sleep(for:.seconds(delay));CATransaction.flush()
            attach(slot,name:"ios-cloud-christmas-blink-\(index)-native",presentation:try XCTUnwrap(blink.root.presentation()))
        }
        blink.setActive(false); XCTAssertEqual(blink.animationCount,0)
        // Pending verification leaves cloud feedback active but no character tracks.
        let suppressed = RoutimoriSyncStage()
        suppressed.update(.init(kind:.receiving,height:220,dark:false,scale:3,reduceMotion:false,outfit:.basic,suppressCharacter:true),isAnimating:true)
        XCTAssertTrue(suppressed.character.isHidden);XCTAssertEqual(tracks(suppressed.character),0)
        XCTAssertGreaterThan(tracks(suppressed.cloud),0);suppressed.halt()
        slot.removeFromSuperview()
        let vacationSlot = UIView(frame:CGRect(x:0,y:0,width:402,height:780));controller.view.addSubview(vacationSlot)
        for outfit in [PioOutfitID.christmas,.hanbok,.astronaut] {
            let rig = RoutimoriVacationRig(outfit:outfit)
            vacationSlot.layer.sublayers?.forEach { $0.removeFromSuperlayer() };vacationSlot.layer.addSublayer(rig.root)
            for dark in [false,true] {
                rig.layout(in:vacationSlot.bounds,slot:CGRect(x:20,y:260,width:362,height:260),isDark:dark,displayScale:3)
                rig.setAnimating(true);CATransaction.flush();try await Task.sleep(for:.milliseconds(150))
                XCTAssertNotNil(rig.hammock.contents)
                XCTAssertEqual(rig.currentRegistration.swingDegrees,0.55)
                attach(vacationSlot,name:"ios-vacation-\(outfit.rawValue)-\(dark ? "night":"day")-native",presentation:try XCTUnwrap(rig.root.presentation()))
                rig.setCharacterVisible(false);XCTAssertNil(rig.hammock.animationKeys());rig.setCharacterVisible(true)
            }
            rig.setAnimating(false)
        }
        vacationSlot.removeFromSuperview()
        let nativeHost = PioCloudSceneHost(frame:CGRect(x:20,y:100,width:220,height:220))
        let lifecycle = RoutimoriSyncStage()
        nativeHost.layer.addSublayer(lifecycle.root);nativeHost.hosted=lifecycle.root
        nativeHost.visibilityChanged = { visible in
            lifecycle.update(.init(kind:.receiving,height:220,dark:false,scale:3,reduceMotion:false,outfit:.christmas,usesIndependentCharacter:true),isAnimating:visible)
        }
        controller.view.addSubview(nativeHost);nativeHost.layoutIfNeeded();nativeHost.refreshVisibility()
        XCTAssertGreaterThan(tracks(lifecycle.root),0)
        nativeHost.removeFromSuperview();XCTAssertEqual(tracks(lifecycle.root),0)
        nativeHost.visibilityChanged=nil
        let report: [String:Any] = ["status":"NATIVE_SCENE_PILOT_EVIDENCE","platform":"iPhone17 simulator","cloudMappings":mappings,"nativeCloudPilotPNGs":9,"nativeBlinkPNGs":2,"nativeVacationPNGs":6,"checks":["42 coordinator mappings","Reduce Motion configuration removes CA tracks","hidden verification character has zero tracks","native window detach halts tracks","vacation hidden foreground halts swing"],"limits":["No StoreKit transactions","No production preference or data writes","No iPhone CPU/RSS profiling","Native scene components, not full cloud workflow screenshots","Basic seated eyes and premium seated hands/tablet remain flattened","Vacation foregrounds sway as whole authored images; no independent eyes/hands"]]
        let attachment = XCTAttachment(data:try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),uniformTypeIdentifier:"public.json")
        attachment.name="ios-scene-native-results";attachment.lifetime = .keepAlways;add(attachment)
    }
}
#endif
