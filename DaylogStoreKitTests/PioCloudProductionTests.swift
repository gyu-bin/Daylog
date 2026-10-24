import XCTest
import QuartzCore
import SwiftUI
import Darwin
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import Daylog

/// The production resource/rig path, without trial flags or entitlement writes.
/// Rendering fixtures here never equip or unlock a paid outfit.
@MainActor final class PioCloudProductionTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipIf(PioCloudBasicEyesTrial.isEnabled || PioCloudBasicEyesTrial.handsEnabled,
            "Production-path checks require all cloud candidate flags disabled")
        XCTAssertTrue(RuntimeEnvironment.isRunningTests)
    }
    func testSmallProductionPackAndIndependentEyeFrames() throws {
        let registration = try XCTUnwrap(PioCloudSceneResources.productionBasicRegistration())
        XCTAssertEqual(registration.revision, "basic-production-eyes-v1")
        XCTAssertEqual(Set(registration.parts.map(\.asset)).count, 5)
        XCTAssertTrue(registration.parts.allSatisfy { $0.asset.hasPrefix("pio_cloud_basic_prod_v1_") })
        XCTAssertNil(registration.holdGroup)
        XCTAssertTrue(PioCloudSceneResources.hasProductionBasicEyes(.basic))
        for outfit in PioOutfitID.allCases where outfit != .basic {
            XCTAssertFalse(PioCloudSceneResources.hasProductionBasicEyes(outfit))
        }
        // V1 remains a valid fallback while normal selection chooses V2.
        XCTAssertEqual(PioCloudSceneResources.selectedRegistration(outfit: .basic)?.revision,
            "basic-production-hands-v2")
    }
    func testProductionReduceMotionSuppressionAndSceneStop() throws {
        let stage = RoutimoriSyncStage()
        stage.update(.init(kind: .receiving, height: 220, dark: false, scale: 3, reduceMotion: false,
            outfit: .basic, usesIndependentCharacter: true), isAnimating: true)
        XCTAssertNotNil(stage.character.sublayers?.first)
        XCTAssertGreaterThan(tracks(stage.character), 0)
        stage.halt(); XCTAssertEqual(tracks(stage.root), 0)
        stage.update(.init(kind: .receiving, height: 220, dark: true, scale: 3, reduceMotion: true,
            outfit: .basic, usesIndependentCharacter: true), isAnimating: true)
        XCTAssertEqual(tracks(stage.root), 0)
        stage.update(.init(kind: .receiving, height: 220, dark: true, scale: 3, reduceMotion: false,
            outfit: .basic, suppressCharacter: true, usesIndependentCharacter: true), isAnimating: true)
        XCTAssertTrue(stage.character.isHidden); XCTAssertEqual(tracks(stage.character), 0)
        stage.halt()
    }

    func testFourteenProductionRegistrationsAndIndependentHold() throws {
        XCTAssertEqual(PioOutfitID.allCases.count, 14)
        let rig = PioCloudCharacterRig()
        for outfit in PioOutfitID.allCases {
            let registration = try XCTUnwrap(PioCloudSceneResources.productionRegistration(outfit: outfit))
            XCTAssertEqual(registration.revision, "\(outfit.rawValue)-production-hands-v2")
            XCTAssertTrue(registration.parts.allSatisfy { $0.asset.hasPrefix("pio_cloud_prod_v2_") })
            XCTAssertTrue(PioCloudSceneResources.hasProductionLayers(outfit))
            XCTAssertTrue(PioCloudSceneResources.missingIndependentLayers(outfit: outfit, context: .cloudDownloading).isEmpty)
            let hold = try XCTUnwrap(registration.holdGroup)
            XCTAssertEqual(Set(hold.ids), Set(["armLeft", "armRight", "tablet"]))
            for side in [64, 220] {
                rig.configure(outfit: outfit, kind: .receiving, bounds: CGRect(x: 0, y: 0, width: side, height: side))
                XCTAssertEqual(Set(rig.parts.keys), Set(registration.parts.map(\.id)))
                XCTAssertTrue(rig.parts.values.allSatisfy { $0.contents != nil && $0.bounds.width > 0 && $0.bounds.height > 0 })
                rig.setActive(true)
                XCTAssertNotNil(rig.parts["eyeLeft"]?.animation(forKey: "cloud.independentBlink"))
                XCTAssertNil(rig.parts["body"]?.animationKeys())
                XCTAssertNotNil(rig.accessoryHold.animation(forKey: "cloud.independentHeldGroup"))
                for id in hold.ids { XCTAssertTrue(rig.parts[id]?.superlayer === rig.accessoryHold) }
                rig.setActive(false)
                XCTAssertEqual(rig.animationCount, 0)
                XCTAssertTrue(CATransform3DIsIdentity(rig.accessoryHold.transform))
            }
        }
    }

    func testFourteenProductionTransitionsSuppressionAndReduceMotion() throws {
        let stage = RoutimoriSyncStage()
        for outfit in PioOutfitID.allCases {
            for kind: SyncSceneKind in [.receiving, .trouble, .receiving] {
                stage.update(.init(kind: kind, height: 220, dark: kind == .trouble, scale: 3, reduceMotion: false,
                    outfit: outfit, usesIndependentCharacter: true), isAnimating: true)
                XCTAssertEqual(stage.configuration?.outfit, outfit)
                XCTAssertNil(stage.character.contents)
                let rigRoot = try XCTUnwrap(stage.character.sublayers?.first)
                XCTAssertNotNil(rigRoot.sublayers?.first { $0.name == "body" }?.contents)
                XCTAssertGreaterThan(tracks(stage.character), 0)
            }
            let completed = PioCloudSceneResources.productionAppearance(from:
                fixture(outfit: outfit, context: .cloudCompleted))
            XCTAssertEqual(completed.outfit, outfit)
            XCTAssertEqual(completed.artwork.assetName,
                outfit == .basic ? "routimori_sync_success" : outfit.artAssetName)
            stage.update(.init(kind: .ready, height: 220, dark: false, scale: 3, reduceMotion: false,
                characterAssetName: completed.artwork.assetName, outfit: outfit,
                usesIndependentCharacter: false), isAnimating: true)
            XCTAssertTrue(stage.character.sublayers?.isEmpty ?? true)
            XCTAssertNotNil(stage.character.contents, "Success must render the same authorized costume, never an empty or Basic substitute")
            XCTAssertNotNil(stage.character.animation(forKey: "celebration"))
            stage.update(.init(kind: .receiving, height: 64, dark: true, scale: 3, reduceMotion: true,
                outfit: outfit, usesIndependentCharacter: true), isAnimating: true)
            XCTAssertEqual(tracks(stage.root), 0)
            XCTAssertNotNil(stage.character.sublayers?.first)
            stage.update(.init(kind: .receiving, height: 64, dark: true, scale: 3, reduceMotion: false,
                outfit: outfit, suppressCharacter: true, usesIndependentCharacter: true), isAnimating: true)
            XCTAssertTrue(stage.character.isHidden)
            XCTAssertEqual(tracks(stage.character), 0)
            stage.halt();XCTAssertEqual(tracks(stage.root), 0)
        }
    }

    func testProductionAppearanceAdapterPreservesAuthorizationAndNotes() throws {
        for outfit in PioOutfitID.allCases {
            for context: PioAppearanceContext in [.cloudDownloading, .cloudFailed, .cloudCompleted] {
                let original = fixture(outfit: outfit, context: context)
                let adapted = PioCloudSceneResources.productionAppearance(from: original)
                XCTAssertEqual(adapted.outfit, original.outfit)
                XCTAssertEqual(adapted.requestedOutfit, original.requestedOutfit)
                XCTAssertEqual(adapted.access, original.access)
                XCTAssertTrue(adapted.outfitApplied)
                XCTAssertNil(adapted.compatibilityNote)
                XCTAssertEqual(adapted.missingArtwork, ["pio_outfit_\(outfit.rawValue)_stage1"])
            }
        }
        for access: PioAppearanceAccess in [.checking, .verificationUnavailable, .notOwned, .unavailable] {
            let denied = fixture(outfit: .basic, requested: .christmas, context: .cloudDownloading, access: access)
            XCTAssertEqual(PioCloudSceneResources.productionAppearance(from: denied), denied)
        }
        let unrelated = fixture(outfit: .christmas, context: .vacationDay)
        XCTAssertEqual(PioCloudSceneResources.productionAppearance(from: unrelated), unrelated)
    }

    private func fixture(outfit: PioOutfitID, requested: PioOutfitID? = nil,
                         context: PioAppearanceContext, access: PioAppearanceAccess = .preview) -> PioResolvedAppearance {
        let original = context.originalSceneAsset ?? ""
        return PioResolvedAppearance(context: context, outfit: outfit, requestedOutfit: requested ?? outfit,
            stage: 1, pose: .cloudDownloading, motion: .idle,
            artwork: .existingScene(asset: original), renderer: .originalScene, access: access,
            outfitApplied: false, growthCompatible: false, animationPreserved: true,
            missingArtwork: ["\(original)_\(outfit.rawValue)", "pio_outfit_\(outfit.rawValue)_stage1"],
            compatibilityNote: "\(outfit.title)의 이 장면 전용 원화가 없어 기본 장면을 유지해요. 착장 선택은 바뀌지 않아요.")
    }

    func testProductionBasicLiveAndStoppedObservations() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioCloudPerformanceReview"))
        #if os(macOS)
        let view = NSView(frame: CGRect(x: 0, y: 0, width: 340, height: 340));view.wantsLayer = true
        let window = NSWindow(contentRect: view.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false;window.contentView = view;window.orderFrontRegardless()
        let parent = view.layer!
        defer { window.orderOut(nil);window.close() }
        #else
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene);let controller = UIViewController()
        window.rootViewController = controller;window.makeKeyAndVisible()
        let parent = controller.view.layer
        defer { window.isHidden = true }
        #endif
        var stage: RoutimoriSyncStage? = RoutimoriSyncStage();weak var weakStage = stage
        parent.addSublayer(stage!.root);stage!.root.position = CGPoint(x: 170, y: 170)
        let configuration = RoutimoriSyncStage.Configuration(kind: .receiving, height: 340, dark: false, scale: 2,
            reduceMotion: false, outfit: .basic, usesIndependentCharacter: true)
        stage!.update(configuration, isAnimating: true);CATransaction.flush()
        try await Task.sleep(for: .seconds(1))
        var phases: [[String: Any]] = []
        for active in [true, false] {
            stage!.update(configuration, isAnimating: active);CATransaction.flush()
            if active { XCTAssertGreaterThan(tracks(stage!.character), 0) }
            else { XCTAssertEqual(tracks(stage!.root), 0) }
            let begin = Date(), initialCPU = cpu(), initialRSS = rss()
            var samples: [UInt64] = []
            var visibleSamples: [Bool] = []
            for _ in 0..<10 {
                try await Task.sleep(for: .seconds(1));samples.append(rss())
                #if os(macOS)
                visibleSamples.append(window.isVisible && !window.isMiniaturized && window.occlusionState.contains(.visible))
                #else
                visibleSamples.append(!window.isHidden && scene.activationState == .foregroundActive)
                #endif
            }
            XCTAssertTrue(visibleSamples.allSatisfy { $0 }, "Performance observations require a genuinely visible native host")
            let elapsed = Date().timeIntervalSince(begin), delta = cpu() - initialCPU
            var phase: [String: Any] = ["active": active, "seconds": elapsed, "cpuSeconds": delta,
                "cpuPercent": delta / elapsed * 100, "initialRSS": initialRSS, "finalRSS": rss(), "samples": samples,
                "visibleSamples": visibleSamples]
            #if os(macOS)
            phase["windowVisible"] = window.isVisible
            phase["publicOcclusionVisible"] = window.occlusionState.contains(.visible)
            #else
            phase["windowVisible"] = !window.isHidden
            phase["sceneActivationState"] = scene.activationState.rawValue
            #endif
            phases.append(phase)
        }
        stage!.halt();stage!.root.removeFromSuperlayer();stage = nil;CATransaction.flush()
        XCTAssertNil(weakStage)
        let report: [String: Any] = ["phases": phases, "finalRSSAfterCleanup": rss(), "sceneReleased": weakStage == nil,
            "scope": "Same process and same warm native Basic production eye scene, active10s then stopped10s. No candidate flags. Process CPU only.",
            "limits": "Bounded Debug test-host observation, not a performance threshold approval, Release profiling, long-term leak proof, external compositor/GPU or battery measurement."]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "production-basic-live-stopped-observations";attachment.lifetime = .keepAlways;add(attachment)
    }

    func testVisibleNativeSceneHostForScreenshot() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioCloudVisibleReviewHost"))
        let appearance = PioResolvedAppearance(context: .cloudDownloading, outfit: .basic, requestedOutfit: .basic,
            stage: 1, pose: .cloudDownloading, motion: .idle, artwork: .existingScene(asset: "routimori_sync_loading"),
            renderer: .originalScene, access: .free, outfitApplied: true, growthCompatible: false,
            animationPreserved: true, missingArtwork: ["independent hands/tablet"], compatibilityNote: nil)
        let content = VStack(spacing: 12) {
            Text(verbatim: AppBrand.name).font(.system(size: 34, weight: .bold, design: .rounded))
            Text("클라우드 · 네이티브 검토 화면").font(.caption)
            RoutimoriSyncScene(kind: .receiving, height: 340, appearanceOverride: appearance)
            Text("기본 피오 · 독립 눈 깜빡임").font(.subheadline)
        }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(white: 0.97))
            .environment(\.scenePhase, .active)
        #if os(macOS)
        let view = NSHostingView(rootView: content);view.frame = CGRect(x: 0, y: 0, width: 402, height: 600)
        let window = NSWindow(contentRect: view.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false;window.contentView = view;window.orderFrontRegardless()
        defer { window.orderOut(nil);window.close() }
        #else
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene);let controller = UIHostingController(rootView: content)
        window.rootViewController = controller;window.makeKeyAndVisible()
        defer { window.isHidden = true }
        #endif
        print("PIO_NATIVE_VISIBLE_REVIEW_READY productionBasic=true candidateFlags=false")
        try await Task.sleep(for: .seconds(8))
    }
    func testProductionOffscreenWindowDetachStopsTracks() async throws {
        #if os(macOS)
        let host = PioCloudSceneHost(frame: CGRect(x: 0, y: 0, width: 220, height: 220));host.wantsLayer = true
        let window = NSWindow(contentRect: host.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false;window.contentView = host
        defer { window.orderOut(nil);window.close() }
        let stage = RoutimoriSyncStage();host.layer!.addSublayer(stage.root)
        #else
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene);let controller = UIViewController()
        window.rootViewController = controller;window.makeKeyAndVisible()
        let host = PioCloudSceneHost(frame: CGRect(x: 20, y: 100, width: 220, height: 220))
        let stage = RoutimoriSyncStage();host.layer.addSublayer(stage.root)
        defer { window.isHidden = true }
        #endif
        let becameVisible = expectation(description: "real native production host becomes visible")
        var receivedVisible = false
        host.visibilityChanged = { visible in
            stage.update(.init(kind: .receiving, height: 220, dark: false, scale: 2, reduceMotion: false,
                outfit: .basic, usesIndependentCharacter: true), isAnimating: visible)
            if visible && !receivedVisible { receivedVisible = true;becameVisible.fulfill() }
        }
        #if os(macOS)
        window.orderFrontRegardless();host.refreshVisibility()
        #else
        controller.view.addSubview(host);host.layoutIfNeeded();host.refreshVisibility()
        #endif
        await fulfillment(of: [becameVisible], timeout: 5)
        XCTAssertGreaterThan(tracks(stage.character), 0, "Detach must start from an actually animating native host")
        host.removeFromSuperview();host.refreshVisibility()
        XCTAssertEqual(tracks(stage.root), 0)
        host.visibilityChanged = nil
    }
    /// Bounded lifecycle accounting, not a memory-growth approval threshold.
    /// Every iteration starts from a genuinely visible native host.
    func testProductionRepeatedAttachDetachObservations() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-PioCloudLifecycleReview"))
        #if os(macOS)
        let parent = NSView(frame: CGRect(x: 0, y: 0, width: 340, height: 340));parent.wantsLayer = true
        let window = NSWindow(contentRect: parent.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false;window.contentView = parent;window.orderFrontRegardless()
        defer { window.orderOut(nil);window.close() }
        #else
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene);let controller = UIViewController()
        window.rootViewController = controller;window.makeKeyAndVisible()
        let parent = controller.view!
        defer { window.isHidden = true }
        #endif
        let initialRSS = rss(), start = Date(), initialCPU = cpu()
        var rows: [[String: Any]] = []
        for index in 1...20 {
            #if os(macOS)
            var host: PioCloudSceneHost? = PioCloudSceneHost(frame: CGRect(x: 40, y: 40, width: 220, height: 220))
            host!.wantsLayer = true
            #else
            var host: PioCloudSceneHost? = PioCloudSceneHost(frame: CGRect(x: 40, y: 120, width: 220, height: 220))
            #endif
            var stage: RoutimoriSyncStage? = RoutimoriSyncStage()
            weak var weakStage = stage;weak var weakHost = host
            let before = rss()
            let visible = expectation(description: "visible production host cycle \(index)")
            var didSeeVisible = false
            host!.visibilityChanged = { shown in
                stage?.update(.init(kind: .receiving, height: 220, dark: false, scale: 2, reduceMotion: false,
                    outfit: .basic, usesIndependentCharacter: true), isAnimating: shown)
                if shown && !didSeeVisible { didSeeVisible = true;visible.fulfill() }
            }
            #if os(macOS)
            host!.layer!.addSublayer(stage!.root)
            #else
            host!.layer.addSublayer(stage!.root)
            #endif
            parent.addSubview(host!);host!.refreshVisibility()
            stage!.root.position = CGPoint(x: 110, y: 110);CATransaction.flush()
            await fulfillment(of: [visible], timeout: 2)
            let activeTracks = tracks(stage!.character)
            XCTAssertGreaterThan(activeTracks, 0, "Lifecycle checks must begin with actual active character tracks")
            try await Task.sleep(for: .milliseconds(150))
            let activeRSS = rss()
            // AppKit's removal path can autorelease temporary references.
            // Drain that deterministic ownership scope before asserting release.
            let detachedTracks = autoreleasepool { () -> Int in
                host!.removeFromSuperview();host!.refreshVisibility()
                let count = tracks(stage!.root)
                stage!.halt();stage!.root.removeFromSuperlayer();host!.visibilityChanged = nil
                stage = nil;host = nil;CATransaction.flush()
                return count
            }
            XCTAssertEqual(detachedTracks, 0, "Detachment itself, before explicit halt, must stop every nested track")
            XCTAssertNil(weakStage);XCTAssertNil(weakHost)
            rows.append(["cycle": index, "actuallyVisible": didSeeVisible, "activeCharacterTracks": activeTracks,
                "beforeRSS": before, "activeRSS": activeRSS, "afterCleanupRSS": rss(),
                "stageReleased": weakStage == nil, "hostReleased": weakHost == nil])
        }
        let report: [String: Any] = ["cycles": rows, "initialRSS": initialRSS, "finalRSS": rss(),
            "seconds": Date().timeIntervalSince(start), "processCPUSeconds": cpu() - initialCPU,
            "scope": "20 production Basic visible attach/start/150ms/stop/detach cycles, same process, no candidate flags, no preferences or StoreKit",
            "limits": "Object release and zero-track assertions are lifecycle checks. RSS is observed, not asserted below an arbitrary threshold. Not long-term leak, Release, battery or external compositor/GPU proof."]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "production-basic-20-cycle-lifecycle-observations";attachment.lifetime = .keepAlways;add(attachment)
    }
    private func tracks(_ layer: CALayer) -> Int {
        (layer.animationKeys()?.count ?? 0) + (layer.sublayers ?? []).reduce(0) { $0 + tracks($1) }
    }
    private func cpu() -> Double {
        var usage = rusage();getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1e6
    }
    private func rss() -> UInt64 {
        var info = mach_task_basic_info();var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)
        let status = withUnsafeMutablePointer(to: &info) { p in
            p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count) }
        }
        return status == KERN_SUCCESS ? UInt64(info.resident_size) : 0
    }
}
