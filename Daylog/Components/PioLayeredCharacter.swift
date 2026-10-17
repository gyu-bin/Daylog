#if DEBUG
import SwiftUI
import QuartzCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// A separate artwork-approved pilot. No wardrobe state or growth-stage mapping.
enum PioLayeredTrial {
    static var isEnabled: Bool {
        RoutimoriSplashTrial.isEnabled && UserDefaults.standard.bool(forKey: "DaylogDebugLayeredRig")
    }
    static let approvedOutfits: [PioOutfitID] = [.basic, .christmas, .hanbok, .astronaut]
    static func supportedMotions(for outfit: PioOutfitID) -> [PioLayeredMotion] {
        guard approvedOutfits.contains(outfit) else { return [] }
        return PioLayeredMotion.allCases
    }
}

enum PioLayeredMotion: String, CaseIterable, Identifiable {
    case idle, blink, wave, flap, walk, jump, landing, celebration, attachment
    var id: String { rawValue }
    var title: String {
        switch self {
        case .idle: "숨쉬기와 깜빡임"
        case .blink: "눈만 깜빡이기"
        case .wave: "오른 날개만 움직이기"
        case .flap: "날개 펄럭이기"
        case .walk: "제자리 발걸음"
        case .jump: "작은 점프"
        case .landing: "착지"
        case .celebration: "기뻐하기"
        case .attachment: "장식과 들고 있는 소품"
        }
    }
}

struct PioLayeredManifest: Decodable {
    struct Part: Decodable {
        let id: String
        let asset: String
        let rect: [Double]
        let pivot: [Double]
        let z: Int
        let neutralAngleDegrees: Double
        let fullCanvasSHA256: String
    }
    let revision: String
    let outfit: String
    let canvas: Double
    let stageArtID: String
    let supportsGrowthStages: Bool
    let parts: [Part]
}

@MainActor
enum PioLayeredResources {
    private static var manifests: [PioOutfitID: PioLayeredManifest] = [:]
    private static var images: [String: CGImage] = [:]
    private(set) static var sourceLoads = 0
    static var imageCount: Int { images.count }
    static var decodedBytes: Int { images.values.reduce(0) { $0 + $1.bytesPerRow * $1.height } }
    static func manifest(for outfit: PioOutfitID) -> PioLayeredManifest? {
        guard PioLayeredTrial.approvedOutfits.contains(outfit) else { return nil }
        if let cached = manifests[outfit] { return cached }
        guard let data = NSDataAsset(name: "pio_layered_\(outfit.rawValue)_registration")?.data,
              let manifest = try? JSONDecoder().decode(PioLayeredManifest.self, from: data),
              manifest.canvas == 1254, manifest.outfit == outfit.rawValue,
              !manifest.supportsGrowthStages, !manifest.parts.isEmpty,
              Set(manifest.parts.map(\.id)).count == manifest.parts.count,
              manifest.parts.allSatisfy({ $0.rect.count == 4 && $0.pivot.count == 2 && $0.rect[2] > 0 && $0.rect[3] > 0 }) else { return nil }
        // Entire set must resolve before selecting this renderer.
        guard manifest.parts.allSatisfy({ image(named: $0.asset) != nil }) else { return nil }
        manifests[outfit] = manifest
        return manifest
    }
    static func image(named name: String) -> CGImage? {
        if let cached = images[name] { return cached }
        #if os(macOS)
        let image = NSImage(named: name)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        let image = UIImage(named: name)?.cgImage
        #endif
        guard let image else { return nil }
        images[name] = image
        sourceLoads += 1
        return image
    }
}

