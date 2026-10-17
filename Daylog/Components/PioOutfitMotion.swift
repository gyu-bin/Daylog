import SwiftUI
import QuartzCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum PioOutfitMotion: String, CaseIterable, Identifiable, Sendable {
    case idle, bounce, jump, landing, celebration, rest, wave
    var id: String { rawValue }
    var title: String {
        switch self {
        case .idle: "숨쉬기"
        case .bounce: "통통 뛰기"
        case .jump: "점프"
        case .landing: "착지"
        case .celebration: "기뻐하기"
        case .rest: "쉬기"
        case .wave: "날개 인사"
        }
    }
}

enum PioOutfitStageSupport: String, Sendable {
    case partial = "PARTIAL"
    case unsupported = "NOT_SUPPORTED"
}

/// These are capabilities of the approved *flattened* artwork, not promises
/// that costume parts, eyes or growth-stage silhouettes have been authored.
struct PioOutfitCapabilities: Sendable {
    let outfit: PioOutfitID
    var supportedMotions: [PioOutfitMotion] {
        let body: [PioOutfitMotion] = [.idle, .bounce, .jump, .landing, .celebration, .rest]
        return outfit == .basic ? body + [.wave] : body
    }
    var hasIndependentWingWave: Bool { outfit == .basic }
    var hasIndependentBlink: Bool { false }
    var hasIndependentWalk: Bool { false }
    var hasIndependentRun: Bool { false }
    var hasIndependentFlap: Bool { false }
    var hasStageSpecificArtwork: Bool { false }
    var isFlattenedCostume: Bool { outfit != .basic }
    func stageSupport(_ stage: Int) -> PioOutfitStageSupport {
        (1...4).contains(stage) ? .partial : .unsupported
    }
}

/// 앱의 캐릭터는 피오다(새싹이 화면은 쓰지 않는다). 실제 앱(Release)에서는 늘 켜져 있다.
/// 검증용 앱에서는 예전 새싹이 화면과 비교할 때만 `-DaylogDebugCharacter saessagi`로 끄고, 주황 피오 시범(`pio`)과는 겹치지 않는다.
/// 단위 테스트는 예전처럼 명시한 시범 인자로만 켠다(새싹이 화면을 검사하는 테스트가 그대로 돈다).
enum PioCharacter {
    static var isEnabled: Bool {
        #if DEBUG
        if RuntimeEnvironment.isRunningTests { return RoutimoriSplashTrial.isEnabled }
        return UserDefaults.standard.string(forKey: "DaylogDebugCharacter") != "saessagi" && !PioTrial.isEnabled
        #else
        true
        #endif
    }
}

/// All stages deliberately retain the same original art;
/// the stage number never silently scales or replaces an equipped costume.
struct PioOutfitMotionView: View {
    static var isTrialEnabled: Bool { PioCharacter.isEnabled }
    let outfit: PioOutfitID
    var stage: Int = 1
    var motion: PioOutfitMotion = .idle
    var isAnimating = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    @State private var onScreen = true

