import SwiftUI
import QuartzCore
import CoreImage
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

    var body: some View {
        let day = PioAppearanceCoordinator.shared.resolve(context: .vacationDay, motion: .rest)
        let night = PioAppearanceCoordinator.shared.resolve(context: .vacationNight, motion: .rest)
        let dayAsset = day.artwork.assetName ?? "routimori_vacation_hammock"
        let nightAsset = night.artwork.assetName ?? "routimori_vacation_hammock_night"
        // Unknown ownership renders only the stationary beach, never a brief
        // Basic character or the unverified selected costume.
        let showsCharacter = PioVacationSceneResources.shouldShowCharacter(access: day.access)
            && PioVacationSceneResources.shouldShowCharacter(access: night.access)
        RoutimoriVacationHost(slot: slot, isDark: colorScheme == .dark,
                              dayForeground: dayAsset, nightForeground: nightAsset,
                              showsCharacter: showsCharacter,
                              isAnimating: showsCharacter && PioVacationSceneResources.shouldAnimate(
                                visible: isVisible, sceneActive: scenePhase == .active, reduceMotion: reduceMotion))
            // Complete authored foregrounds retain their original pixels. A costume
            // switch replaces this host; a same-asset ownership refresh does not.
            .id("\(dayAsset)|\(nightAsset)")
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
    }
}

@MainActor
final class RoutimoriVacationRig {
    // Source coordinates are preserved without per-image cropping or stretching.
    // Original Basic registration remains intact. Newly authored outfits carry
    // conservative preview registration; exact rope-root approval is still pending.
    static let sourceSize = CGSize(width: 1024, height: 1536)
    static let hammockFocus = CGPoint(x: 512, y: 740)
    static let attachment = CGPoint(x: 968, y: 484)
    static let nightHammockFocus = CGPoint(x: 512, y: 845)
    static let nightAttachment = CGPoint(x: 68, y: 465)
    static let swingDegrees: CGFloat = 1.5
    let root = CALayer()
    /// 화면 전체를 채우는 흐린 풍경. 넓은 창(Mac, iPad 가로)에서도 양옆이 비지 않게 같은 풍경을 크게 흐려 깔고,
    /// 또렷한 원래 그림(`canvas`)은 해먹 자리에 맞춘 크기 그대로 그 위에 둔다(피오가 커져 글자를 가리지 않게).
    let backdrop = CALayer()
    let canvas = CALayer()
    private let dayAmbient: CGImage?
    private let nightAmbient: CGImage?
    let beach = CALayer()
    let hammock = CALayer()
    private let dayBackground: CGImage?
    private let dayForeground: CGImage?
    private let nightBackground: CGImage?
    private let nightForeground: CGImage?
    private var isAnimating = false
    private let dayRegistration: RoutimoriVacationRegistration
    private let nightRegistration: RoutimoriVacationRegistration
    private(set) var currentRegistration = RoutimoriVacationRegistration.originalDay
    private(set) var independentEyes: PioVacationIndependentEyes?
    private(set) var independentNightEyes: PioVacationIndependentEyes?
    private let supportsBasicRopeAnchors: Bool
    private(set) var activeHinge: PioVacationAnchorMotion?

