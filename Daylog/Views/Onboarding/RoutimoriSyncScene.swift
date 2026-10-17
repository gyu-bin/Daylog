import QuartzCore
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Trial artwork is selected only by the existing DEBUG character switch.
/// The scene receives display state; it never queries or completes a cloud operation.
struct RoutimoriSyncScene: View {
    let kind: SyncSceneKind
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @State private var isVisible = false

    private var appearance: PioResolvedAppearance {
        PioAppearanceCoordinator.shared.resolve(context: kind.pioAppearanceContext)
    }
    private var characterAssetName: String? {
        if case .existingScene(let asset) = appearance.artwork { return asset }
        return nil
    }

    var body: some View {
        RoutimoriSyncLayerView(
            configuration: .init(kind: kind, height: height, dark: colorScheme == .dark,
                                 scale: displayScale, reduceMotion: reduceMotion,
                                 characterAssetName: characterAssetName),
            isAnimating: isVisible && scenePhase == .active && !reduceMotion
        )
        .frame(width: height, height: height)
        .accessibilityHidden(true)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

extension SyncSceneKind {
    var pioAppearanceContext: PioAppearanceContext {
        switch self {
        case .receiving: .cloudDownloading
        case .ready: .cloudCompleted
        case .trouble: .cloudFailed
        }
    }
}

enum RoutimoriSyncStyle {
    static let green = Color(red: 0.28, green: 0.43, blue: 0.23)
    static func ink(dark: Bool) -> Color {
        dark ? Color(red: 0.85, green: 0.9, blue: 0.77) : Color(red: 0.21, green: 0.33, blue: 0.17)
    }
    static func background(dark: Bool) -> [Color] {
        dark ? [Color(red: 0.12, green: 0.15, blue: 0.12), Color(red: 0.08, green: 0.1, blue: 0.08)]
             : [Color(red: 0.98, green: 0.97, blue: 0.92), Color(red: 0.96, green: 0.94, blue: 0.87)]
    }
}

struct RoutimoriSyncBrand: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: "leaf.fill").font(.system(size: 19, weight: .medium))
                .rotationEffect(.degrees(-28)).accessibilityHidden(true)
            Text("Routimori").font(.system(size: 34, weight: .bold, design: .rounded))
            Text("조금씩, 더 나은 나로").font(.subheadline)
        }
        .foregroundStyle(RoutimoriSyncStyle.ink(dark: colorScheme == .dark))
    }
}