    var body: some View {
        Group {
            if Self.isTrialEnabled, PioOutfitMotionImageCache.image(for: outfit) != nil {
                PioOutfitMotionHost(outfit: outfit, stage: stage, motion: motion,
                    isAnimating: isAnimating && visible && onScreen && scenePhase == .active && !reduceMotion)
            } else {
                still
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .modifier(PioOutfitMotionVisibility(onScreen: $onScreen))
    }

    private var still: some View {
        Group {
            if let image = stillImage {
                image.resizable().scaledToFit()
            } else {
                Image(systemName: outfit.symbol).resizable().scaledToFit()
                    .padding(24).foregroundStyle(.secondary)
            }
        }
    }

    private var stillImage: Image? {
        guard let name = outfit.artAssetName else { return nil }
        #if os(macOS)
        guard let image = NSImage(named: name) else { return nil }
        return Image(nsImage: image)
        #else
        guard let image = UIImage(named: name) else { return nil }
        return Image(uiImage: image)
        #endif
    }
}

private struct PioOutfitMotionVisibility: ViewModifier {
    @Binding var onScreen: Bool
    func body(content: Content) -> some View {
        if #available(macOS 15.0, iOS 18.0, *) {
            content.onScrollVisibilityChange(threshold: 0.05) { onScreen = $0 }
        } else {
            content
        }
    }
}

/// Passive counters: reading/resetting a snapshot never invalidates SwiftUI,
/// clears an image cache, or changes the renderer's animation/layout behavior.
@MainActor
enum PioOutfitMotionDiagnostics {
    enum Event: String, CaseIterable {
        case hostUpdates, nativeRefreshes, layoutCalls, effectiveLayouts
        case layoutTransactions, configurations, sourceLoads
    }
    private static var counts: [Event: Int] = [:]
    private final class WeakRig {
        weak var value: PioOutfitMotionRig?
        init(_ value: PioOutfitMotionRig) { self.value = value }
    }
    private static var active: [ObjectIdentifier: WeakRig] = [:]
    static var snapshot: [String: Int] {
        var result = Dictionary(uniqueKeysWithValues: Event.allCases.map { ($0.rawValue, counts[$0, default: 0]) })
        result["cachedImages"] = PioOutfitMotionImageCache.cachedImageCount
        // A destroyed host/test rig must not stay active merely because it did
        // not receive a final stop callback. Weak references also avoid retention.
        active = active.filter { $0.value.value?.isAnimating == true }
        let rigs = active.values.compactMap(\.value)
        result["activeRigs"] = rigs.count
        result["activeAnimationTracks"] = rigs.reduce(0) { $0 + $1.animationCount }
        return result
    }
    static func reset() { counts.removeAll(keepingCapacity: true) }
    static func record(_ event: Event) { counts[event, default: 0] += 1 }
    static func setActive(_ isActive: Bool, rig: PioOutfitMotionRig) {
        let id = ObjectIdentifier(rig)
        if isActive { active[id] = WeakRig(rig) }
        else { active.removeValue(forKey: id) }
    }
}

@MainActor
enum PioOutfitMotionImageCache {
    private static var images: [String: CGImage] = [:]
    private(set) static var decodeCount = 0
    static var cachedImageCount: Int { images.count }
    static func image(for outfit: PioOutfitID) -> CGImage? {
        guard let name = outfit.artAssetName else { return nil }
        if let cached = images[name] { return cached }
        #if os(macOS)
        let image = NSImage(named: name)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        let image = UIImage(named: name)?.cgImage
        #endif
        guard let image else { return nil }
        // The catalog bounds this cache at fourteen decoded source images.
        images[name] = image
        decodeCount += 1
        PioOutfitMotionDiagnostics.record(.sourceLoads)
        return image
    }
}

@MainActor
final class PioOutfitMotionRig {
    let root = CALayer()
    let canvas = CALayer()
    let artwork = CALayer()
    private var approvedWave: RoutimoriSplashRig?
    private(set) var outfit: PioOutfitID?
    private(set) var motion: PioOutfitMotion = .idle
    private(set) var stage = 1
    private(set) var configurationCount = 0
    private(set) var isAnimating = false
    private var source: CGImage?
    private var configuration: Configuration?
    // Diagnostic comparison only; repeated layouts still execute unchanged.
    private var measuredLayout: MeasuredLayout?
    private struct MeasuredLayout: Equatable {
        let bounds: CGRect
        let displayScale: CGFloat
    }
    private struct Configuration: Equatable {
        let outfit: PioOutfitID
        let motion: PioOutfitMotion
    }
    static let canvasSide: CGFloat = 1000

    init() {
        root.addSublayer(canvas)
        canvas.bounds = CGRect(x: 0, y: 0, width: Self.canvasSide, height: Self.canvasSide)
        canvas.addSublayer(artwork)
        artwork.contentsGravity = .resize
        artwork.minificationFilter = .trilinear
    }

    var animationCount: Int {
        func count(_ layer: CALayer) -> Int {
            (layer.animationKeys()?.count ?? 0) + (layer.sublayers ?? []).reduce(0) { $0 + count($1) }
        }
        return count(root)
    }