@MainActor
enum PioLayeredMetrics {
    private final class WeakRig {
        weak var value: PioLayeredRig?
        init(_ value: PioLayeredRig) { self.value = value }
    }
    private static var rigs: [ObjectIdentifier: WeakRig] = [:]
    private static var counters: [String: Int] = [:]
    static func record(_ key: String) { counters[key, default: 0] += 1 }
    static func register(_ rig: PioLayeredRig) { rigs[ObjectIdentifier(rig)] = WeakRig(rig) }
    static func reset() { counters.removeAll(keepingCapacity: true) }
    static var presentations: [[String: Double]] { rigs.values.compactMap { $0.value?.presentationSnapshot } }
    static var snapshot: [String: Int] {
        rigs = rigs.filter { $0.value.value != nil }
        let live = rigs.values.compactMap(\.value)
        var result = counters
        for key in ["hostUpdates", "layouts", "effectiveLayouts", "configurations"] { result[key] = counters[key, default: 0] }
        result["liveRigs"] = live.count
        result["activeRigs"] = live.filter(\.isAnimating).count
        result["activeAnimationTracks"] = live.reduce(0) { $0 + $1.animationCount }
        for category in ["body", "eyes", "wings", "feet", "accessory"] {
            result[category + "Tracks"] = live.reduce(0) { $0 + $1.trackCount(category: category) }
        }
        result["cachedImages"] = PioLayeredResources.imageCount
        result["sourceLoads"] = PioLayeredResources.sourceLoads
        result["decodedBytes"] = PioLayeredResources.decodedBytes
        return result
    }
}