/// A traveling segment is an activity indicator, never a fabricated completion percentage.
struct RoutimoriSyncActivity: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    var body: some View {
        VStack(spacing: 10) {
            RoutimoriActivityLayerView(isAnimating: isVisible && !reduceMotion && scenePhase == .active)
                .frame(width: 240, height: 8)
                .accessibilityElement().accessibilityLabel("iCloud 기록 확인 중")
            Text("조금만 기다려 주세요.").font(.footnote).foregroundStyle(.secondary)
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

@MainActor
final class RoutimoriSyncStage {
    struct Configuration: Equatable {
        var kind: SyncSceneKind
        var height: CGFloat
        var dark: Bool
        var scale: CGFloat
        var reduceMotion: Bool
        /// A scene-specific approved asset, resolved centrally. This is never a
        /// standing costume pasted onto the tablet or expressive scene pose.
        var characterAssetName: String? = nil
    }
    let root = CALayer()
    let character = CALayer()
    let cloud = CALayer()
    let glyph = CALayer()
    private(set) var configuration: Configuration?
    private var isAnimating = false

    func update(_ configuration: Configuration, isAnimating: Bool) {
        let changed = self.configuration != configuration
        if changed {
            self.configuration = configuration
            build(configuration)
        }
        animate(isAnimating && !configuration.reduceMotion, force: changed)
    }

    func halt() { animate(false, force: true) }

    private func build(_ config: Configuration) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        root.sublayers?.forEach { $0.removeFromSuperlayer() }
        root.bounds = CGRect(x: 0, y: 0, width: config.height, height: config.height)
        let u = config.height / 340
        for layer in [cloud, glyph, character] {
            layer.removeAllAnimations()
            layer.transform = CATransform3DIdentity
            layer.contentsScale = config.scale
            layer.contentsGravity = .resizeAspect
            root.addSublayer(layer)
        }
        cloud.bounds = CGRect(x: 0, y: 0, width: 160 * u, height: 90 * u)
        cloud.position = point(170 * u, 57 * u, config.height)
        cloud.contents = render(
            CloudShape().fill(LinearGradient(colors: [.white, Color(red: 0.91, green: 0.93, blue: 0.9)],
                                             startPoint: .top, endPoint: .bottom))
                .frame(width: 148 * u, height: 78 * u).padding(6 * u), scale: config.scale)
        cloud.shadowColor = CGColor(gray: 0, alpha: 1)
        cloud.shadowOpacity = config.dark ? 0.14 : 0.08
        cloud.shadowRadius = 5 * u
        cloud.shadowOffset = CGSize(width: 0, height: down(3 * u))

        let symbol: String = switch config.kind {
        case .receiving: "arrow.down"
        case .ready: "checkmark"
        case .trouble: "xmark"
        }
        let color = config.kind == .trouble ? Color(red: 0.78, green: 0.39, blue: 0.32) : RoutimoriSyncStyle.green
        glyph.bounds = CGRect(x: 0, y: 0, width: 46 * u, height: 46 * u)
        glyph.position = point(170 * u, (config.kind == .receiving ? 112 : 61) * u, config.height)
        glyph.contents = render(Image(systemName: symbol).font(.system(size: 32 * u, weight: .bold))
            .foregroundStyle(color).frame(width: 46 * u, height: 46 * u), scale: config.scale)

        let originalAsset: String = switch config.kind {
        case .receiving: "routimori_sync_loading"
        case .ready: "routimori_sync_success"
        case .trouble: "routimori_sync_failure"
        }
        let asset = config.characterAssetName ?? originalAsset
        #if os(macOS)
        character.contents = NSImage(named: asset)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        character.contents = UIImage(named: asset)?.cgImage
        #endif
        // Square canvas, aspect fit: source resolution is deliberately not assumed to be 1024.
        character.bounds = CGRect(x: 0, y: 0, width: 256 * u, height: 256 * u)
        character.position = point(170 * u, 226 * u, config.height)
    }

    private func animate(_ enabled: Bool, force: Bool) {
        guard let config = configuration, force || enabled != isAnimating else { return }
        isAnimating = enabled
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        for layer in [character, cloud, glyph] {
            layer.removeAllAnimations()
            layer.transform = CATransform3DIdentity
        }
        guard enabled else { return }
        let u = config.height / 340
        character.add(track("transform.scale", [1, 1.018, 1], duration: 3.8), forKey: "breathing")
        cloud.add(track("transform.translation.y", [0, down(-3 * u), 0], duration: 4.6), forKey: "float")
        switch config.kind {
        case .receiving:
            character.add(track("transform.rotation.z", [0, 0.018, 0, -0.018, 0], duration: 6), forKey: "attention")
            glyph.add(track("transform.translation.y", [down(-3 * u), down(5 * u), down(-3 * u)], duration: 1.8), forKey: "receiving")
        case .ready:
            character.add(track("transform.translation.y", [0, down(-10 * u), 0, down(-4 * u), 0],
                                duration: 1.4, repeats: false), forKey: "celebration")
            glyph.add(track("transform.scale", [1, 1.13, 1], duration: 1.1, repeats: false), forKey: "confirmation")
        case .trouble:
            // A single concerned tilt settles gently; an error must not shake forever.
            character.add(track("transform.rotation.z", [0, -0.045, 0.018, 0], duration: 2.3, repeats: false), forKey: "concern")
        }
    }

    private func track(_ keyPath: String, _ values: [CGFloat], duration: Double, repeats: Bool = true) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = values.map { NSNumber(value: Double($0)) }
        animation.duration = duration
        animation.calculationMode = .linear
        animation.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: values.count - 1)
        animation.repeatCount = repeats ? .infinity : 0
        return animation
    }

    private func render<V: View>(_ view: V, scale: CGFloat) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.cgImage
    }

    private func point(_ x: CGFloat, _ y: CGFloat, _ height: CGFloat) -> CGPoint {
        #if os(macOS)
        CGPoint(x: x, y: height - y)
        #else
        CGPoint(x: x, y: y)
        #endif
    }
    private func down(_ value: CGFloat) -> CGFloat {
        #if os(macOS)
        -value
        #else
        value
        #endif
    }
}