    func configure(outfit: PioOutfitID, stage: Int, motion requested: PioOutfitMotion) {
        self.stage = min(max(stage, 1), 4)
        let supported = PioOutfitCapabilities(outfit: outfit).supportedMotions
        let motion = supported.contains(requested) ? requested : .idle
        let next = Configuration(outfit: outfit, motion: motion)
        guard configuration != next else { return }
        let resume = isAnimating
        setAnimating(false)
        configuration = next
        configurationCount += 1
        PioOutfitMotionDiagnostics.record(.configurations)
        self.outfit = outfit
        self.motion = motion
        source = PioOutfitMotionImageCache.image(for: outfit)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        approvedWave?.canvas.removeFromSuperlayer()
        artwork.isHidden = outfit == .basic && motion == .wave
        if artwork.isHidden {
            // The wardrobe basic PNG is byte-identical to the approved splash
            // image. Keep its exact masks, source pivot and modest wave track.
            if approvedWave == nil { approvedWave = RoutimoriSplashRig(image: source) }
            if let approvedWave {
                canvas.addSublayer(approvedWave.canvas)
                approvedWave.layout(in: canvas.bounds, displayScale: 1)
            }
        } else if let source {
            artwork.contents = source
            let scale = Self.canvasSide / CGFloat(max(source.width, source.height))
            let size = CGSize(width: CGFloat(source.width) * scale, height: CGFloat(source.height) * scale)
            artwork.bounds = CGRect(origin: .zero, size: size)
            #if os(macOS)
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position = CGPoint(x: Self.canvasSide / 2, y: (Self.canvasSide - size.height) / 2)
            #else
            artwork.anchorPoint = CGPoint(x: 0.5, y: 1)
            artwork.position = CGPoint(x: Self.canvasSide / 2, y: (Self.canvasSide + size.height) / 2)
            #endif
        } else {
            artwork.contents = nil
        }
        CATransaction.commit()
        if resume { setAnimating(true) }
    }

    func layout(in bounds: CGRect, displayScale: CGFloat) {
        PioOutfitMotionDiagnostics.record(.layoutCalls)
        let measured = MeasuredLayout(bounds: bounds, displayScale: max(displayScale, 1))
        if measuredLayout != measured {
            PioOutfitMotionDiagnostics.record(.effectiveLayouts)
            measuredLayout = measured
        }
        PioOutfitMotionDiagnostics.record(.layoutTransactions)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.frame = bounds
        canvas.position = CGPoint(x: bounds.midX, y: bounds.midY)
        // Space above the character for the shared jump/celebration tracks.
        let scale = max(0, min(bounds.width, bounds.height)) * 0.86 / Self.canvasSide
        canvas.transform = CATransform3DMakeScale(scale, scale, 1)
        artwork.contentsScale = max(displayScale, 1)
        CATransaction.commit()
    }

    func setAnimating(_ requested: Bool, reduceMotion: Bool = false) {
        let active = requested && !reduceMotion && source != nil
        guard active != isAnimating else { return }
        isAnimating = active
        PioOutfitMotionDiagnostics.setActive(active, rig: self)
        if !active {
            approvedWave?.setAnimating(false)
            artwork.removeAllAnimations()
            CATransaction.begin(); CATransaction.setDisableActions(true)
            artwork.transform = CATransform3DIdentity
            CATransaction.commit()
            return
        }
        if outfit == .basic && motion == .wave {
            approvedWave?.setAnimating(true)
            return
        }
        switch motion {
        case .idle, .rest:
            let breath = CABasicAnimation(keyPath: "transform.scale.y")
            breath.fromValue = 1
            breath.toValue = motion == .rest ? 1.012 : 1.018
            breath.duration = motion == .rest ? 2.4 : SaessagiIdleMotion.breathHalfPeriod
            breath.autoreverses = true
            breath.repeatCount = .infinity
            breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            artwork.add(breath, forKey: "outfit.breath")
        case .landing:
            // A body-level settling pose, without pretending feet are independent.
            add(values: [1, 1.035, 0.99, 1, 1], times: [0, 0.12, 0.28, 0.5, 1],
                keyPath: "transform.scale.x", duration: 3.2)
            add(values: [1, 0.965, 1.01, 1, 1], times: [0, 0.12, 0.28, 0.5, 1],
                keyPath: "transform.scale.y", duration: 3.2)
        case .bounce, .jump, .celebration:
            var random = SystemRandomNumberGenerator()
            let action: SaessagiAction = motion == .bounce ? .bounce : motion == .jump ? .hop : .cheer
            guard let plan = SaessagiMotionPlan.make(action, at: 0, range: 0,
                size: Double(Self.canvasSide), using: &random) else { return }
            #if os(macOS)
            let up = 1.0, clockwise = -1.0
            #else
            let up = -1.0, clockwise = 1.0
            #endif
            add(plan.bob.mapped { $0 * 0.45 * up }, keyPath: "transform.translation.y", duration: plan.duration)
            add(plan.squashX.mapped { 1 + ($0 - 1) * 0.35 }, keyPath: "transform.scale.x", duration: plan.duration)
            add(plan.squashY.mapped { 1 + ($0 - 1) * 0.35 }, keyPath: "transform.scale.y", duration: plan.duration)
            add(plan.rock.mapped { $0 * .pi / 180 * 0.35 * clockwise }, keyPath: "transform.rotation.z", duration: plan.duration)
        case .wave: break // Unsupported costume waves resolve to idle in configure.
        }
    }