@MainActor
final class PioLayeredRig {
    let root = CALayer()
    let canvas = CALayer()
    let movement = CALayer()
    private(set) var layers: [String: CALayer] = [:]
    private(set) var leftGrip: CALayer?
    private(set) var manifest: PioLayeredManifest?
    private(set) var isAnimating = false
    private(set) var configurationCount = 0
    private var motion: PioLayeredMotion = .idle
    private var outfit: PioOutfitID?
    private var flatReference = false
    private var lastBounds: CGRect?
    private var lastScale: CGFloat?
    #if os(macOS)
    private static let down = -1.0
    #else
    private static let down = 1.0
    #endif
    init() {
        root.addSublayer(canvas)
        canvas.addSublayer(movement)
        canvas.bounds = CGRect(x: 0, y: 0, width: 1254, height: 1254)
        movement.bounds = canvas.bounds
        movement.anchorPoint = CGPoint(x: 0.5, y: Self.down < 0 ? 0.12 : 0.88)
        movement.position = CGPoint(x: 627, y: 1254 * movement.anchorPoint.y)
        PioLayeredMetrics.register(self)
    }
    @discardableResult
    func configure(outfit: PioOutfitID, motion: PioLayeredMotion, flatReference: Bool = false) -> Bool {
        guard PioLayeredTrial.supportedMotions(for: outfit).contains(motion),
              let next = PioLayeredResources.manifest(for: outfit) else {
            setAnimating(false)
            layers.values.forEach { $0.removeFromSuperlayer() }
            layers.removeAll(); leftGrip?.removeFromSuperlayer(); leftGrip = nil
            manifest = nil; self.outfit = nil
            return false
        }
        if self.outfit == outfit && self.motion == motion && manifest?.revision == next.revision && self.flatReference == flatReference { return true }
        let resume = isAnimating
        setAnimating(false)
        let changesArt = self.outfit != outfit || manifest?.revision != next.revision || self.flatReference != flatReference
        self.outfit = outfit; self.motion = motion; manifest = next; self.flatReference = flatReference
        configurationCount += 1; PioLayeredMetrics.record("configurations")
        if changesArt {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            layers.values.forEach { $0.removeFromSuperlayer() }; layers.removeAll()
            leftGrip?.removeFromSuperlayer(); leftGrip = nil
            if flatReference {
                let layer = CALayer()
                layer.name = "reference"; layer.frame = canvas.bounds
                layer.contents = PioLayeredResources.image(named: "pio_layered_\(outfit.rawValue)_reference")
                layer.minificationFilter = .trilinear
                movement.addSublayer(layer); layers["reference"] = layer
            } else {
            for part in next.parts.sorted(by: { $0.z < $1.z }) {
                let layer = CALayer(), r = part.rect, p = part.pivot
                layer.name = part.id
                layer.bounds = CGRect(x: 0, y: 0, width: r[2], height: r[3])
                let ax = (p[0] - r[0]) / r[2], ay = (p[1] - r[1]) / r[3]
                layer.anchorPoint = CGPoint(x: ax, y: Self.down < 0 ? 1-ay : ay)
                layer.position = CGPoint(x: p[0], y: Self.down < 0 ? next.canvas-p[1] : p[1])
                layer.contents = PioLayeredResources.image(named: part.asset)
                layer.contentsGravity = .resize
                layer.minificationFilter = .trilinear
                layer.transform = CATransform3DMakeRotation(part.neutralAngleDegrees * Self.down * .pi/180, 0, 0, 1)
                layer.opacity = (part.id.hasPrefix("lid") || part.id.hasPrefix("half")) ? 0 : 1
                if outfit == .christmas && (part.id == "gift" || part.id == "handLeft") {
                    if leftGrip == nil {
                        let group = CALayer()
                        let gripPivot = next.parts.first { $0.id == "handLeft" }!.pivot
                        group.name = "leftGrip"; group.bounds = canvas.bounds
                        group.anchorPoint = CGPoint(x: gripPivot[0]/1254, y: Self.down < 0 ? 1-gripPivot[1]/1254 : gripPivot[1]/1254)
                        group.position = CGPoint(x: gripPivot[0], y: Self.down < 0 ? 1254-gripPivot[1] : gripPivot[1])
                        movement.addSublayer(group); leftGrip = group
                    }
                    leftGrip?.addSublayer(layer)
                } else { movement.addSublayer(layer) }
                layers[part.id] = layer
            }
            }
            CATransaction.commit()
        }
        if resume { setAnimating(true) }
        return true
    }
    func layout(in bounds: CGRect, displayScale: CGFloat) {
        PioLayeredMetrics.record("layouts")
        guard lastBounds != bounds || lastScale != displayScale else { return }
        lastBounds = bounds; lastScale = displayScale
        PioLayeredMetrics.record("effectiveLayouts")
        CATransaction.begin(); CATransaction.setDisableActions(true)
        root.frame = bounds
        canvas.position = CGPoint(x: bounds.midX, y: bounds.midY)
        let scale = min(bounds.width, bounds.height) / 1254
        canvas.transform = CATransform3DMakeScale(scale, scale, 1)
        CATransaction.commit()
    }
    var animationCount: Int {
        (root.animationKeys()?.count ?? 0) + (canvas.animationKeys()?.count ?? 0) + (movement.animationKeys()?.count ?? 0)
            + (leftGrip?.animationKeys()?.count ?? 0)
            + layers.values.reduce(0) { $0 + ($1.animationKeys()?.count ?? 0) }
    }
    func trackCount(category: String) -> Int {
        let selected = layers.filter { id, _ in
            switch category {
            case "body": id == "body"
            case "eyes": id.hasPrefix("eye") || id.hasPrefix("lid") || id.hasPrefix("half")
            case "wings": id.hasPrefix("wing") || id.hasPrefix("hand")
            case "feet": id.hasPrefix("foot")
            case "accessory": id == "sprout" || id == "hat" || id == "gift"
            default: false
            }
        }
        let shared = ["wings", "accessory"].contains(category) ? (leftGrip?.animationKeys()?.count ?? 0) : 0
        let own = selected.values.reduce(0) { $0 + ($1.animationKeys()?.count ?? 0) } + shared
        // Parent breathing/jump transforms move the body too: never report a
        // false body=0 merely because the texture layer has no own animation.
        return own + (category == "body" ? (root.animationKeys()?.count ?? 0) + (canvas.animationKeys()?.count ?? 0) + (movement.animationKeys()?.count ?? 0) : 0)
    }
    var presentationSnapshot: [String: Double] {
        var values: [String: Double] = [:]
        let groups: [(String, CALayer)] = leftGrip.map { [("leftGrip", $0)] } ?? []
        for (name, layer) in [("root", root), ("canvas", canvas), ("movement", movement)] + groups + layers.sorted(by: { $0.key < $1.key }).map({ ($0.key, $0.value) }) {
            let sampled = layer.presentation() ?? layer
            let transform = sampled.transform
            values[name + ".rotation"] = atan2(transform.m12, transform.m11)
            values[name + ".translationX"] = transform.m41
            values[name + ".translationY"] = transform.m42
            values[name + ".x"] = sampled.position.x
            values[name + ".y"] = sampled.position.y
            values[name + ".scaleX"] = hypot(transform.m11, transform.m12)
            values[name + ".scaleY"] = hypot(transform.m21, transform.m22)
            values[name + ".opacity"] = Double(sampled.opacity)
        }
        return values
    }
    func setAnimating(_ requested: Bool, reduceMotion: Bool = false) {
        let active = requested && !reduceMotion && manifest != nil && !flatReference
        guard active != isAnimating else { return }
        isAnimating = active
        if !active {
            root.removeAllAnimations(); canvas.removeAllAnimations(); movement.removeAllAnimations(); leftGrip?.removeAllAnimations()
            layers.values.forEach { $0.removeAllAnimations() }
            return
        }
        switch motion {
        case .idle:
            add(movement, "transform.scale.y", [1,1.012,1], [0,0.5,1], 3.2)
            blink(); accessory()
        case .blink: blink()
        case .wave: wing("Right", 12)
        case .flap:
            if let leftGrip {
                add(leftGrip, "transform.rotation.z", [0,6,-6,6,-6,0,0].map { $0 * Self.down * .pi/180 }, [0,0.16,0.32,0.48,0.64,0.8,1], 3.2)
            } else { wing("Left", -12) }
            wing("Right", 12)
        case .walk: feet()
        case .jump:
            add(movement, "transform.translation.y", [0,-36 * Self.down,0,0], [0,0.3,0.6,1], 3)
        case .landing:
            add(movement, "transform.scale.y", [1,0.97,1.01,1,1], [0,0.12,0.3,0.5,1], 3)
            add(movement, "transform.scale.x", [1,1.03,0.99,1,1], [0,0.12,0.3,0.5,1], 3)
        case .celebration:
            add(movement, "transform.translation.y", [0,-20 * Self.down,0,0], [0,0.3,0.6,1], 3)
            if outfit != .christmas { wing("Left", -10) }
            wing("Right", 10)
        case .attachment:
            accessory()
            if outfit == .christmas {
                add(leftGrip, "transform.translation.x", [0,-4,4,0], [0,0.25,0.75,1], 3.6)
                add(leftGrip, "transform.translation.y", [0,-8 * Self.down,8 * Self.down,0], [0,0.25,0.75,1], 3.6)
            }
        }
    }
    private func blink() {
        // Exactly one genuine eye texture is visible at a time. A short half-lid
        // transition avoids the gray doubled-eye artifact of opacity crossfades.
        let times = [0.0, 0.40, 0.416, 0.446, 0.462, 1.0]
        for side in ["Left", "Right"] {
            add(layers["eye"+side], "opacity", [1,0,0,0,1,1], times, 3.6, discrete: true)
            add(layers["half"+side], "opacity", [0,1,0,1,0,0], times, 3.6, discrete: true)
            add(layers["lid"+side], "opacity", [0,0,1,0,0,0], times, 3.6, discrete: true)
        }
    }
    private func wing(_ side: String, _ amplitude: Double) {
        let id = layers["wing"+side] != nil ? "wing"+side : "hand"+side
        rotate(id, [0,-amplitude,amplitude,-amplitude,amplitude,0,0], [0,0.16,0.32,0.48,0.64,0.8,1], 3.2)
    }
    private func feet() {
        for (side, start) in [("Left", 0.0), ("Right", 0.5)] {
            let id="foot"+side
            // The original basic pose kicks its right foot 35 master pixels higher.
            // The separately reviewed plant lowers that foot to the left toe ground.
            let plant = outfit == .basic && side == "Right" ? 35.0 : 0.0
            add(layers[id], "transform.translation.y", [plant,plant-18,plant,plant].map { $0 * Self.down }, [0,0.25,0.5,1], 1.6, offset: start*1.6)
            rotate(id, [0,side == "Left" ? -8 : 8,0,0], [0,0.25,0.5,1], 1.6, offset: start*1.6)
        }
    }
    private func accessory() {
        let id=layers["sprout"] != nil ? "sprout" : "hat"
        rotate(id, [0,-4,4,0], [0,0.25,0.75,1], 3.6)
    }
    private func rotate(_ id: String, _ degrees: [Double], _ times: [Double], _ duration: Double, offset: Double = 0) {
        let neutral=manifest?.parts.first(where: { $0.id == id })?.neutralAngleDegrees ?? 0
        add(layers[id], "transform.rotation.z", degrees.map { ($0+neutral) * Self.down * .pi/180 }, times, duration, offset: offset)
    }
    private func add(_ layer: CALayer?, _ key: String, _ values: [Double], _ times: [Double], _ duration: Double, offset: Double = 0, discrete: Bool = false) {
        guard let layer else { return }
        let animation=CAKeyframeAnimation(keyPath: key)
        animation.values=values; animation.keyTimes=times.map { NSNumber(value: $0) }
        animation.duration=duration; animation.repeatCount = .infinity; animation.timeOffset=offset
        if discrete { animation.calculationMode = .discrete }
        else { animation.timingFunctions=Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: values.count-1) }
        layer.add(animation, forKey: "layered."+key)
    }
}

