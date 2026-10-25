import SwiftUI
import QuartzCore

extension PioHomeProductionResources {
    /// Consume the coordinator's resolved authorization; never infer ownership from art availability.
    static func supports(_ appearance: PioResolvedAppearance) -> Bool {
        guard [.dashboard, .growth].contains(appearance.context), !appearance.isAwaitingVerification else { return false }
        let authorized: Bool
        switch appearance.access {
        case .verified: authorized = appearance.outfit == appearance.requestedOutfit
        case .free, .notOwned, .unavailable: authorized = appearance.outfit == .basic
        #if DEBUG
        case .testing: authorized = appearance.outfit == appearance.requestedOutfit
        #endif
        default: authorized = false
        }
        return authorized && manifest(appearance.outfit) != nil
    }
}

extension PioHomeProductionAction {
    var duration: Duration {
        switch self {
        case .idle: .milliseconds(3600)
        case .bounce: .milliseconds(1200)
        case .walk: .milliseconds(1800)
        case .jump: .milliseconds(2200)
        case .landing: .milliseconds(1500)
        case .celebrate: .milliseconds(2600)
        case .greet: .milliseconds(2800)
        case .sleepy: .milliseconds(4200)
        case .surprised: .milliseconds(2600)
        case .encourage: .milliseconds(3800)
        }
    }
    static func resolve(gesture: PioHeaderGesture) -> Self {
        switch gesture { case .greet: .greet; case .jump: .jump; case .encourage: .encourage; case .rest: .sleepy }
    }
}

/// Bounded playback and quiet idle presentation over the generated canonical rig.
/// The underlying ten authored motion tracks are never rewritten here.
@MainActor final class PioHomeProductionStage {
    let rig = PioHomeProductionRig()
    var root: CALayer { rig.root }
    private var outfit: PioOutfitID?
    private var requestedAction: PioHomeProductionAction = .idle
    private var requestStarted = false
    private(set) var displayedAction: PioHomeProductionAction = .idle
    private(set) var isActive = false
    private var generation: UInt = 0
    private var completion: Task<Void, Never>?
    private var gentleJoints: [String: CAKeyframeAnimation] = [:]
    private var gentlePosture: CAKeyframeAnimation?
    var animationCount: Int { rig.animationCount }

    /// 동작이 끝나는 시각에 `fire`를 부르도록 예약한다. 기본은 실제 시간(`Task.sleep`)이고 앱은 늘 이것을 쓴다.
    /// 테스트는 이 예약을 받아 직접 넘긴다: 전체 테스트 실행에서는 메인 액터가 붐벼 실제 시계로 기다리면
    /// 깨어나는 때가 1초 넘게 밀려(동작 길이와 무관한 실패) 상태 전이를 확인할 수 없었다(2026-10-24).
    var completionScheduler: @MainActor (Duration, @escaping @MainActor () -> Void) -> Task<Void, Never> = PioHomeProductionStage.realTimeScheduler

    static func realTimeScheduler(_ duration: Duration, _ fire: @escaping @MainActor () -> Void) -> Task<Void, Never> {
        Task { @MainActor in
            do { try await Task.sleep(for: duration) } catch { return }
            guard !Task.isCancelled else { return }
            fire()
        }
    }