    init(background: CGImage?, foreground: CGImage?, nightBackground: CGImage? = nil, nightForeground: CGImage? = nil,
         dayRegistration: RoutimoriVacationRegistration = .originalDay,
         nightRegistration: RoutimoriVacationRegistration = .originalNight,
         supportsBasicDayEyes: Bool = false, supportsBasicNightEyes: Bool = false,
         supportsChristmasNightEyes: Bool = false,
         supportsChristmasDayEyes: Bool = false, supportsWinterNightEyes: Bool = false,
         supportsBasicRopeAnchors: Bool = false) {
        self.supportsBasicRopeAnchors = supportsBasicRopeAnchors
        self.dayRegistration = dayRegistration
        self.nightRegistration = nightRegistration
        currentRegistration = dayRegistration
        dayBackground = background
        dayForeground = foreground
        self.nightBackground = nightBackground
        self.nightForeground = nightForeground
        dayAmbient = Self.ambient(background)
        nightAmbient = Self.ambient(nightBackground)
        #if os(macOS)
        root.isGeometryFlipped = true
        #endif
        root.masksToBounds = true
        backdrop.contentsGravity = .resizeAspectFill
        backdrop.masksToBounds = true
        root.addSublayer(backdrop)
        root.addSublayer(canvas)
        canvas.anchorPoint = .zero
        canvas.bounds = CGRect(origin: .zero, size: Self.sourceSize)
        // Fade the portrait's outer edges into the surrounding cream on wide
        // panes. This stationary mask includes both registered layers, so the
        // character keeps its intended size. This fade is not a substitute for
        // checking authored rope registration at both motion extremes.
        let horizontalFade = CAGradientLayer()
        horizontalFade.frame = canvas.bounds
        horizontalFade.startPoint = CGPoint(x: 0, y: 0.5)
        horizontalFade.endPoint = CGPoint(x: 1, y: 0.5)
        horizontalFade.colors = [CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: 1),
                                 CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0)]
        horizontalFade.locations = [0, 0.16, 0.84, 1]
        let verticalFade = CAGradientLayer()
        verticalFade.frame = canvas.bounds
        verticalFade.colors = horizontalFade.colors
        verticalFade.locations = [0, 0.08, 0.92, 1]
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
        hammock.anchorPoint = CGPoint(x: dayRegistration.attachment.x / Self.sourceSize.width,
                                      y: dayRegistration.attachment.y / Self.sourceSize.height)
        hammock.position = dayRegistration.attachment
        hammock.contents = foreground
        if supportsBasicDayEyes, let foreground {
            independentEyes = PioVacationIndependentEyes(originalForeground: foreground)
            if let independentEyes { hammock.addSublayer(independentEyes.root) }
        } else if supportsChristmasDayEyes, let foreground {
            independentEyes = PioVacationIndependentEyes(originalForeground: foreground, profile: .christmasDay)
            if let independentEyes { hammock.addSublayer(independentEyes.root) }
        }
        if supportsBasicNightEyes, let nightForeground {
            independentNightEyes = PioVacationIndependentEyes(originalForeground: nightForeground, profile: .basicNight)
            if let independentNightEyes { hammock.addSublayer(independentNightEyes.root) }
        } else if supportsChristmasNightEyes, let nightForeground {
            independentNightEyes = PioVacationIndependentEyes(originalForeground: nightForeground, profile: .christmasNight)
            if let independentNightEyes { hammock.addSublayer(independentNightEyes.root) }
        } else if supportsWinterNightEyes, let nightForeground {
            independentNightEyes = PioVacationIndependentEyes(originalForeground: nightForeground, profile: .winterNight)
            if let independentNightEyes { hammock.addSublayer(independentNightEyes.root) }
        }
    }

    convenience init(outfit: PioOutfitID, independentlyAnimatesBasicDayEyes: Bool = true,
                     independentlyAnimatesBasicNightEyes: Bool = true,
                     independentlyAnimatesChristmasNightEyes: Bool = true,
                     independentlyAnimatesChristmasDayEyes: Bool = true,
                     independentlyAnimatesWinterNightEyes: Bool = true,
                     independentlyAnchorsBasicRopes: Bool = true) {
        self.init(dayForegroundAsset: PioVacationSceneResources.sourceAsset(outfit: outfit, night: false),
                  nightForegroundAsset: PioVacationSceneResources.sourceAsset(outfit: outfit, night: true),
                  independentlyAnimatesBasicDayEyes: independentlyAnimatesBasicDayEyes,
                  independentlyAnimatesBasicNightEyes: independentlyAnimatesBasicNightEyes,
                  independentlyAnimatesChristmasNightEyes: independentlyAnimatesChristmasNightEyes,
                  independentlyAnimatesChristmasDayEyes: independentlyAnimatesChristmasDayEyes,
                  independentlyAnimatesWinterNightEyes: independentlyAnimatesWinterNightEyes,
                  independentlyAnchorsBasicRopes: independentlyAnchorsBasicRopes)
    }

    convenience init(dayForegroundAsset: String, nightForegroundAsset: String,
                     independentlyAnimatesBasicDayEyes: Bool = true,
                     independentlyAnimatesBasicNightEyes: Bool = true,
                     independentlyAnimatesChristmasNightEyes: Bool = true,
                     independentlyAnimatesChristmasDayEyes: Bool = true,
                     independentlyAnimatesWinterNightEyes: Bool = true,
                     independentlyAnchorsBasicRopes: Bool = true) {
        func image(_ name: String) -> CGImage? {
            #if os(macOS)
            NSImage(named: name)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
            #else
            UIImage(named: name)?.cgImage
            #endif
        }
        self.init(background: image("routimori_vacation_background"),
                  foreground: image(dayForegroundAsset),
                  nightBackground: image("routimori_vacation_background_night"),
                  nightForeground: image(nightForegroundAsset),
                  dayRegistration: PioVacationSceneResources.registration(asset: dayForegroundAsset, night: false),
                  nightRegistration: PioVacationSceneResources.registration(asset: nightForegroundAsset, night: true),
                  supportsBasicDayEyes: independentlyAnimatesBasicDayEyes && dayForegroundAsset == "routimori_vacation_hammock",
                  supportsBasicNightEyes: independentlyAnimatesBasicNightEyes && nightForegroundAsset == "routimori_vacation_hammock_night",
                  supportsChristmasNightEyes: independentlyAnimatesChristmasNightEyes && nightForegroundAsset == "routimori_vacation_night_christmas",
                  supportsChristmasDayEyes: independentlyAnimatesChristmasDayEyes && dayForegroundAsset == "routimori_vacation_day_christmas",
                  supportsWinterNightEyes: independentlyAnimatesWinterNightEyes && nightForegroundAsset == "routimori_vacation_night_winter",
                  supportsBasicRopeAnchors: independentlyAnchorsBasicRopes
                    && dayForegroundAsset == "routimori_vacation_hammock"
                    && nightForegroundAsset == "routimori_vacation_hammock_night")
    }

    func layout(in bounds: CGRect, slot: CGRect?, isDark: Bool, displayScale: CGFloat) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let target = slot ?? CGRect(x: bounds.width * 0.05, y: bounds.height * 0.3,
                                   width: bounds.width * 0.9, height: bounds.width * 0.64)
        let scale = max(target.width, 1) / Self.sourceSize.width
        // Switch a complete registered pair together. Missing preview assets fall
        // back to the day pair rather than leaving an empty layer or mismatched rig.
        let usesNightArtwork = isDark && nightBackground != nil && nightForeground != nil
        let registration = usesNightArtwork ? nightRegistration : dayRegistration
        let hinge = supportsBasicRopeAnchors
            ? (usesNightArtwork ? PioVacationAnchorMotion.basicNight : PioVacationAnchorMotion.basicDay) : nil
        let swingChanged = registration.swingDegrees != currentRegistration.swingDegrees
            || hinge?.fixedPoint != activeHinge?.fixedPoint
        activeHinge = hinge
        currentRegistration = registration
        let focus = registration.focus
        let anchor = registration.attachment
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.frame = bounds
        root.backgroundColor = isDark
            ? CGColor(red: 0.025, green: 0.065, blue: 0.12, alpha: 1)
            : CGColor(red: 0.98, green: 0.97, blue: 0.92, alpha: 1)
        backdrop.frame = bounds
        backdrop.contents = usesNightArtwork ? nightAmbient : dayAmbient
        beach.contents = usesNightArtwork ? nightBackground : dayBackground
        hammock.contents = usesNightArtwork ? nightForeground : dayForeground
        hammock.anchorPoint = CGPoint(x: anchor.x / Self.sourceSize.width, y: anchor.y / Self.sourceSize.height)
        hammock.position = anchor
        canvas.position = CGPoint(x: target.midX - focus.x * scale,
                                  y: target.midY - focus.y * scale)
        canvas.transform = CATransform3DMakeScale(scale, scale, 1)
        for layer in [root, beach, hammock] { layer.contentsScale = max(displayScale, 1) }
        CATransaction.commit()
        independentEyes?.setVisible(!usesNightArtwork && !hammock.isHidden)
        independentNightEyes?.setVisible(usesNightArtwork && !hammock.isHidden)
        if swingChanged && isAnimating {
            setAnimating(false)
            setAnimating(true)
        }
    }

    /// 풍경을 작게 줄여 흐린 그림. 한 번만 만들고, 화면에서는 크게 늘려 깐다(작게 만들어 늘리므로 가볍다).
    static func ambient(_ image: CGImage?) -> CGImage? {
        guard let image, image.width > 0 else { return nil }
        let input = CIImage(cgImage: image)
        let scale = 192 / CGFloat(image.width)
        let small = input.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let blurred = small.clampedToExtent().applyingGaussianBlur(sigma: 7).cropped(to: small.extent)
        return CIContext().createCGImage(blurred, from: small.extent)
    }

    func setCharacterVisible(_ visible: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hammock.isHidden = !visible
        CATransaction.commit()
        if !visible { setAnimating(false) }
    }

    func setAnimating(_ active: Bool) {
        let active = active && !hammock.isHidden
        independentEyes?.setAnimating(active)
        independentNightEyes?.setAnimating(active)
        guard active != isAnimating else { return }
        isAnimating = active
        if active {
            if let activeHinge {
                hammock.add(activeHinge.animation(), forKey: "hammockSway")
                return
            }
            let swing = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            let angle = currentRegistration.swingDegrees * .pi / 180
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
    let showsCharacter: Bool
    let isAnimating: Bool
    func makeNSView(context: Context) -> RoutimoriVacationNativeView {
        let view = RoutimoriVacationNativeView(dayForeground: dayForeground, nightForeground: nightForeground)
        view.showsCharacter = showsCharacter
        view.rig.setCharacterVisible(showsCharacter)
        return view
    }
    func updateNSView(_ view: RoutimoriVacationNativeView, context: Context) {
        view.slot = slot; view.isDark = isDark; view.showsCharacter = showsCharacter
        view.requestedAnimation = isAnimating; view.refresh()
    }
    static func dismantleNSView(_ view: RoutimoriVacationNativeView, coordinator: ()) { view.rig.setAnimating(false) }
}

private final class RoutimoriVacationNativeView: NSView {
    let rig: RoutimoriVacationRig
    var slot: CGRect?
    var isDark = false
    var requestedAnimation = false
    var showsCharacter = true
    init(dayForeground: String, nightForeground: String) {
        rig = RoutimoriVacationRig(dayForegroundAsset: dayForeground, nightForegroundAsset: nightForeground)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(rig.root)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func layout() { super.layout(); refresh() }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); observeWindow(); observeClipViews(); refresh() }
    override func viewDidMoveToSuperview() { super.viewDidMoveToSuperview(); observeClipViews(); refresh() }
    override func viewDidHide() { super.viewDidHide(); refresh() }
    override func viewDidUnhide() { super.viewDidUnhide(); refresh() }
    private func observeClipViews() {
        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: nil)
        var ancestor = superview
        while let view = ancestor {
            if let clip = view as? NSClipView {
                // Do not retain an owning clip ancestor from its document.
                // Selector observation does not need an extra strong reference.
                clip.postsBoundsChangedNotifications = true
                NotificationCenter.default.addObserver(self, selector: #selector(clipBoundsChanged),
                    name: NSView.boundsDidChangeNotification, object: clip)
            }
            ancestor = view.superview
        }
    }
    private func observeWindow() {
        for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification] {
            NotificationCenter.default.removeObserver(self, name: name, object: nil)
            if let window {
                NotificationCenter.default.addObserver(self, selector: #selector(clipBoundsChanged), name: name, object: window)
            }
        }
    }
    @objc private func clipBoundsChanged(_ notification: Notification) { refresh() }
    deinit { NotificationCenter.default.removeObserver(self) }
    func refresh() {
        rig.setCharacterVisible(showsCharacter)
        rig.layout(in: bounds, slot: slot, isDark: isDark, displayScale: window?.backingScaleFactor ?? 2)
        rig.setAnimating(requestedAnimation && window?.isVisible == true && window?.isMiniaturized == false
                         && window?.occlusionState.contains(.visible) == true && !isHiddenOrHasHiddenAncestor
                         && visibleRect.intersects(bounds) && !visibleRect.isEmpty)
    }
}
#else
private struct RoutimoriVacationHost: UIViewRepresentable {
    let slot: CGRect?
    let isDark: Bool
    let dayForeground: String
    let nightForeground: String
    let showsCharacter: Bool
    let isAnimating: Bool
    func makeUIView(context: Context) -> RoutimoriVacationNativeView {
        let view = RoutimoriVacationNativeView(dayForeground: dayForeground, nightForeground: nightForeground)
        view.showsCharacter = showsCharacter
        view.rig.setCharacterVisible(showsCharacter)
        return view
    }
    func updateUIView(_ view: RoutimoriVacationNativeView, context: Context) {
        view.slot = slot; view.isDark = isDark; view.showsCharacter = showsCharacter
        view.requestedAnimation = isAnimating; view.refresh()
    }
    static func dismantleUIView(_ view: RoutimoriVacationNativeView, coordinator: ()) { view.rig.setAnimating(false) }
}

