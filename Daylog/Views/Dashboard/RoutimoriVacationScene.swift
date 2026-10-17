import SwiftUI
import QuartzCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The trial keeps the existing vacation controls and scroll layout. Only its
/// scenery changes: the beach stays still while the registered hammock sways.
struct RoutimoriVacationScene: View {
    let slot: CGRect?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    private func sceneAsset(_ context: PioAppearanceContext, fallback: String) -> String {
        let appearance = PioAppearanceCoordinator.shared.resolve(context: context, motion: .rest)
        if case .existingScene(let asset) = appearance.artwork { return asset }
        return fallback
    }

    var body: some View {
        let dayAsset = sceneAsset(.vacationDay, fallback: "routimori_vacation_hammock")
        let nightAsset = sceneAsset(.vacationNight, fallback: "routimori_vacation_hammock_night")
        RoutimoriVacationHost(slot: slot, isDark: colorScheme == .dark,
                              dayForeground: dayAsset, nightForeground: nightAsset,
                              isAnimating: isVisible && scenePhase == .active && !reduceMotion)
            // Only an approved scene asset can replace this complete foreground.
            // Same-asset ownership updates do not recreate the animation host.
            .id("\(dayAsset)|\(nightAsset)")
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
    }
}

@MainActor
final class RoutimoriVacationRig {
    // Both images share this source registration; neither image is independently
    // cropped or stretched. The resting hammock therefore matches the beach.
    static let sourceSize = CGSize(width: 1024, height: 1536)
    static let hammockFocus = CGPoint(x: 512, y: 740)
    static let attachment = CGPoint(x: 968, y: 484)
    static let nightHammockFocus = CGPoint(x: 512, y: 845)
    static let nightAttachment = CGPoint(x: 68, y: 465)
    static let swingDegrees: CGFloat = 1.5
    let root = CALayer()
    let canvas = CALayer()
    let beach = CALayer()
    let hammock = CALayer()
    private let dayBackground: CGImage?
    private let dayForeground: CGImage?
    private let nightBackground: CGImage?
    private let nightForeground: CGImage?
    private var isAnimating = false

    init(background: CGImage?, foreground: CGImage?, nightBackground: CGImage? = nil, nightForeground: CGImage? = nil) {
        dayBackground = background
        dayForeground = foreground
        self.nightBackground = nightBackground
        self.nightForeground = nightForeground
        #if os(macOS)
        root.isGeometryFlipped = true
        #endif
        root.masksToBounds = true
        root.addSublayer(canvas)
        canvas.anchorPoint = .zero
        canvas.bounds = CGRect(origin: .zero, size: Self.sourceSize)
        // Fade the portrait's outer edges into the surrounding cream on wide
        // panes. This stationary mask includes both registered layers, so the
        // character keeps its intended size and the rope cannot reveal a seam.
        let horizontalFade = CAGradientLayer()
        horizontalFade.frame = canvas.bounds
        horizontalFade.startPoint = CGPoint(x: 0, y: 0.5)
        horizontalFade.endPoint = CGPoint(x: 1, y: 0.5)
        horizontalFade.colors = [CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: 1),
                                 CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0)]
        horizontalFade.locations = [0, 0.075, 0.925, 1]
        let verticalFade = CAGradientLayer()
        verticalFade.frame = canvas.bounds
        verticalFade.colors = horizontalFade.colors
        verticalFade.locations = [0, 0.06, 0.94, 1]
        horizontalFade.mask = verticalFade
        canvas.mask = horizontalFade
        for layer in [beach, hammock] {
            layer.bounds = canvas.bounds
            layer.contentsGravity = .resize
            layer.minificationFilter = .trilinear
            canvas.addSublayer(layer)
        }
        beach.position = CGPoint(x: Self.sourceSize.width / 2, y: Self.sourceSize.height / 2)
        beach.contents = background
        hammock.anchorPoint = CGPoint(x: Self.attachment.x / Self.sourceSize.width,
                                      y: Self.attachment.y / Self.sourceSize.height)
        hammock.position = Self.attachment
        hammock.contents = foreground
    }

    func layout(in bounds: CGRect, slot: CGRect?, isDark: Bool, displayScale: CGFloat) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let target = slot ?? CGRect(x: bounds.width * 0.05, y: bounds.height * 0.3,
                                   width: bounds.width * 0.9, height: bounds.width * 0.64)
        let scale = max(target.width, 1) / Self.sourceSize.width
        // Switch a complete registered pair together. Missing preview assets fall
        // back to the day pair rather than leaving an empty layer or mismatched rig.
        let usesNightArtwork = isDark && nightBackground != nil && nightForeground != nil
        let focus = usesNightArtwork ? Self.nightHammockFocus : Self.hammockFocus
        let anchor = usesNightArtwork ? Self.nightAttachment : Self.attachment
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.frame = bounds
        root.backgroundColor = isDark
            ? CGColor(red: 0.025, green: 0.065, blue: 0.12, alpha: 1)
            : CGColor(red: 0.98, green: 0.97, blue: 0.92, alpha: 1)
        beach.contents = usesNightArtwork ? nightBackground : dayBackground
        hammock.contents = usesNightArtwork ? nightForeground : dayForeground
        hammock.anchorPoint = CGPoint(x: anchor.x / Self.sourceSize.width, y: anchor.y / Self.sourceSize.height)
        hammock.position = anchor
        canvas.position = CGPoint(x: target.midX - focus.x * scale,
                                  y: target.midY - focus.y * scale)
        canvas.transform = CATransform3DMakeScale(scale, scale, 1)
        for layer in [root, beach, hammock] { layer.contentsScale = max(displayScale, 1) }
        CATransaction.commit()
    }

    func setAnimating(_ active: Bool) {
        guard active != isAnimating else { return }
        isAnimating = active
        if active {
            let swing = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            let angle = Self.swingDegrees * .pi / 180
            swing.values = [0, angle, 0, -angle, 0]
            swing.keyTimes = [0, 0.25, 0.5, 0.75, 1]
            swing.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 4)
            swing.duration = 7.6
            swing.repeatCount = .infinity
            hammock.add(swing, forKey: "hammockSway")
        } else {
            hammock.removeAllAnimations()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hammock.transform = CATransform3DIdentity
            CATransaction.commit()
        }
    }
}

