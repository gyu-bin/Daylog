import SwiftUI
import QuartzCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Explicit Debug activation shared by the green character surfaces.
enum RoutimoriSplashTrial {
    static var isEnabled: Bool {
        enabled(character: UserDefaults.standard.string(forKey: "DaylogDebugCharacter"),
                arguments: ProcessInfo.processInfo.arguments)
    }

    static func enabled(character: String?, arguments: [String]) -> Bool {
        #if DEBUG
        character == "routimori" || arguments.contains("-pio-wardrobe-testing")
        #else
        false
        #endif
    }

    static var isHeld: Bool {
        #if DEBUG
        UserDefaults.standard.string(forKey: "DaylogDebugSplashHold") == "routimori"
        #else
        false
        #endif
    }

    @MainActor private static var macClaimed = false
    @MainActor static func claimMac() -> Bool {
        guard isEnabled, !RuntimeEnvironment.isRunningTests,
              UserDefaults.standard.string(forKey: "DaylogDebugSplash") != "off", !macClaimed else { return false }
        macClaimed = true
        return true
    }
}

struct RoutimoriSplashView: View {
    var onLeaving: () -> Void = {}
    let onFinish: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 46
    @ScaledMetric(relativeTo: .body) private var captionSize: CGFloat = 16
    @State private var isLeaving = false
    @State private var hasFinished = false
    @State private var hasStarted = false
    @State private var isVisible = false

