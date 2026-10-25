#if DEBUG
import SwiftUI
import QuartzCore

/// A presentation wrapper around the unchanged common rig, not another rig.
@MainActor final class PioHeaderMotionStage {
    let rig = PioOverhaulRig()
    var root: CALayer { rig.root }
    private var outfit: PioOutfitID?
    private var gesture: PioHeaderGesture?
    private(set) var isActive = false
    private var gentleJoints: [String: CAKeyframeAnimation] = [:]
    private var gentlePosture: CAKeyframeAnimation?
    var animationCount: Int { rig.animationCount }
    func update(outfit: PioOutfitID, gesture: PioHeaderGesture?, active: Bool, bounds: CGRect) {
        let changed = self.outfit != outfit || self.gesture != gesture
        if self.outfit != outfit { captureIdleDetails(outfit) }
        self.outfit = outfit; self.gesture = gesture
        if changed { rig.setActive(false); rig.configure(outfit, action: action(gesture)) }
        rig.layout(bounds)
        guard changed || isActive != active else { return }
        isActive = active; rig.setActive(active)
        guard active else { return }
        if gesture == nil {
            for (id, track) in gentleJoints { rig.layers[id]?.add(track, forKey: "transform.rotation.z") }
            if let gentlePosture { rig.movement.add(gentlePosture, forKey: "transform.rotation.z") }
        } else {
            for layer in [rig.movement] + Array(rig.layers.values) {
                for key in layer.animationKeys() ?? [] {
                    guard let track = layer.animation(forKey: key)?.copy() as? CAAnimation else { continue }
                    track.repeatCount = 0; layer.add(track, forKey: key)
                }
            }
        }
    }
    func halt() { isActive = false; rig.setActive(false) }
    private func action(_ gesture: PioHeaderGesture?) -> PioOverhaulAction {
        switch gesture { case .greet: .greet; case .jump: .jump; case .encourage: .encourage; case .rest: .sleepy; case nil: .idle }
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
        track.values = numbers.map { $0 * scale }; track.duration = duration
        track.repeatCount = .infinity
        track.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: max(values.count - 1, 0))
        return track
    }
}

#if os(macOS)
struct PioHeaderNativeCharacter: NSViewRepresentable {
    let outfit: PioOutfitID; let gesture: PioHeaderGesture?; let active: Bool
    @MainActor final class Coordinator { let stage = PioHeaderMotionStage() }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> PioCloudSceneHost {
        let view = PioCloudSceneHost(); view.wantsLayer = true; view.layer?.addSublayer(context.coordinator.stage.root)
        view.hosted = context.coordinator.stage.root; return view
    }
    func updateNSView(_ view: PioCloudSceneHost, context: Context) {
        view.visibilityChanged = { [weak view, weak stage = context.coordinator.stage] visible in
            guard let view else { return }; stage?.update(outfit: outfit, gesture: gesture, active: active && visible, bounds: view.bounds)
        }
        view.refreshVisibility(); view.needsLayout = true
    }
    static func dismantleNSView(_ view: PioCloudSceneHost, coordinator: Coordinator) { view.visibilityChanged = nil; coordinator.stage.halt() }
}
#else
struct PioHeaderNativeCharacter: UIViewRepresentable {
    let outfit: PioOutfitID; let gesture: PioHeaderGesture?; let active: Bool
    @MainActor final class Coordinator { let stage = PioHeaderMotionStage() }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> PioCloudSceneHost {
        let view = PioCloudSceneHost(); view.isUserInteractionEnabled = false
        view.layer.addSublayer(context.coordinator.stage.root); view.hosted = context.coordinator.stage.root; return view
    }
    func updateUIView(_ view: PioCloudSceneHost, context: Context) {
        view.visibilityChanged = { [weak view, weak stage = context.coordinator.stage] visible in
            guard let view else { return }; stage?.update(outfit: outfit, gesture: gesture, active: active && visible, bounds: view.bounds)
        }
        view.refreshVisibility(); view.setNeedsLayout()
    }
    static func dismantleUIView(_ view: PioCloudSceneHost, coordinator: Coordinator) { view.visibilityChanged = nil; coordinator.stage.halt() }
}
#endif
#endif