struct PioLayeredCharacterView: View {
    let outfit: PioOutfitID
    var motion: PioLayeredMotion = .idle
    var isAnimating = true
    var flatReference = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible=false
    @State private var onScreen=true
    var body: some View {
        Group {
            if PioLayeredTrial.isEnabled, PioLayeredResources.manifest(for: outfit) != nil {
                PioLayeredHost(outfit: outfit, motion: motion, flatReference: flatReference, active: isAnimating && visible && onScreen && scenePhase == .active && !reduceMotion)
            } else { Text("승인된 레이어 원화 없음").font(.caption) }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
        .onAppear { visible=true }.onDisappear { visible=false }
        .modifier(PioLayeredVisibility(onScreen: $onScreen))
    }
}
private struct PioLayeredVisibility: ViewModifier {
    @Binding var onScreen: Bool
    func body(content: Content) -> some View {
        if #available(macOS 15, iOS 18, *) {
            content.onScrollVisibilityChange(threshold: 0.05) { onScreen=$0 }
        } else { content }
    }
}
#if os(macOS)
private struct PioLayeredHost: NSViewRepresentable {
    let outfit: PioOutfitID; let motion: PioLayeredMotion; let flatReference: Bool; let active: Bool
    func makeNSView(context: Context) -> PioLayeredNativeView { PioLayeredNativeView() }
    func updateNSView(_ view: PioLayeredNativeView, context: Context) {
        PioLayeredMetrics.record("hostUpdates")
        view.rig.configure(outfit: outfit, motion: motion, flatReference: flatReference); view.requested=active; view.refresh()
    }
    static func dismantleNSView(_ view: PioLayeredNativeView, coordinator: ()) { view.rig.setAnimating(false) }
}
private final class PioLayeredNativeView: NSView {
    let rig=PioLayeredRig(); var requested=false
    init() { super.init(frame: .zero); wantsLayer=true; layer?.addSublayer(rig.root) }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    override func layout() { super.layout(); refresh() }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); refresh() }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    func refresh() { rig.layout(in: bounds, displayScale: window?.backingScaleFactor ?? 2); rig.setAnimating(requested && window != nil) }
}
#else
private struct PioLayeredHost: UIViewRepresentable {
    let outfit: PioOutfitID; let motion: PioLayeredMotion; let flatReference: Bool; let active: Bool
    func makeUIView(context: Context) -> PioLayeredNativeView { PioLayeredNativeView() }
    func updateUIView(_ view: PioLayeredNativeView, context: Context) {
        PioLayeredMetrics.record("hostUpdates")
        view.rig.configure(outfit: outfit, motion: motion, flatReference: flatReference); view.requested=active; view.refresh()
    }
    static func dismantleUIView(_ view: PioLayeredNativeView, coordinator: ()) { view.rig.setAnimating(false) }
}
private final class PioLayeredNativeView: UIView {
    let rig=PioLayeredRig(); var requested=false
    init() { super.init(frame: .zero); isUserInteractionEnabled=false; layer.addSublayer(rig.root) }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    override func layoutSubviews() { super.layoutSubviews(); refresh() }
    override func didMoveToWindow() { super.didMoveToWindow(); refresh() }
    func refresh() { rig.layout(in: bounds, displayScale: window?.screen.scale ?? 2); rig.setAnimating(requested && window != nil) }
}
#endif
#endif