    private func add(_ track: SaessagiTrack, keyPath: String, duration: Double) {
        guard !track.isConstant else { return }
        let cycle = duration + 1.5
        add(values: track.values + [track.last], times: track.times.map { $0 / cycle } + [1],
            keyPath: keyPath, duration: cycle)
    }

    private func add(values: [Double], times: [Double], keyPath: String, duration: Double) {
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = values
        animation.keyTimes = times.map { NSNumber(value: $0) }
        animation.duration = duration
        animation.repeatCount = .infinity
        animation.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: values.count - 1)
        artwork.add(animation, forKey: "outfit.\(keyPath)")
    }
}

#if os(macOS)
private struct PioOutfitMotionHost: NSViewRepresentable {
    let outfit: PioOutfitID
    let stage: Int
    let motion: PioOutfitMotion
    let isAnimating: Bool
    func makeNSView(context: Context) -> PioOutfitMotionNativeView { PioOutfitMotionNativeView() }
    func updateNSView(_ view: PioOutfitMotionNativeView, context: Context) {
        PioOutfitMotionDiagnostics.record(.hostUpdates)
        view.rig.configure(outfit: outfit, stage: stage, motion: motion)
        view.requestedAnimation = isAnimating
        view.refresh()
    }
    static func dismantleNSView(_ view: PioOutfitMotionNativeView, coordinator: ()) { view.rig.setAnimating(false) }
}
private final class PioOutfitMotionNativeView: NSView {
    let rig = PioOutfitMotionRig()
    var requestedAnimation = false
    init() { super.init(frame: .zero); wantsLayer = true; layer?.addSublayer(rig.root) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func layout() { super.layout(); refresh() }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); refresh() }
    func refresh() {
        PioOutfitMotionDiagnostics.record(.nativeRefreshes)
        rig.layout(in: bounds, displayScale: window?.backingScaleFactor ?? 2)
        rig.setAnimating(requestedAnimation && window != nil)
    }
}
#else
private struct PioOutfitMotionHost: UIViewRepresentable {
    let outfit: PioOutfitID
    let stage: Int
    let motion: PioOutfitMotion
    let isAnimating: Bool
    func makeUIView(context: Context) -> PioOutfitMotionNativeView { PioOutfitMotionNativeView() }
    func updateUIView(_ view: PioOutfitMotionNativeView, context: Context) {
        PioOutfitMotionDiagnostics.record(.hostUpdates)
        view.rig.configure(outfit: outfit, stage: stage, motion: motion)
        view.requestedAnimation = isAnimating
        view.refresh()
    }
    static func dismantleUIView(_ view: PioOutfitMotionNativeView, coordinator: ()) { view.rig.setAnimating(false) }
}
private final class PioOutfitMotionNativeView: UIView {
    let rig = PioOutfitMotionRig()
    var requestedAnimation = false
    init() { super.init(frame: .zero); isUserInteractionEnabled = false; layer.addSublayer(rig.root) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() { super.layoutSubviews(); refresh() }
    override func didMoveToWindow() { super.didMoveToWindow(); refresh() }
    func refresh() {
        PioOutfitMotionDiagnostics.record(.nativeRefreshes)
        rig.layout(in: bounds, displayScale: window?.screen.scale ?? 2)
        rig.setAnimating(requestedAnimation && window != nil)
    }
}
#endif