    private let green = Color(red: 0.08, green: 0.27, blue: 0.19)
    private let muted = Color(red: 0.38, green: 0.48, blue: 0.42)
    private var isAnimating: Bool { isVisible && scenePhase == .active && !reduceMotion && !isLeaving }
    private var appearance: PioResolvedAppearance {
        PioAppearanceCoordinator.shared.resolve(context: .splash, motion: .wave)
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 430
            let spacing: CGFloat = compact ? 6 : 16
            let characterWidth = min(proxy.size.width * 0.76, proxy.size.height * 0.48, 340)
            ZStack {
                Color(red: 0.985, green: 0.98, blue: 0.955).ignoresSafeArea()
                VStack(spacing: spacing) {
                    Spacer(minLength: 0)
                    VStack(spacing: compact ? 3 : 8) {
                        sprout.frame(width: compact ? 30 : 42, height: compact ? 18 : 25)
                        Text("Routimori")
                            .font(.system(size: min(titleSize, proxy.size.width * 0.14, max(22, proxy.size.height * 0.085)), weight: .heavy, design: .rounded))
                            .foregroundStyle(green)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text("작은 습관, 오래가는 성장")
                            .font(.system(size: min(captionSize, compact ? 13 : 18)))
                            .foregroundStyle(muted)
                            .lineLimit(1).minimumScaleFactor(0.65)
                    }
                    Spacer(minLength: compact ? 0 : 10)
                    PioAppearanceView(appearance: appearance, isAnimating: isAnimating)
                        .frame(width: characterWidth, height: characterWidth * 1192 / 1319)
                    Spacer(minLength: compact ? 0 : 16)
                    VStack(spacing: compact ? 8 : 15) {
                        Capsule().fill(green.opacity(0.09))
                            .overlay(alignment: .leading) {
                                Capsule().fill(Color(red: 0.43, green: 0.64, blue: 0.39))
                                    .frame(width: compact ? 46 : 66)
                            }
                            .frame(width: compact ? 125 : 180, height: 5)
                        Text("지금, 더 나은 내가 되는 중이에요 🌱")
                            .font(.system(size: min(captionSize * 0.85, compact ? 11 : 15)))
                            .foregroundStyle(muted)
                            .multilineTextAlignment(.center)
                            .lineLimit(2).minimumScaleFactor(0.65)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, compact ? 12 : 28)
                .frame(maxWidth: 640)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .opacity(isLeaving ? 0 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Routimori. 작은 습관, 오래가는 성장. \(appearance.outfit.title). \(appearance.compatibilityNote ?? "")")
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .task(id: scenePhase) { await runPresentation() }
    }

    private var sprout: some View {
        GeometryReader { proxy in
            ZStack {
                Capsule().fill(green.opacity(0.8)).frame(width: 3, height: proxy.size.height * 0.65).offset(y: 6)
                Ellipse().fill(Color(red: 0.46, green: 0.65, blue: 0.27))
                    .frame(width: proxy.size.width * 0.53, height: proxy.size.height * 0.57)
                    .rotationEffect(.degrees(35)).offset(x: -proxy.size.width * 0.22, y: -1)
                Ellipse().fill(Color(red: 0.58, green: 0.74, blue: 0.34))
                    .frame(width: proxy.size.width * 0.58, height: proxy.size.height * 0.63)
                    .rotationEffect(.degrees(-37)).offset(x: proxy.size.width * 0.21, y: -3)
            }.frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    @MainActor private func runPresentation() async {
        guard !hasFinished else { return }
        do {
            if scenePhase == .background {
                guard !hasStarted else { return }
                // Match the existing splash's cold-background grace policy. A launch
                // that never becomes visible must not greet on a later foreground.
                try await Task.sleep(for: .seconds(SplashTimeline.startGrace))
                try Task.checkCancellation()
                guard !hasStarted, !hasFinished else { return }
                hasFinished = true
                onLeaving()
                onFinish()
                return
            }
            guard scenePhase == .active else { return }
            hasStarted = true
            guard !RoutimoriSplashTrial.isHeld else { return }
            // A background transition cancels this task. On return, the visible greeting
            // restarts its dwell; an already-started fade completes without a second callback.
            if !isLeaving {
                try await Task.sleep(for: .seconds(3.2))
                try Task.checkCancellation()
                onLeaving()
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { isLeaving = true }
            }
            try await Task.sleep(for: .seconds(reduceMotion ? 0 : 0.35))
            try Task.checkCancellation()
            guard !hasFinished else { return }
            hasFinished = true
            onFinish()
        } catch { return }
    }
}

/// Two masks of the same approved PNG. The face/body/sprout remain one untouched image;
/// only the screen-right wing receives an independent shoulder rotation.
@MainActor final class RoutimoriSplashRig {
    static let sourceSize = CGSize(width: 1319, height: 1192)
    static let shoulder = CGPoint(x: 1050, y: 830)
    let canvas = CALayer()
    let character = CALayer()
    let wing = CALayer()
    let body = CALayer()
    private let shadow = CAShapeLayer()
    private var animating = false

    init(image: CGImage?) {
        let rect = CGRect(origin: .zero, size: Self.sourceSize)
        canvas.bounds = rect
        character.bounds = rect
        character.position = CGPoint(x: rect.midX, y: rect.midY)
        canvas.addSublayer(shadow)
        canvas.addSublayer(character)
        shadow.path = CGPath(ellipseIn: CGRect(x: 440, y: Self.point(CGPoint(x: 0, y: 1150)).y - 14, width: 480, height: 28), transform: nil)
        shadow.fillColor = CGColor(gray: 0.28, alpha: 0.08)
        shadow.shadowColor = CGColor(gray: 0.26, alpha: 1)
        shadow.shadowOpacity = 0.12
        shadow.shadowRadius = 14
        shadow.shadowOffset = .zero
        for layer in [wing, body] {
            layer.bounds = rect
            layer.position = CGPoint(x: rect.midX, y: rect.midY)
            layer.contents = image
            layer.contentsGravity = .resize
            layer.minificationFilter = .trilinear
            character.addSublayer(layer)
        }
        let anchor = Self.point(Self.shoulder)
        wing.anchorPoint = CGPoint(x: anchor.x / rect.width, y: anchor.y / rect.height)
        wing.position = anchor
        let wingMask = CAShapeLayer()
        wingMask.frame = rect
        wingMask.path = Self.wingRegion(overlap: 8)
        wing.mask = wingMask
        let bodyMask = CAShapeLayer()
        bodyMask.frame = rect
        let retained = CGMutablePath()
        retained.addRect(rect)
        retained.addPath(Self.wingRegion(overlap: 0))
        bodyMask.path = retained
        bodyMask.fillRule = .evenOdd
        body.mask = bodyMask
    }

    static func point(_ p: CGPoint) -> CGPoint {
        #if os(macOS)
        CGPoint(x: p.x, y: sourceSize.height - p.y)
        #else
        p
        #endif
    }

    private static func wingRegion(overlap: CGFloat) -> CGPath {
        // Smooth natural torso contour. Underlap tapers to zero at both ends;
        // otherwise a rotated sliver of torso can peek out above/below the wing.
        let path = CGMutablePath()
        path.move(to: point(CGPoint(x: overlap > 0 ? 1070 : 1040, y: 560)))
        path.addCurve(to: point(CGPoint(x: 1052, y: 700)),
                      control1: point(CGPoint(x: overlap > 0 ? 1070 : 1050, y: 610)),
                      control2: point(CGPoint(x: overlap > 0 ? 1054 : 1050, y: 660)))
        path.addCurve(to: point(CGPoint(x: 1030 - overlap, y: 865)),
                      control1: point(CGPoint(x: 1052 - overlap, y: 760)),
                      control2: point(CGPoint(x: 1048 - overlap, y: 825)))
        path.addCurve(to: point(CGPoint(x: overlap > 0 ? 1029 : 1017, y: overlap > 0 ? 909 : 916)),
                      control1: point(CGPoint(x: 1020 - overlap * 0.5, y: 887)),
                      control2: point(CGPoint(x: overlap > 0 ? 1029 : 1018, y: 905)))
        path.addLine(to: point(CGPoint(x: 1319, y: overlap > 0 ? 909 : 916)))
        path.addLine(to: point(CGPoint(x: 1319, y: 560)))
        path.closeSubpath()
        return path
    }

    func layout(in bounds: CGRect, displayScale: CGFloat) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        canvas.position = CGPoint(x: bounds.midX, y: bounds.midY)
        let scale = min(bounds.width / Self.sourceSize.width, bounds.height / Self.sourceSize.height)
        canvas.transform = CATransform3DMakeScale(scale, scale, 1)
        for layer in [canvas, character, wing, body] { layer.contentsScale = displayScale }
        CATransaction.commit()
    }

    func setAnimating(_ enabled: Bool) {
        guard enabled != animating else { return }
        animating = enabled
        if !enabled {
            wing.removeAllAnimations()
            character.removeAllAnimations()
            return
        }
        #if os(macOS)
        let sign: CGFloat = -1
        #else
        let sign: CGFloat = 1
        #endif
        let wave = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        wave.values = [0, -8, 8, -10, 7, -5, 0, 0].map { NSNumber(value: Double($0) * Double(sign) * .pi / 180) }
        wave.keyTimes = [0, 0.12, 0.23, 0.34, 0.45, 0.56, 0.68, 1]
        wave.duration = 3.4
        wave.repeatCount = .infinity
        wave.calculationMode = .cubic
        wing.add(wave, forKey: "greeting")
        let bob = CAKeyframeAnimation(keyPath: "transform.translation.y")
        bob.values = [0, -8 * sign, 0, 3 * sign, 0]
        bob.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        bob.duration = 3.4; bob.repeatCount = .infinity; bob.calculationMode = .cubic
        character.add(bob, forKey: "breathing")
        let tilt = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        tilt.values = [0, 0.012 * sign, 0, -0.008 * sign, 0]
        tilt.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        tilt.duration = 3.4; tilt.repeatCount = .infinity; tilt.calculationMode = .cubic
        character.add(tilt, forKey: "tilt")
    }
}

#if os(macOS)
private struct RoutimoriCharacterHost: NSViewRepresentable {
    let isAnimating: Bool
    func makeNSView(context: Context) -> RoutimoriCharacterNativeView { RoutimoriCharacterNativeView() }
    func updateNSView(_ view: RoutimoriCharacterNativeView, context: Context) { view.requestedAnimation = isAnimating; view.refresh() }
    static func dismantleNSView(_ view: RoutimoriCharacterNativeView, coordinator: ()) { view.rig.setAnimating(false) }
}

private final class RoutimoriCharacterNativeView: NSView {
    let rig: RoutimoriSplashRig
    var requestedAnimation = false
    init() {
        let image = NSImage(named: "routimori_splash_character")?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        rig = RoutimoriSplashRig(image: image)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(rig.canvas)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() { super.layout(); refresh() }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); refresh() }
    func refresh() {
        rig.layout(in: bounds, displayScale: window?.backingScaleFactor ?? 2)
        rig.setAnimating(requestedAnimation && window != nil)
    }
}
#else
private struct RoutimoriCharacterHost: UIViewRepresentable {
    let isAnimating: Bool
    func makeUIView(context: Context) -> RoutimoriCharacterNativeView { RoutimoriCharacterNativeView() }
    func updateUIView(_ view: RoutimoriCharacterNativeView, context: Context) { view.requestedAnimation = isAnimating; view.refresh() }
    static func dismantleUIView(_ view: RoutimoriCharacterNativeView, coordinator: ()) { view.rig.setAnimating(false) }
}

private final class RoutimoriCharacterNativeView: UIView {
    let rig = RoutimoriSplashRig(image: UIImage(named: "routimori_splash_character")?.cgImage)
    var requestedAnimation = false
    init() { super.init(frame: .zero); layer.addSublayer(rig.canvas); isUserInteractionEnabled = false }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() { super.layoutSubviews(); refresh() }
    override func didMoveToWindow() { super.didMoveToWindow(); refresh() }
    func refresh() {
        rig.layout(in: bounds, displayScale: window?.screen.scale ?? 2)
        rig.setAnimating(requestedAnimation && window != nil)
    }
}
#endif