private final class RoutimoriVacationNativeView: UIView {
    let rig: RoutimoriVacationRig
    var slot: CGRect?
    var isDark = false
    var requestedAnimation = false
    var showsCharacter = true
    private var scrollObservations: [NSKeyValueObservation] = []
    init(dayForeground: String, nightForeground: String) {
        rig = RoutimoriVacationRig(dayForegroundAsset: dayForeground, nightForegroundAsset: nightForeground)
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        layer.addSublayer(rig.root)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() { super.layoutSubviews(); refresh() }
    override func didMoveToWindow() { super.didMoveToWindow(); observeScrollViews(); refresh() }
    override func didMoveToSuperview() { super.didMoveToSuperview(); observeScrollViews(); refresh() }
    private func observeScrollViews() {
        scrollObservations.removeAll()
        var ancestor = superview
        while let view = ancestor {
            if let scroll = view as? UIScrollView {
                scrollObservations.append(scroll.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                    self?.refresh()
                })
            }
            ancestor = view.superview
        }
    }
    private var intersectsVisibleAncestors: Bool {
        guard let window, !bounds.isEmpty else { return false }
        var visible = convert(bounds, to: window).intersection(window.bounds)
        var ancestor: UIView? = self
        while let view = ancestor {
            if view.isHidden || view.alpha < 0.01 { return false }
            if view.clipsToBounds { visible = visible.intersection(view.convert(view.bounds, to: window)) }
            if visible.isNull || visible.isEmpty { return false }
            ancestor = view.superview
        }
        return true
    }
    func refresh() {
        rig.setCharacterVisible(showsCharacter)
        rig.layout(in: bounds, slot: slot, isDark: isDark, displayScale: window?.screen.scale ?? 2)
        rig.setAnimating(requestedAnimation && intersectsVisibleAncestors)
    }
}
#endif
