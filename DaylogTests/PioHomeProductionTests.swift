import Testing
import QuartzCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import Daylog

@MainActor struct PioHomeProductionTests {
    @Test func allFourteenRegistrationsHaveGenuineSizedLayers() throws {
        #expect(PioOutfitID.allCases.count == 14)
        for outfit in PioOutfitID.allCases {
            let manifest = try #require(PioHomeProductionResources.manifest(outfit))
            #expect(manifest.outfit == outfit.rawValue && manifest.canvas == 1254)
            for part in manifest.parts {
                let image = try #require(PioHomeProductionResources.image(part.asset))
                #expect(image.width == Int(part.rect[2]) && image.height == Int(part.rect[3]))
                #expect(part.asset.hasPrefix("pio_home_production_"))
            }
        }
    }

    #if DEBUG
    @Test func all140ProductionTimelinesMatchProtectedCanonicalRig() throws {
        for outfit in PioOutfitID.allCases {
            let canonical = PioOverhaulRig(), production = PioHomeProductionRig()
            for action in PioHomeProductionAction.allCases {
                canonical.configure(outfit, action: try #require(PioOverhaulAction(rawValue: action.rawValue)))
                production.configure(outfit, action: action)
                canonical.setActive(true); production.setActive(true)
                #expect(Set(canonical.layers.keys) == Set(production.layers.keys))
                try compare(canonical.movement, production.movement)
                for (id, a) in canonical.layers { try compare(a, try #require(production.layers[id])) }
                canonical.setActive(false); production.setActive(false)
            }
        }
    }
    private func compare(_ a: CALayer, _ b: CALayer) throws {
        #expect(a.position == b.position && a.anchorPoint == b.anchorPoint && a.bounds == b.bounds && a.zPosition == b.zPosition)
        #expect(Set(a.animationKeys() ?? []) == Set(b.animationKeys() ?? []))
        for key in a.animationKeys() ?? [] {
            let x = try #require(a.animation(forKey: key) as? CAKeyframeAnimation)
            let y = try #require(b.animation(forKey: key) as? CAKeyframeAnimation)
            #expect(x.values as? [Double] == y.values as? [Double])
            #expect(x.keyTimes == y.keyTimes && x.duration == y.duration && x.repeatCount == y.repeatCount && x.calculationMode == y.calculationMode)
        }
    }
    #endif

    @Test func boundedActionsReturnToQuietIdleAndLifecycleStopsAllTracks() throws {
        let stage = PioHomeProductionStage(), bounds = CGRect(x: 0, y: 0, width: 220, height: 220)
        for outfit in PioOutfitID.allCases {
            for action in PioHomeProductionAction.allCases where action != .idle {
                stage.update(outfit: outfit, action: action, active: true, bounds: bounds)
                #expect(stage.displayedAction == action)
                for layer in [stage.rig.movement] + Array(stage.rig.layers.values) {
                    for key in layer.animationKeys() ?? [] { #expect(layer.animation(forKey: key)?.repeatCount == 0) }
                }
                stage.settle(); #expect(stage.displayedAction == .idle)
                #expect(stage.animationCount > 0)
                let body = try #require(stage.rig.layers["body"])
                stage.update(outfit: outfit, action: action, active: true, bounds: bounds)
                #expect(stage.displayedAction == .idle) // same event does not restart after completion
                #expect(stage.rig.layers["body"] === body)
                stage.halt(); #expect(stage.animationCount == 0)
            }
        }
    }

    @Test func homeProductionDoesNotGrantPreviewOrUnverifiedPaidAccess() {
        func appearance(_ outfit: PioOutfitID, _ access: PioAppearanceAccess, context: PioAppearanceContext = .dashboard) -> PioResolvedAppearance {
            PioResolvedAppearance(context: context, outfit: outfit, requestedOutfit: outfit, stage: 1,
                pose: .standing, motion: .idle, artwork: .unavailable, renderer: .unavailable, access: access,
                outfitApplied: true, growthCompatible: false, animationPreserved: false, missingArtwork: [], compatibilityNote: nil)
        }
        #expect(PioHomeProductionResources.supports(appearance(.basic, .free)))
        #expect(PioHomeProductionResources.supports(appearance(.christmas, .verified)))
        for access in [PioAppearanceAccess.checking, .verificationUnavailable, .notOwned, .unavailable, .preview, .free] {
            #expect(!PioHomeProductionResources.supports(appearance(.christmas, access)))
        }
        #expect(!PioHomeProductionResources.supports(appearance(.basic, .free, context: .cloudDownloading)))
    }

    @Test func quietIdleHasIndependentSlowJointsWithoutTranslationHops() throws {
        let stage = PioHomeProductionStage()
        stage.update(outfit: .basic, action: .idle, active: true, bounds: CGRect(x: 0, y: 0, width: 64, height: 64))
        let y = try #require(stage.rig.movement.animation(forKey: "transform.translation.y") as? CAKeyframeAnimation)
        #expect((y.values as? [Double])?.allSatisfy { $0 == 0 } == true)
        let joint = try #require(stage.rig.layers["wingRight"]?.animation(forKey: "transform.rotation.z") as? CAKeyframeAnimation)
        #expect(joint.duration == 17.3)
        #expect((joint.values as? [Double])?.contains { $0 != 0 } == true)
        stage.halt(); #expect(stage.animationCount == 0)
    }

    /// 동작 완료 예약을 실제 시계 대신 테스트가 넘긴다. 예약된 길이와, 끝났을 때 실제 완료 코드가 하는 일을 확인한다.
    /// (전체 실행에서 메인 액터가 붐벼 실제 시계 대기가 1초 넘게 밀리던 불안정, 2026-10-24.) 동작 길이·연출은 그대로다.
    @MainActor private final class ManualCompletionClock {
        private(set) var scheduled: [Duration] = []
        private var pending: [(fire: @MainActor () -> Void, task: Task<Void, Never>)] = []
        func schedule(_ duration: Duration, _ fire: @escaping @MainActor () -> Void) -> Task<Void, Never> {
            let task = Task<Void, Never> {}
            scheduled.append(duration); pending.append((fire, task))
            return task
        }
        /// 가장 최근 예약의 시각이 된 것처럼 완료를 부른다. 그 사이 취소된 예약이면 부르지 않는다(실제 예약과 같다).
        func elapseLatest() {
            guard let last = pending.popLast(), !last.task.isCancelled else { return }
            last.fire()
        }
    }

    @Test func firstInactiveRequestStartsWhenVisibleButPlayedRequestDoesNotReplay() async throws {
        let stage = PioHomeProductionStage(), bounds = CGRect(x: 0, y: 0, width: 220, height: 220)
        let clock = ManualCompletionClock(); stage.completionScheduler = clock.schedule
        defer { stage.halt() }
        stage.update(outfit: .basic, action: .jump, active: false, bounds: bounds)
        #expect(stage.animationCount == 0)
        stage.update(outfit: .basic, action: .jump, active: true, bounds: bounds)
        #expect(stage.displayedAction == .jump && stage.animationCount > 0)
        stage.update(outfit: .basic, action: .jump, active: false, bounds: bounds)
        #expect(stage.animationCount == 0)
        stage.update(outfit: .basic, action: .jump, active: true, bounds: bounds)
        #expect(stage.displayedAction == .idle)
        // A different outfit/request created while invisible is genuinely pending.
        stage.update(outfit: .hanbok, action: .greet, active: false, bounds: bounds)
        #expect(stage.animationCount == 0)
        stage.update(outfit: .hanbok, action: .greet, active: true, bounds: bounds)
        #expect(stage.displayedAction == .greet)
        // 인사 동작의 완료는 작성된 길이(2.8초)에 예약되고, 그때 실제 완료 코드가 idle로 되돌린다.
        #expect(clock.scheduled.last == PioHomeProductionAction.greet.duration)
        #expect(clock.scheduled.last == .milliseconds(2800))
        clock.elapseLatest()
        #expect(stage.displayedAction == .idle && stage.isActive)
    }

    @Test func growthBubbleDismissalDoesNotCutOffAuthoredCelebration() async throws {
        let stage = PioHomeProductionStage(), bounds = CGRect(x: 0, y: 0, width: 220, height: 220)
        let clock = ManualCompletionClock(); stage.completionScheduler = clock.schedule
        let host = try LiveLayerHost(bounds: bounds)
        host.layer.addSublayer(stage.root)
        defer { stage.halt(); host.close() }
        stage.update(outfit: .basic, action: .celebrate, active: true, bounds: bounds)
        CATransaction.flush()
        #expect(stage.rig.movement.animation(forKey: "transform.translation.x")?.duration == 2.6)
        #expect(clock.scheduled == [.milliseconds(2600)])
        print("celebrate hosted start keys=\(stage.rig.movement.animationKeys() ?? [])")
        // GrowthCard의 말풍선이 동작 도중(1.8초)에 사라져 idle을 요청한다. 그 요청이 축하 동작을 끊지 않아야 한다.
        stage.update(outfit: .basic, action: .idle, active: true, bounds: bounds)
        CATransaction.flush()
        #expect(stage.displayedAction == .celebrate)
        print("celebrate hosted after idle request keys=\(stage.rig.movement.animationKeys() ?? []) presentation=\(stage.rig.movement.presentation() != nil)")
        #expect(stage.rig.movement.presentation() != nil)
        #expect(stage.rig.movement.animation(forKey: "transform.translation.x")?.duration == 2.6)
        // idle 요청은 기존 2.6초 마감을 취소하거나 새로 잡지 않는다.
        #expect(clock.scheduled == [.milliseconds(2600)])
        clock.elapseLatest()
        #expect(stage.displayedAction == .idle)
        stage.update(outfit: .basic, action: .idle, active: true, bounds: bounds)
        #expect(stage.displayedAction == .idle) // cleared bubble cannot replay the event
    }

    @Test func outfitSwitchCancelsOldDeadlineWithoutInterruptingNewAction() async throws {
        let stage = PioHomeProductionStage(), bounds = CGRect(x: 0, y: 0, width: 220, height: 220)
        defer { stage.halt() }
        stage.update(outfit: .basic, action: .jump, active: true, bounds: bounds)
        stage.update(outfit: .astronaut, action: .encourage, active: true, bounds: bounds)
        #expect(stage.rig.layers["visor"] != nil)
        try await Task.sleep(for: .milliseconds(2400)) // beyond cancelled jump's 2.2-second deadline
        #expect(stage.displayedAction == .encourage)
        try await waitForAuthoredCompletion(stage, timeout: .seconds(2.4))
        #expect(stage.displayedAction == .idle)
        stage.update(outfit: .christmas, action: .greet, active: true, bounds: bounds)
        stage.halt()
        #expect(stage.animationCount == 0)
        stage.update(outfit: .christmas, action: .greet, active: true, bounds: bounds)
        #expect(stage.displayedAction == .idle)
    }

    /// A real render tree is essential when checking a finite CA track after an await.
    /// Unhosted layers are only appropriate for synchronous timeline structure checks.
    private final class LiveLayerHost {
        let layer: CALayer
        #if os(macOS)
        let window: NSWindow
        #else
        let window: UIWindow
        #endif
        init(bounds: CGRect) throws {
            #if os(macOS)
            let view = NSView(frame: bounds)
            view.wantsLayer = true
            window = NSWindow(contentRect: bounds, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = view
            window.orderFrontRegardless()
            layer = try #require(view.layer)
            #else
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            window = UIWindow(windowScene: scene)
            let controller = UIViewController()
            window.rootViewController = controller
            window.makeKeyAndVisible()
            let view = UIView(frame: bounds)
            controller.view.addSubview(view)
            layer = view.layer
            #endif
        }
        func close() {
            layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            #if os(macOS)
            window.orderOut(nil); window.close()
            #else
            window.isHidden = true; window.rootViewController = nil
            #endif
        }
    }

    private func waitForAuthoredCompletion(_ stage: PioHomeProductionStage, timeout: Duration) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while stage.displayedAction != .idle && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(stage.displayedAction == .idle, "Real completion task must settle; no manual settle() in this regression")
    }

}