    func update(outfit: PioOutfitID, action: PioHomeProductionAction, active: Bool, bounds: CGRect) {
        let outfitChanged = self.outfit != outfit
        let requestChanged = requestedAction != action
        let changed = outfitChanged || requestChanged
        if outfitChanged { captureIdleDetails(outfit) }
        self.outfit = outfit; requestedAction = action
        rig.layout(bounds)
        // A short-lived UI event/bubble may clear before its authored motion ends.
        // Record the idle request without cancelling the action's existing deadline.
        if !outfitChanged, requestChanged, action == .idle, isActive, active,
           requestStarted, displayedAction != .idle { return }
        guard changed || isActive != active else { return }
        completion?.cancel(); completion = nil; generation &+= 1
        isActive = active
        if changed {
            requestStarted = false
            displayedAction = action
        } else if active && !requestStarted {
            // SwiftUI first creates the host while visible=false. Its first onAppear
            // must start this pending request, not mistake it for a resumed old event.
            displayedAction = action
        } else {
            // A previously played request does not replay on background/offscreen return.
            displayedAction = .idle
        }
        play()
    }
    func halt() {
        completion?.cancel(); completion = nil; generation &+= 1
        isActive = false; rig.setActive(false)
    }
    /// Called at the authored action boundary; token protects against stale completion after switching.
    func settle() {
        completion?.cancel(); completion = nil
        displayedAction = .idle; play()
    }
    private func play() {
        guard let outfit else { return }
        rig.setActive(false); rig.configure(outfit, action: displayedAction); rig.setActive(isActive)
        guard isActive else { return }
        requestStarted = true
        if displayedAction == .idle {
            for (id, track) in gentleJoints { rig.layers[id]?.add(track, forKey: "transform.rotation.z") }
            if let gentlePosture { rig.movement.add(gentlePosture, forKey: "transform.rotation.z") }
        } else {
            for layer in [rig.movement] + Array(rig.layers.values) {
                for key in layer.animationKeys() ?? [] {
                    guard let track = layer.animation(forKey: key)?.copy() as? CAAnimation else { continue }
                    track.repeatCount = 0; layer.add(track, forKey: key)
                }
            }
            let expected = generation, duration = displayedAction.duration
            completion = completionScheduler(duration) { [weak self] in
                guard let self, self.generation == expected, self.isActive else { return }
                self.settle()
            }
        }
    }
    private func captureIdleDetails(_ outfit: PioOutfitID) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        rig.setActive(false); rig.configure(outfit, action: .greet); rig.setActive(true)
        gentleJoints.removeAll()
        for (id, layer) in rig.layers {
            if let track = smallCopy(layer.animation(forKey: "transform.rotation.z"), scale: 0.06, duration: 17.3) { gentleJoints[id] = track }
        }
        gentlePosture = smallCopy(rig.movement.animation(forKey: "transform.rotation.z"), scale: 0.18, duration: 27.6)
        rig.setActive(false); rig.configure(outfit, action: .idle)
    }
    private func smallCopy(_ source: CAAnimation?, scale: Double, duration: Double) -> CAKeyframeAnimation? {
        guard let track = source?.copy() as? CAKeyframeAnimation, let values = track.values else { return nil }
        let numbers = values.compactMap { ($0 as? NSNumber)?.doubleValue }
        guard numbers.count == values.count else { return nil }
        track.values = numbers.map { $0 * scale }; track.duration = duration; track.repeatCount = .infinity
        track.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: max(values.count - 1, 0))
        return track
    }
    deinit { completion?.cancel() }
}

struct PioHomeProductionCharacter: View {
    let appearance: PioResolvedAppearance
    var gesture: PioHeaderGesture? = nil
    var isAnimating = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    var body: some View {
        Group {
            if PioHomeProductionResources.supports(appearance) {
                PioHomeProductionHost(outfit: appearance.outfit,
                    action: gesture.map(PioHomeProductionAction.resolve(gesture:)) ?? .resolve(motion: appearance.motion, pose: appearance.pose),
                    active: isAnimating && visible && scenePhase == .active && !reduceMotion)
            } else { Color.clear }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
        .onAppear { visible = true }.onDisappear { visible = false }
    }
}

#if os(macOS)
private struct PioHomeProductionHost: NSViewRepresentable {
    let outfit: PioOutfitID; let action: PioHomeProductionAction; let active: Bool
    @MainActor final class Coordinator { let stage = PioHomeProductionStage() }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> PioCloudSceneHost {
        let view = PioCloudSceneHost(); view.wantsLayer = true; view.layer?.addSublayer(context.coordinator.stage.root)
        view.hosted = context.coordinator.stage.root; return view
    }
    func updateNSView(_ view: PioCloudSceneHost, context: Context) {
        view.visibilityChanged = { [weak view, weak stage = context.coordinator.stage] visible in
            guard let view else { return }; stage?.update(outfit: outfit, action: action, active: active && visible, bounds: view.bounds)
        }
        view.refreshVisibility(); view.needsLayout = true
    }
    static func dismantleNSView(_ view: PioCloudSceneHost, coordinator: Coordinator) { view.visibilityChanged = nil; coordinator.stage.halt() }
}
#else
private struct PioHomeProductionHost: UIViewRepresentable {
    let outfit: PioOutfitID; let action: PioHomeProductionAction; let active: Bool
    @MainActor final class Coordinator { let stage = PioHomeProductionStage() }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> PioCloudSceneHost {
        let view = PioCloudSceneHost(); view.isUserInteractionEnabled = false
        view.layer.addSublayer(context.coordinator.stage.root); view.hosted = context.coordinator.stage.root; return view
    }
    func updateUIView(_ view: PioCloudSceneHost, context: Context) {
        view.visibilityChanged = { [weak view, weak stage = context.coordinator.stage] visible in
            guard let view else { return }; stage?.update(outfit: outfit, action: action, active: active && visible, bounds: view.bounds)
        }
        view.refreshVisibility(); view.setNeedsLayout()
    }
    static func dismantleUIView(_ view: PioCloudSceneHost, coordinator: Coordinator) { view.visibilityChanged = nil; coordinator.stage.halt() }
}
#endif