#if os(macOS)
private struct RoutimoriVacationHost: NSViewRepresentable {
    let slot: CGRect?
    let isDark: Bool
    let dayForeground: String
    let nightForeground: String
    let isAnimating: Bool
    func makeNSView(context: Context) -> RoutimoriVacationNativeView {
        RoutimoriVacationNativeView(dayForeground: dayForeground, nightForeground: nightForeground)
    }
    func updateNSView(_ view: RoutimoriVacationNativeView, context: Context) {
        view.slot = slot; view.isDark = isDark; view.requestedAnimation = isAnimating; view.refresh()
    }
    static func dismantleNSView(_ view: RoutimoriVacationNativeView, coordinator: ()) { view.rig.setAnimating(false) }
}

private final class RoutimoriVacationNativeView: NSView {
    let rig: RoutimoriVacationRig
    var slot: CGRect?
    var isDark = false
    var requestedAnimation = false
    init(dayForeground: String, nightForeground: String) {
        func image(_ name: String) -> CGImage? {
            NSImage(named: name)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        rig = RoutimoriVacationRig(background: image("routimori_vacation_background"),
                                  foreground: image(dayForeground),
                                  nightBackground: image("routimori_vacation_background_night"),
                                  nightForeground: image(nightForeground))
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(rig.root)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func layout() { super.layout(); refresh() }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); refresh() }
    func refresh() {
        rig.layout(in: bounds, slot: slot, isDark: isDark, displayScale: window?.backingScaleFactor ?? 2)
        rig.setAnimating(requestedAnimation && window != nil)
    }
}
#else
private struct RoutimoriVacationHost: UIViewRepresentable {
    let slot: CGRect?
    let isDark: Bool
    let dayForeground: String
    let nightForeground: String
    let isAnimating: Bool
    func makeUIView(context: Context) -> RoutimoriVacationNativeView {
        RoutimoriVacationNativeView(dayForeground: dayForeground, nightForeground: nightForeground)
    }
    func updateUIView(_ view: RoutimoriVacationNativeView, context: Context) {
        view.slot = slot; view.isDark = isDark; view.requestedAnimation = isAnimating; view.refresh()
    }
    static func dismantleUIView(_ view: RoutimoriVacationNativeView, coordinator: ()) { view.rig.setAnimating(false) }
}

private final class RoutimoriVacationNativeView: UIView {
    let rig: RoutimoriVacationRig
    var slot: CGRect?
    var isDark = false
    var requestedAnimation = false
    init(dayForeground: String, nightForeground: String) {
        rig = RoutimoriVacationRig(background: UIImage(named: "routimori_vacation_background")?.cgImage,
                                   foreground: UIImage(named: dayForeground)?.cgImage,
                                   nightBackground: UIImage(named: "routimori_vacation_background_night")?.cgImage,
                                   nightForeground: UIImage(named: nightForeground)?.cgImage)
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        layer.addSublayer(rig.root)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() { super.layoutSubviews(); refresh() }
    override func didMoveToWindow() { super.didMoveToWindow(); refresh() }
    func refresh() {
        rig.layout(in: bounds, slot: slot, isDark: isDark, displayScale: window?.screen.scale ?? 2)
        rig.setAnimating(requestedAnimation && window != nil)
    }
}
#endif
