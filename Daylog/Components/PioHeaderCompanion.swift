import SwiftUI
import Observation

enum PioHeaderGesture: String, CaseIterable, Sendable {
    case greet, jump, encourage, rest
    static let tapGestures: [Self] = [.greet, .jump, .encourage]
    var duration: Duration { switch self { case .greet: .milliseconds(2800); case .jump: .milliseconds(2200); case .encourage: .milliseconds(3800); case .rest: .milliseconds(4200) } }
    var motion: PioOutfitMotion { switch self { case .greet: .wave; case .jump: .jump; case .encourage: .celebration; case .rest: .rest } }
    func motion(for outfit: PioOutfitID, independent: Bool) -> PioOutfitMotion {
        if self == .greet, !independent, !PioOutfitCapabilities(outfit: outfit).supportedMotions.contains(.wave) { return .bounce }
        return motion
    }
    var title: String { switch self { case .greet: "인사하는 중"; case .jump: "폴짝 뛰는 중"; case .encourage: "응원하는 중"; case .rest: "잠깐 쉬는 중" } }
}

/// Local response state only. Nothing here equips, unlocks or persists an outfit.
@MainActor @Observable final class PioHeaderInteraction {
    struct Run: Equatable { let token: UInt; let gesture: PioHeaderGesture }
    private(set) var run: Run?
    private(set) var isActive = false
    @ObservationIgnored private var sequence = 0
    @ObservationIgnored private var token: UInt = 0
    @ObservationIgnored private var completion: Task<Void, Never>?
    func setActive(_ active: Bool) {
        guard active != isActive else { return }; isActive = active
        if !active { resetResponse() }
    }
    @discardableResult func respond(to gesture: PioHeaderGesture? = nil) -> Run? {
        guard isActive, run == nil else { return nil }
        token &+= 1
        let next = Run(token: token, gesture: gesture ?? PioHeaderGesture.tapGestures[sequence % PioHeaderGesture.tapGestures.count])
        if gesture == nil { sequence += 1 }; run = next
        completion = Task { [weak self] in
            do { try await Task.sleep(for: next.gesture.duration) } catch { return }
            guard !Task.isCancelled else { return }
            self?.complete(next)
        }
        return next
    }
    @discardableResult func complete(_ expected: Run) -> Bool {
        guard run == expected else { return false }
        completion?.cancel(); completion = nil; run = nil
        return true
    }
    func resetResponse() {
        completion?.cancel(); completion = nil; run = nil; token &+= 1
    }
    deinit { completion?.cancel() }
}

/// The dashboard button owns only its small interaction state; the dashboard
/// never receives a per-frame timer or repeated animation-state publications.
struct PioHeaderCompanion: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var size: CGFloat = 64
    var artworkScale: CGFloat = 1.25
    /// 누를 때 함께 할 일(말풍선 대사 넘기기 등). 인사 동작은 늘 한다.
    var onTap: (() -> Void)? = nil
    @State private var interaction = PioHeaderInteraction()
    @State private var visible = false
    @State private var onScreen = true
    private var appearance: PioResolvedAppearance {
        let base = PioAppearanceCoordinator.shared.resolve(level: store.growth.level, context: .dashboard)
        guard let gesture = interaction.run?.gesture else { return base }
        let independent = PioHomeProductionResources.supports(base)
        return PioAppearanceCoordinator.shared.resolve(level: store.growth.level, context: .dashboard,
            motion: gesture.motion(for: base.outfit, independent: independent))
    }
    private var progress: SaessagiProgress {
        SaessagiProgress(day: store.selectedDay, done: store.checkSections.reduce(0) { $0 + $1.done },
            skipped: store.checkSections.reduce(0) { $0 + $1.skipped })
    }
    private var canAnimate: Bool { visible && onScreen && scenePhase == .active && !reduceMotion && !appearance.isAwaitingVerification }
    var body: some View {
        Button { interaction.respond(); onTap?() } label: {
            Group {
                if appearance.isAwaitingVerification { Color.clear }
                else { character.frame(width: size * artworkScale, height: size * artworkScale) }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(appearance.isAwaitingVerification)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(appearance.isAwaitingVerification ? "피오 의상을 확인하는 중" : "\(appearance.outfit.title), 피오에게 인사하기")
        .accessibilityValue(interaction.run?.gesture.title ?? "편안하게 기다리는 중")
        .accessibilityHint(reduceMotion ? "동작 줄이기가 켜져 있어 편안한 자세를 유지합니다." : "누르면 인사, 점프, 응원을 한 번씩 보여줍니다.")
        .accessibilityIdentifier("pio.header.companion")
        .background(PioHeaderVisibilityProbe { onScreen = $0 })
        .onAppear { visible = true; refreshActivity() }
        .onDisappear { visible = false; interaction.setActive(false) }
        .onChange(of: onScreen) { _, _ in refreshActivity() }
        .onChange(of: scenePhase) { _, _ in refreshActivity() }
        .onChange(of: reduceMotion) { _, _ in refreshActivity() }
        .onChange(of: appearance.isAwaitingVerification) { _, _ in refreshActivity() }
        .onChange(of: appearance.outfit) { _, _ in interaction.resetResponse(); refreshActivity() }
        .onChange(of: progress) { old, new in
            switch SaessagiMood.reaction(from: old, to: new) {
            case .completed: interaction.respond(to: .encourage)
            case .skipped: interaction.respond(to: .rest)
            default: break
            }
        }
    }
    @ViewBuilder private var character: some View {
        if PioHomeProductionResources.supports(appearance) {
            PioHomeProductionCharacter(appearance: appearance, gesture: interaction.run?.gesture, isAnimating: canAnimate)
        } else {
            PioAppearanceView(appearance: appearance, isAnimating: canAnimate).accessibilityHidden(true)
        }
    }
    private func refreshActivity() { interaction.setActive(canAnimate) }
}

#if os(macOS)
private struct PioHeaderVisibilityProbe: NSViewRepresentable {
    let changed: (Bool) -> Void
    final class Coordinator { var visible: Bool? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> PioCloudSceneHost { PioCloudSceneHost() }
    func updateNSView(_ view: PioCloudSceneHost, context: Context) {
        view.visibilityChanged = { [weak coordinator = context.coordinator] value in
            guard let coordinator, coordinator.visible != value else { return }; coordinator.visible = value
            Task { @MainActor in
                guard coordinator.visible == value else { return }
                changed(value)
            }
        }
        view.refreshVisibility()
    }
    static func dismantleNSView(_ view: PioCloudSceneHost, coordinator: Coordinator) { coordinator.visible = nil; view.visibilityChanged = nil }
}
#else
private struct PioHeaderVisibilityProbe: UIViewRepresentable {
    let changed: (Bool) -> Void
    final class Coordinator { var visible: Bool? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> PioCloudSceneHost {
        let view = PioCloudSceneHost(); view.isUserInteractionEnabled = false; return view
    }
    func updateUIView(_ view: PioCloudSceneHost, context: Context) {
        view.visibilityChanged = { [weak coordinator = context.coordinator] value in
            guard let coordinator, coordinator.visible != value else { return }; coordinator.visible = value
            Task { @MainActor in
                guard coordinator.visible == value else { return }
                changed(value)
            }
        }
        view.refreshVisibility()
    }
    static func dismantleUIView(_ view: PioCloudSceneHost, coordinator: Coordinator) { coordinator.visible = nil; view.visibilityChanged = nil }
}
#endif