#if os(macOS)
private struct RoutimoriSyncLayerView: NSViewRepresentable {
    let configuration: RoutimoriSyncStage.Configuration
    let isAnimating: Bool
    final class Coordinator { @MainActor lazy var stage = RoutimoriSyncStage() }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> SyncLayerHost {
        let view = SyncLayerHost()
        view.wantsLayer = true
        view.layer?.addSublayer(context.coordinator.stage.root)
        view.hosted = context.coordinator.stage.root
        return view
    }
    func updateNSView(_ view: SyncLayerHost, context: Context) {
        context.coordinator.stage.update(configuration, isAnimating: isAnimating)
        view.needsLayout = true
    }
    static func dismantleNSView(_ view: SyncLayerHost, coordinator: Coordinator) { coordinator.stage.halt() }
}
#else
private struct RoutimoriSyncLayerView: UIViewRepresentable {
    let configuration: RoutimoriSyncStage.Configuration
    let isAnimating: Bool
    final class Coordinator { @MainActor lazy var stage = RoutimoriSyncStage() }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> SyncLayerHost {
        let view = SyncLayerHost()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.layer.addSublayer(context.coordinator.stage.root)
        view.hosted = context.coordinator.stage.root
        return view
    }
    func updateUIView(_ view: SyncLayerHost, context: Context) {
        context.coordinator.stage.update(configuration, isAnimating: isAnimating)
        view.setNeedsLayout()
    }
    static func dismantleUIView(_ view: SyncLayerHost, coordinator: Coordinator) { coordinator.stage.halt() }
}
#endif

/// The capsule runs back and forth and exposes no numeric accessibility value.
@MainActor
final class RoutimoriSyncActivityStage {
    let root = CALayer()
    let segment = CALayer()
    private var isAnimating = false
    init() {
        root.bounds = CGRect(x: 0, y: 0, width: 240, height: 8)
        root.cornerRadius = 4
        root.backgroundColor = CGColor(red: 0.47, green: 0.57, blue: 0.38, alpha: 0.18)
        segment.bounds = CGRect(x: 0, y: 0, width: 76, height: 8)
        segment.position = CGPoint(x: 120, y: 4)
        segment.cornerRadius = 4
        segment.backgroundColor = CGColor(red: 0.39, green: 0.55, blue: 0.3, alpha: 1)
        root.addSublayer(segment)
    }
    func update(isAnimating: Bool) {
        guard self.isAnimating != isAnimating else { return }
        self.isAnimating = isAnimating
        segment.removeAllAnimations()
        guard isAnimating else { return }
        let motion = CABasicAnimation(keyPath: "transform.translation.x")
        motion.fromValue = -80
        motion.toValue = 80
        motion.duration = 1.7
        motion.autoreverses = true
        motion.repeatCount = .infinity
        motion.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        segment.add(motion, forKey: "activity")
    }
}

#if os(macOS)
private struct RoutimoriActivityLayerView: NSViewRepresentable {
    let isAnimating: Bool
    final class Coordinator { @MainActor lazy var stage = RoutimoriSyncActivityStage() }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> SyncLayerHost {
        let view = SyncLayerHost()
        view.wantsLayer = true
        view.layer?.addSublayer(context.coordinator.stage.root)
        view.hosted = context.coordinator.stage.root
        return view
    }
    func updateNSView(_ view: SyncLayerHost, context: Context) {
        context.coordinator.stage.update(isAnimating: isAnimating)
        view.needsLayout = true
    }
    static func dismantleNSView(_ view: SyncLayerHost, coordinator: Coordinator) {
        coordinator.stage.update(isAnimating: false)
    }
}
#else
private struct RoutimoriActivityLayerView: UIViewRepresentable {
    let isAnimating: Bool
    final class Coordinator { @MainActor lazy var stage = RoutimoriSyncActivityStage() }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> SyncLayerHost {
        let view = SyncLayerHost()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.layer.addSublayer(context.coordinator.stage.root)
        view.hosted = context.coordinator.stage.root
        return view
    }
    func updateUIView(_ view: SyncLayerHost, context: Context) {
        context.coordinator.stage.update(isAnimating: isAnimating)
        view.setNeedsLayout()
    }
    static func dismantleUIView(_ view: SyncLayerHost, coordinator: Coordinator) {
        coordinator.stage.update(isAnimating: false)
    }
}
#endif
