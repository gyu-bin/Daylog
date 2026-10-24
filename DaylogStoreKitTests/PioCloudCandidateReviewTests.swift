#if DEBUG
import XCTest
import QuartzCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import Daylog

/// Genuine newly authored components in the existing cloud rig. Opt-in only;
/// these checks do not create receipts, equip an outfit, or touch user data.
@MainActor final class PioCloudCandidateReviewTests: XCTestCase {
    private var batchOverride: PioOutfitID?
    private var reviewOutfit: PioOutfitID {
        if let batchOverride { return batchOverride }
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-PioCloudCandidateOutfit"), arguments.indices.contains(index + 1),
           let outfit = PioOutfitID(rawValue: arguments[index + 1]) { return outfit }
        return arguments.contains("-PioCloudChristmasCandidate") ? .christmas : .basic
    }
    override func setUpWithError() throws {
        try XCTSkipUnless(PioCloudBasicEyesTrial.isEnabled || PioCloudBasicEyesTrial.handsEnabled || ProcessInfo.processInfo.arguments.contains("-PioCloudProductionReview"))
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-PioCloudCandidateOutfit") {
            let value = try XCTUnwrap(arguments.indices.contains(index + 1) ? arguments[index + 1] : nil,
                "Explicit candidate selection requires an outfit raw value")
            _ = try XCTUnwrap(PioOutfitID(rawValue: value), "Unknown candidate must not silently test Basic")
        }
        if !arguments.contains("-PioCloudProductionReview") { XCTAssertTrue(PioOverhaulTrial.isEnabled) }
    }

    func testCandidateRegistrationNeutralAndStop() throws {
        let registration = try XCTUnwrap(ProcessInfo.processInfo.arguments.contains("-PioCloudProductionReview") ? PioCloudSceneResources.productionRegistration(outfit: reviewOutfit) : PioCloudSceneResources.candidate(outfit: reviewOutfit))
        let productionReview = ProcessInfo.processInfo.arguments.contains("-PioCloudProductionReview")
        XCTAssertEqual(registration.revision, productionReview ? "\(reviewOutfit.rawValue)-production-hands-v2"
            : (PioCloudBasicEyesTrial.handsEnabled ? "\(reviewOutfit.rawValue)-hands-v2" : "basic-eyes-v1"))
        XCTAssertTrue(PioCloudSceneResources.hasSeatedLayers(reviewOutfit))
        // The coordinator's DEBUG trial resource API remains opt-in even
        // though the native scene has its own narrow Basic production gate.
        XCTAssertEqual(PioCloudSceneResources.assetName(outfit: reviewOutfit, context: .cloudDownloading),
            PioOverhaulTrial.isEnabled ? registration.parts.first { $0.id == "body" }?.asset : nil)
        let rig = PioCloudCharacterRig()
        for side in [64, 220] {
            for kind: SyncSceneKind in [.receiving, .trouble] {
                let bounds = CGRect(x: 0, y: 0, width: side, height: side)
                rig.configure(outfit: reviewOutfit, kind: kind, bounds: bounds)
                XCTAssertEqual(Set(rig.parts.keys), Set(registration.parts.map(\.id)))
                XCTAssertEqual(rig.parts["body"]?.frame, bounds)
                XCTAssertEqual(rig.parts["eyeLeft"]?.opacity, 1)
                XCTAssertEqual(rig.parts["lidLeft"]?.opacity, 0)
                XCTAssertGreaterThan(nonemptyPixels(try XCTUnwrap(rig.parts["eyeLeft"])), 20,
                    "A timed opacity track alone cannot prove that the texture sampler actually draws an eye")
                if reviewOutfit == .basic {
                    XCTAssertNil(rig.parts["halfLeft"], "No genuine Basic half-eye artwork is registered yet")
                }
                for dark in [false, true] {
                    attach(rig.root, side: side, dark: dark,
                        name: "\(registration.revision)-\(side)pt-\(kind.rawValue)-\(dark ? "dark" : "light")-neutral-model")
                }
                rig.setActive(true)
                XCTAssertNotNil(rig.parts["eyeLeft"]?.animation(forKey: "cloud.independentBlink"))
                XCTAssertNil(rig.parts["body"]?.animationKeys(), "Body must not be blinked or rotated as a surrogate")
                if let hold = registration.holdGroup {
                    XCTAssertEqual(Set(rig.accessoryHold.sublayers?.compactMap(\.name) ?? []), Set(hold.ids))
                    XCTAssertNotNil(rig.accessoryHold.animation(forKey: "cloud.independentHeldGroup"))
                    XCTAssertLessThanOrEqual(hold.degrees, 2)
                    let roots = rig.root.sublayers ?? []
                    XCTAssertGreaterThan(try XCTUnwrap(roots.firstIndex { $0 === rig.accessoryHold }),
                        try XCTUnwrap(roots.firstIndex { $0 === rig.parts["body"] }),
                        "Held foreground must paint above the clean torso in both native render paths")
                    for id in hold.ids {
                        XCTAssertGreaterThan(nonemptyPixels(try XCTUnwrap(rig.parts[id])), 20,
                            "Each claimed independent hand/prop must actually draw genuine source pixels")
                    }
                } else { XCTAssertNil(rig.accessoryHold.animationKeys()) }
                rig.setActive(false)
                XCTAssertEqual(rig.animationCount, 0)
                XCTAssertTrue(CATransform3DIsIdentity(rig.accessoryHold.transform))
            }
        }
        // Resizing and switching at unchanged bounds must reapply donor frames.
        rig.configure(outfit: reviewOutfit == .basic ? .christmas : .basic, kind: .receiving, bounds: CGRect(x: 0, y: 0, width: 220, height: 220))
        rig.configure(outfit: reviewOutfit, kind: .receiving, bounds: CGRect(x: 0, y: 0, width: 220, height: 220))
        let eye = try XCTUnwrap(registration.parts.first { $0.id == "eyeLeft" })
        XCTAssertEqual(rig.parts["eyeLeft"]!.bounds.width, CGFloat(eye.rect[2]) * 220 / 1254, accuracy: 0.001)
        // Actual Reduce Motion configuration stops all nested candidate tracks.
        let scene = RoutimoriSyncStage()
        scene.update(.init(kind: .receiving, height: 220, dark: false, scale: 2, reduceMotion: true,
            outfit: reviewOutfit, usesIndependentCharacter: true), isAnimating: true)
        XCTAssertEqual(tracks(scene.root), 0)
        XCTAssertNotNil(scene.character.sublayers?.first)
    }

    func testAllFourteenKeepApprovedFallbackWhenNoCandidateExists() throws {
        for outfit in PioOutfitID.allCases {
            let registration = PioCloudSceneResources.selectedRegistration(outfit: outfit)
            for context: PioAppearanceContext in [.cloudDownloading, .cloudFailed] {
                let legacy = "pio_cloud_\(outfit.rawValue)_body"
                let expected = registration?.parts.first { $0.id == "body" }?.asset
                    ?? (PioAppearanceResources.hasImage(legacy) ? legacy : nil)
                XCTAssertEqual(PioCloudSceneResources.assetName(outfit: outfit, context: context),
                    PioOverhaulTrial.isEnabled ? expected : nil)
            }
            if PioCloudSceneResources.hasSeatedLayers(outfit) {
                let rig = PioCloudCharacterRig()
                rig.configure(outfit: outfit, kind: .receiving, bounds: CGRect(x: 0, y: 0, width: 220, height: 220))
                XCTAssertNotNil(rig.parts["body"]?.contents)
                XCTAssertNotNil(rig.parts["eyeLeft"]?.contents)
                rig.setActive(true); XCTAssertGreaterThan(rig.animationCount, 0)
                rig.setActive(false); XCTAssertEqual(rig.animationCount, 0)
            }
        }
    }

    func testActualIndependentBlinkAndHeldPresentation() async throws {
        let registration = try XCTUnwrap(ProcessInfo.processInfo.arguments.contains("-PioCloudProductionReview") ? PioCloudSceneResources.productionRegistration(outfit: reviewOutfit) : PioCloudSceneResources.candidate(outfit: reviewOutfit))
        let host = try makeHost()
        defer { host.close() }
        let rigs = [64, 220].map { side -> PioCloudCharacterRig in
            let rig = PioCloudCharacterRig()
            rig.configure(outfit: reviewOutfit, kind: .receiving, bounds: CGRect(x: 0, y: 0, width: side, height: side))
            host.layer.addSublayer(rig.root)
            rig.root.position = CGPoint(x: 170, y: side == 64 ? 330 : 150)
            return rig
        }
        let start = CACurrentMediaTime()
        rigs.forEach { $0.setActive(true) }; CATransaction.flush()
        var observations: [[String: Any]] = []
        let targets: [(String, Double)] = [("open", 0.15), ("hold-positive", 1.60), ("closed", 1.80), ("reopened", 2.30), ("hold-negative", 4.80)]
        for (name, target) in targets {
            let remaining = target - (CACurrentMediaTime() - start)
            if remaining > 0 { try await Task.sleep(for: .seconds(remaining)) }
            if name == "closed" || name == "open" || name == "reopened" {
                // Wait for the requested presentation state within the same
                // bounded observation window. Simulator rendering/PNG capture
                // can overrun the target; elapsed wall time alone does not
                // establish that the eyes have reopened on the render server.
                let expectsClosed = name == "closed"
                let deadline = CACurrentMediaTime() + 0.5
                while CACurrentMediaTime() < deadline && !rigs.allSatisfy({ rig in
                    guard let eye = rig.parts["eyeLeft"]?.presentation(),
                          let lid = rig.parts["lidLeft"]?.presentation() else { return false }
                    return expectsClosed ? eye.opacity < 0.05 && lid.opacity > 0.95
                        : eye.opacity > 0.95 && lid.opacity < 0.05
                }) { try await Task.sleep(for: .milliseconds(8)) }
            }
            CATransaction.flush()
            for (index, rig) in rigs.enumerated() {
                let side = index == 0 ? 64 : 220
                let presentation = try XCTUnwrap(rig.root.presentation())
                let eye = try XCTUnwrap(rig.parts["eyeLeft"]?.presentation())
                let lid = try XCTUnwrap(rig.parts["lidLeft"]?.presentation())
                let observedElapsed = CACurrentMediaTime() - start
                XCTAssertNil(rig.parts["body"]?.animationKeys())
                XCTAssertTrue(CATransform3DIsIdentity(try XCTUnwrap(rig.parts["body"]?.presentation()).transform))
                if name == "closed" { XCTAssertLessThan(eye.opacity, 0.05); XCTAssertGreaterThan(lid.opacity, 0.95) }
                if name == "open" || name == "reopened" { XCTAssertGreaterThan(eye.opacity, 0.95); XCTAssertLessThan(lid.opacity, 0.05) }
                let held = rig.accessoryHold.presentation()?.value(forKeyPath: "transform.rotation.z") as? NSNumber
                if registration.holdGroup != nil && name.hasPrefix("hold-") {
                    XCTAssertGreaterThan(abs(held?.doubleValue ?? 0), 0.005)
                    for id in registration.holdGroup!.ids {
                        XCTAssertTrue(rig.parts[id]?.superlayer === rig.accessoryHold)
                        XCTAssertNil(rig.parts[id]?.animationKeys(), "Contact is preserved by the common hold joint")
                    }
                }
                for dark in [false, true] {
                    attach(presentation, side: side, dark: dark,
                        name: "\(registration.revision)-\(side)pt-\(dark ? "dark" : "light")-\(name)-actual-presentation")
                }
                observations.append(["state": name, "side": side, "elapsed": observedElapsed,
                    "eyeOpacity": eye.opacity, "lidOpacity": lid.opacity, "heldRadians": held?.doubleValue ?? 0])
            }
        }
        rigs.forEach { $0.setActive(false); XCTAssertEqual($0.animationCount, 0); $0.root.removeFromSuperlayer() }
        let report: [String: Any] = ["revision": registration.revision, "platform": Self.platform,
            "partAssets": Dictionary(uniqueKeysWithValues: registration.parts.map { ($0.id, $0.asset) }),
            "partRects": Dictionary(uniqueKeysWithValues: registration.parts.map { ($0.id, $0.rect) }),
            "holdIDs": registration.holdGroup?.ids ?? [],
            "observations": observations, "independent": registration.holdGroup == nil ? ["eyes", "lids"] : ["eyes", "lids", "shared arms/tablet hold joint"],
            "limits": "Native presentation-layer component captures; candidate geometry still requires visual approval. Held parts never detach or wave independently of the prop. No purchase, preference or whole-screen workflow verification."]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "\(registration.revision)-actual-native-observations"; attachment.lifetime = .keepAlways; add(attachment)
    }

    /// Optional actual presentation frames for a short review clip, never a
    /// manually interpolated/model timeOffset animation.
    func testActualPresentationSequence() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioCloudCandidateSequence"))
        let registration = try XCTUnwrap(ProcessInfo.processInfo.arguments.contains("-PioCloudProductionReview") ? PioCloudSceneResources.productionRegistration(outfit: reviewOutfit) : PioCloudSceneResources.candidate(outfit: reviewOutfit))
        let host = try makeHost(); defer { host.close() }
        let rig = PioCloudCharacterRig()
        rig.configure(outfit: reviewOutfit, kind: .receiving, bounds: CGRect(x: 0, y: 0, width: 220, height: 220))
        host.layer.addSublayer(rig.root);rig.root.position = CGPoint(x: 170, y: 150)
        let begin = CACurrentMediaTime(); rig.setActive(true); CATransaction.flush()
        for index in 0..<104 {
            let remaining = Double(index) / 20 - (CACurrentMediaTime() - begin)
            if remaining > 0 { try await Task.sleep(for: .seconds(remaining)) }
            attach(try XCTUnwrap(rig.root.presentation()), side: 220, dark: false,
                name: String(format: "%@-native-sequence-%03d", registration.revision, index))
        }
        rig.setActive(false); XCTAssertEqual(rig.animationCount, 0)
    }

    private func explicitBatchOutfits() throws -> [PioOutfitID] {
        let arguments = ProcessInfo.processInfo.arguments
        let index = try XCTUnwrap(arguments.firstIndex(of: "-PioCloudCandidateBatch"),
            "Batch execution requires an explicit list; never silently substitute Basic")
        let value = try XCTUnwrap(arguments.indices.contains(index + 1) ? arguments[index + 1] : nil)
        let rawValues = value.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        XCTAssertEqual(Set(rawValues).count, rawValues.count, "Duplicate outfits would inflate check counts")
        guard !rawValues.isEmpty, Set(rawValues).count == rawValues.count else {
            throw NSError(domain: "PioCloudCandidateBatch", code: 1)
        }
        return try rawValues.map { raw in
            try XCTUnwrap(PioOutfitID(rawValue: raw), "Unknown batch outfit \(raw)")
        }
    }
    func testBatchCandidateRegistrationNeutralAndStop() throws {
        let outfits = try explicitBatchOutfits();defer { batchOverride = nil }
        var rows: [[String: Any]] = []
        for outfit in outfits {
            batchOverride = outfit
            let before = testRun?.failureCount ?? 0
            var completed = false;var errorText = ""
            print("PIO_CANDIDATE_BATCH_BEGIN neutral \(outfit.rawValue)")
            do { try testCandidateRegistrationNeutralAndStop();completed = true }
            catch { errorText = String(describing: error);XCTFail("\(outfit.rawValue) neutral failed: \(error)") }
            rows.append(["outfit": outfit.rawValue, "completed": completed, "error": errorText,
                "assertionFailuresAdded": (testRun?.failureCount ?? 0) - before])
        }
        try attachBatchResults(rows, name: "candidate-batch-neutral-results")
    }
    func testBatchActualIndependentBlinkAndHeldPresentation() async throws {
        let outfits = try explicitBatchOutfits();defer { batchOverride = nil }
        var rows: [[String: Any]] = []
        for outfit in outfits {
            batchOverride = outfit
            let before = testRun?.failureCount ?? 0
            var completed = false;var errorText = ""
            print("PIO_CANDIDATE_BATCH_BEGIN presentation \(outfit.rawValue)")
            do { try await testActualIndependentBlinkAndHeldPresentation();completed = true }
            catch { errorText = String(describing: error);XCTFail("\(outfit.rawValue) presentation failed: \(error)") }
            rows.append(["outfit": outfit.rawValue, "completed": completed, "error": errorText,
                "assertionFailuresAdded": (testRun?.failureCount ?? 0) - before])
        }
        try attachBatchResults(rows, name: "candidate-batch-presentation-results")
    }
    private func attachBatchResults(_ rows: [[String: Any]], name: String) throws {
        let report: [String: Any] = ["platform": Self.platform, "checks": rows,
            "count": rows.count, "scope": "Exact existing assertion body per explicitly selected outfit, sequential shared process/cache; no omitted or silently substituted outfits. Native component evidence, not artwork approval or purchase verification."]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = name;attachment.lifetime = .keepAlways;add(attachment)
    }
    private func tracks(_ layer: CALayer) -> Int {
        (layer.animationKeys()?.count ?? 0) + (layer.sublayers ?? []).reduce(0) { $0 + tracks($1) }
    }
    private func nonemptyPixels(_ layer: CALayer) -> Int {
        let context = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 256,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.scaleBy(x: 64 / max(layer.bounds.width, 1), y: 64 / max(layer.bounds.height, 1))
        layer.render(in: context)
        let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
        return stride(from: 3, to: 64 * 256, by: 4).reduce(0) { $0 + (bytes[$1] > 0 ? 1 : 0) }
    }
    private func attach(_ layer: CALayer, side: Int, dark: Bool, name: String) {
        let context = CGContext(data: nil, width: side * 3, height: side * 3, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray: dark ? 0.08 : 0.97, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side * 3, height: side * 3));context.scaleBy(x: 3, y: 3)
        #if os(iOS)
        context.translateBy(x: 0, y: CGFloat(side)); context.scaleBy(x: 1, y: -1)
        #endif
        layer.render(in: context)
        let image = context.makeImage()!
        #if os(macOS)
        let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
        #else
        let data = UIImage(cgImage: image).pngData()!
        #endif
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name; attachment.lifetime = .keepAlways;add(attachment)
    }
    private struct Host {
        let layer: CALayer
        let close: @MainActor () -> Void
    }
    private func makeHost() throws -> Host {
        #if os(macOS)
        let view = NSView(frame: CGRect(x: 0, y: 0, width: 340, height: 400));view.wantsLayer = true
        let window = NSWindow(contentRect: view.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false;window.contentView = view;window.orderFrontRegardless()
        return Host(layer: view.layer!, close: { window.orderOut(nil);window.close() })
        #else
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene);let controller = UIViewController()
        controller.view.backgroundColor = .systemBackground
        window.rootViewController = controller;window.makeKeyAndVisible()
        let view = UIView(frame: CGRect(x: 0, y: 80, width: 340, height: 400));controller.view.addSubview(view)
        return Host(layer: view.layer, close: { window.isHidden = true })
        #endif
    }
    private static var platform: String {
        #if os(macOS)
        "Mac"
        #else
        "iPhone Simulator"
        #endif
    }
}
#endif
