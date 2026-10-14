import QuartzCore
import SwiftUI

/// 휴가 화면의 배경: 하늘과 바다, 두 야자나무 사이의 해먹, 그 위에 누운 새싹이. 밝은 모드는 낮, 어두운 모드는 저녁이다.
///
/// 그림은 조각으로 나뉘어 있고(`VacationArt`) 전부 Core Animation 레이어에 올린다. 움직임도 레이어 애니메이션이다
/// (SwiftUI의 반복 애니메이션은 프레임마다 앱이 다시 계산해 CPU를 쓴다. 새싹이와 같은 이유).
/// 움직임 줄이기를 켰거나, 화면에서 사라지거나, 앱이 뒤로 가면 쉬는 자세로 멈춘다.
struct VacationSceneBackground: View {
    /// 해먹이 놓일 띠(이 뷰의 좌표). 아직 자리를 모르면 nil이고, 그동안은 가운데에 둔다.
    let slot: CGRect?
    /// 위쪽 안전 영역. 해와 구름을 그 아래에 둔다.
    var topInset: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    var body: some View {
        VacationSceneLayerView(
            slot: slot, topInset: topInset, isDark: colorScheme == .dark, displayScale: displayScale,
            isAnimating: isVisible && !reduceMotion && scenePhase == .active
        )
        .accessibilityHidden(true)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

/// 해먹이 놓일 띠의 자리를 배경에 알려 주는 값.
struct VacationSlotKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

/// 장면의 레이어를 올리고 움직이는 무대. macOS와 iOS가 함께 쓴다.
///
/// 겹치는 순서: 하늘 → 별 → 해 → 구름 → 풍경(산·바다·모래) → 두 야자나무(줄기 → 잎 → 열매)
/// → 흔들리는 묶음(`swing` → 숨쉬기 `breather`: 해먹과 누운 새싹이 → 마시는 손 → 고쳐 쓰는 손 → 머리 위 잎).
/// 손 그림과 잎은 해먹과 한 묶음으로 흔들리므로 서로 어긋나지 않는다.
@MainActor
final class VacationSceneStage {
    struct Configuration: Equatable {
        var layout: VacationSceneLayout
        var isDark: Bool
        var displayScale: CGFloat
    }

    private let root = CALayer()
    private let sky = CALayer()
    private let stars = CALayer()
    private let sun = CALayer()
    private let cloudLayers = VacationArt.clouds.map { _ in CALayer() }
    private let sceneryGroup = CALayer()
    private var sceneryTiles: [CALayer] = []
    private let sand = CALayer()
    private let rig = CALayer()
    private let trunks = [VacationArt.PalmSide.left: CALayer(), .right: CALayer()]
    private let fronds = [VacationArt.PalmSide.left: CALayer(), .right: CALayer()]
    private let coconuts = [VacationArt.PalmSide.left: CALayer(), .right: CALayer()]
    private let swing = CALayer()
    private let breather = CALayer()
    private let hammock = CALayer()
    private let sipHands = CALayer()
    private let adjustHands = CALayer()
    private let leaf = CALayer()

    private var configuration: Configuration?
    /// 지금 올려 둔 그림을 만들 때의 크기. 창 크기를 바꾸는 동안에는 있던 그림을 늘여 쓰다가, 멈추면 다시 만든다.
    private var rendered: Configuration?
    private var rerender: Task<Void, Never>?
    private var isAnimating = false
    private var actions: Task<Void, Never>?
    private var lastAction: VacationAction?

    private static let actionKey = "action"
    private static let loopKey = "loop"

    func install(in host: CALayer) {
        guard root.superlayer !== host else { return }
        #if os(macOS)
        // AppKit의 레이어는 아래가 원점이다. 이 무대 안에서는 iOS처럼 위에서 아래로 놓는다(양의 회전도 시계 방향이 된다).
        root.isGeometryFlipped = true
        #endif
        host.addSublayer(root)
        for layer in [sky, stars, sun] + cloudLayers + [sceneryGroup, sand, rig] { root.addSublayer(layer) }
        for side in VacationArt.PalmSide.allCases {
            for layer in [trunks[side], fronds[side], coconuts[side]] { rig.addSublayer(layer!) }
        }
        rig.addSublayer(swing)
        swing.addSublayer(breather)
        for layer in [hammock, sipHands, adjustHands, leaf] { breather.addSublayer(layer) }
        sky.contentsGravity = .resize
        sipHands.opacity = 0
        adjustHands.opacity = 0
    }

    func update(_ next: Configuration, isAnimating: Bool) {
        if next != configuration {
            let previous = configuration
            configuration = next
            layout(next)
            if rendered == nil || previous?.isDark != next.isDark || previous?.displayScale != next.displayScale {
                render(next)
            } else {
                // 크기만 바뀌었다(창 크기 조절, 회전): 잠깐 멈춘 뒤에 그 크기로 다시 만든다.
                rerender?.cancel()
                rerender = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(220))
                    guard !Task.isCancelled, let self, let current = self.configuration else { return }
                    self.render(current)
                }
            }
        }
        guard isAnimating != self.isAnimating else { return }
        if isAnimating { start() } else { stop() }
    }

    /// 뷰가 사라질 때: 움직임과 예약해 둔 일을 모두 내린다.
    func halt() {
        rerender?.cancel()
        stop()
    }

    // MARK: - 자리

    private func layout(_ configuration: Configuration) {
        let layout = configuration.layout
        let scale = configuration.displayScale
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.frame = CGRect(origin: .zero, size: layout.pane)

        place(sky, layout.skyFrame, scale: scale)
        place(stars, layout.starsFrame, scale: scale)
        stars.isHidden = !configuration.isDark
        place(sun, layout.sunFrame, scale: scale)
        for (layer, cloud) in zip(cloudLayers, VacationArt.clouds) { place(layer, layout.cloudFrame(cloud), scale: scale) }
        sand.frame = layout.sandFrame
        sand.backgroundColor = VacationArt.sandColor(isDark: configuration.isDark)

        // 풍경: 가운데 한 장과, 화면이 더 넓으면 양옆에 뒤집어 가며 붙인 장들.
        let perSide = layout.sceneryTilesPerSide
        let count = perSide * 2 + 1
        while sceneryTiles.count < count {
            let tile = CALayer()
            sceneryGroup.addSublayer(tile)
            sceneryTiles.append(tile)
        }
        while sceneryTiles.count > count { sceneryTiles.removeLast().removeFromSuperlayer() }
        sceneryGroup.frame = CGRect(origin: .zero, size: layout.pane)
        let center = aligned(layout.sceneryFrame, scale: scale)
        for (index, tile) in sceneryTiles.enumerated() {
            let offset = index - perSide
            tile.bounds = CGRect(origin: .zero, size: center.size)
            tile.position = CGPoint(x: center.midX + CGFloat(offset) * center.width, y: center.midY)
            tile.setAffineTransform(CGAffineTransform(scaleX: offset.isMultiple(of: 2) ? 1 : -1, y: 1))
        }

        // 해먹과 나무: 포즈 정사각형의 왼쪽 위를 원점으로 놓는다.
        let origin = layout.poseOrigin
        let side = layout.slot.width
        rig.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        rig.anchorPoint = .zero
        rig.position = CGPoint(x: (origin.x * scale).rounded() / scale, y: (origin.y * scale).rounded() / scale)
        for palm in VacationArt.PalmSide.allCases {
            let pieces = [(trunks[palm], VacationArt.palmTrunk(palm)), (fronds[palm], VacationArt.palmFronds(palm)), (coconuts[palm], VacationArt.palmCoconuts(palm))]
            for (layer, piece) in pieces {
                place(layer!, layout.rect(VacationArt.palmRect(piece, side: palm)), anchor: piece.anchor, scale: scale)
            }
        }
        // 흔들림과 숨쉬기 모두 줄이 묶인 높이를 기준으로 삼는다(기둥의 매듭은 제자리에 있다).
        let full = CGRect(x: 0, y: 0, width: side, height: side)
        let hook = CGPoint(x: 0.5, y: VacationArt.hookLine / VacationArt.canvas)
        place(swing, full, anchor: hook, scale: scale)
        place(breather, full, anchor: hook, scale: scale)
        for (layer, piece) in posePieces { place(layer, layout.rect(piece.rect), anchor: piece.anchor, scale: scale) }
        CATransaction.commit()
    }

    private var posePieces: [(CALayer, VacationArt.Piece)] {
        [
            (hammock, VacationArt.hammock), (sipHands, VacationArt.sipHands), (adjustHands, VacationArt.adjustHands),
            (leaf, VacationArt.leaf),
        ]
    }

    /// 화면의 픽셀에 맞춘 자리.
    private func aligned(_ frame: CGRect, scale: CGFloat) -> CGRect {
        let minX = (frame.minX * scale).rounded() / scale, minY = (frame.minY * scale).rounded() / scale
        let width = max((frame.width * scale).rounded(), 1) / scale, height = max((frame.height * scale).rounded(), 1) / scale
        return CGRect(x: minX, y: minY, width: width, height: height)
    }

    /// `anchor`(조각 안의 0…1, 왼쪽 위가 원점)를 기준점으로 삼아 레이어를 `frame`에 놓는다. 걸려 있는 변형은 건드리지 않는다.
    private func place(_ layer: CALayer, _ frame: CGRect, anchor: CGPoint = CGPoint(x: 0.5, y: 0.5), scale: CGFloat) {
        let frame = aligned(frame, scale: scale)
        layer.bounds = CGRect(origin: .zero, size: frame.size)
        layer.anchorPoint = anchor
        layer.position = CGPoint(x: frame.minX + frame.width * anchor.x, y: frame.minY + frame.height * anchor.y)
        layer.contentsScale = scale
        if layer !== sky { layer.contentsGravity = .resize }
    }

    // MARK: - 그림

    /// 지금 자리의 크기에 맞는 그림을 만들어 올린다.
    private func render(_ configuration: Configuration) {
        rendered = configuration
        let scale = configuration.displayScale
        let isDark = configuration.isDark
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        func set(_ layer: CALayer, _ asset: String) {
            let size = layer.bounds.size
            layer.contents = VacationArtRenderer.image(asset, pixels: CGSize(width: size.width * scale, height: size.height * scale))
        }
        // 하늘은 세로로 늘여 쓰는 가는 띠라 원본 그대로 올린다.
        sky.contents = VacationArtRenderer.source(VacationArt.name("vacation_sky", isDark: isDark))
        if isDark { set(stars, "vacation_stars_night") } else { stars.contents = nil }
        set(sun, VacationArt.name("vacation_sun", isDark: isDark))
        // 구름은 가장 큰 것에 맞춰 한 장만 만들어 함께 쓴다.
        if let largest = cloudLayers.max(by: { $0.bounds.width < $1.bounds.width }) {
            set(largest, VacationArt.name("vacation_cloud", isDark: isDark))
            for layer in cloudLayers { layer.contents = largest.contents }
        }
        if let first = sceneryTiles.first {
            set(first, VacationArt.name("vacation_scenery", isDark: isDark))
            for tile in sceneryTiles { tile.contents = first.contents }
        }
        for palm in VacationArt.PalmSide.allCases {
            set(trunks[palm]!, VacationArt.palmTrunk(palm).asset)
            set(fronds[palm]!, VacationArt.palmFronds(palm).asset)
            set(coconuts[palm]!, VacationArt.palmCoconuts(palm).asset)
        }
        for (layer, piece) in posePieces { set(layer, piece.asset) }
        CATransaction.commit()
    }

    // MARK: - 늘 도는 움직임

    private func start() {
        isAnimating = true
        let ease = CAMediaTimingFunction(name: .easeInEaseOut)
        func loop(_ layer: CALayer, _ keyPath: String, from: Any, to: Any, halfPeriod: Double, offset: Double = 0) {
            let animation = CABasicAnimation(keyPath: keyPath)
            animation.fromValue = from
            animation.toValue = to
            animation.duration = halfPeriod
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = ease
            animation.timeOffset = offset
            layer.add(animation, forKey: "\(Self.loopKey).\(keyPath)")
        }
        func shear(_ amount: CGFloat) -> NSValue {
            NSValue(caTransform3D: CATransform3DMakeAffineTransform(CGAffineTransform(a: 1, b: 0, c: amount, d: 1, tx: 0, ty: 0)))
        }
        // 해먹: 줄이 묶인 높이는 그대로 두고 아래로 갈수록 좌우로 더 움직인다(가운데에서 시작한다).
        loop(swing, "transform", from: shear(-VacationHammockMotion.swing), to: shear(VacationHammockMotion.swing),
             halfPeriod: VacationHammockMotion.swingHalfPeriod, offset: VacationHammockMotion.swingHalfPeriod / 2)
        // 숨쉬기: 새싹이가 숨을 쉴 때마다 해먹이 살짝 내려앉았다 오른다(매듭은 제자리).
        loop(breather, "transform.scale.y", from: 1, to: 1 + VacationHammockMotion.breath, halfPeriod: VacationHammockMotion.breathHalfPeriod)
        // 머리 위의 잎: 줄기 밑동을 중심으로 살랑인다.
        let leafAngle = VacationHammockMotion.leafAngle * .pi / 180
        loop(leaf, "transform.rotation.z", from: -leafAngle, to: leafAngle, halfPeriod: VacationHammockMotion.leafHalfPeriod,
             offset: VacationHammockMotion.leafHalfPeriod / 2)
        // 야자나무의 잎: 꼭대기를 중심으로 느리게, 두 나무가 서로 다른 박자로.
        let frondAngle = VacationHammockMotion.frondAngle * .pi / 180
        loop(fronds[.left]!, "transform.rotation.z", from: -frondAngle, to: frondAngle, halfPeriod: 2.7, offset: 1.1)
        loop(fronds[.right]!, "transform.rotation.z", from: frondAngle, to: -frondAngle, halfPeriod: 3.2, offset: 0.4)
        // 구름: 천천히 좌우로 흐른다.
        for (index, (layer, cloud)) in zip(cloudLayers, VacationArt.clouds).enumerated() {
            loop(layer, "transform.translation.x", from: -cloud.drift, to: cloud.drift, halfPeriod: cloud.duration, offset: Double(index) * 3.1)
        }

        // 가끔 하는 행동. 하나를 걸어 두고 끝날 때까지, 그리고 다음 행동까지 잠든다(한 번에 하나만 돈다).
        actions?.cancel()
        actions = Task { [weak self] in
            var generator = SystemRandomNumberGenerator()
            var delay = Self.debugRest ?? VacationAction.firstRest
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let self else { return }
                let action = Self.debugAction ?? VacationAction.next(after: self.lastAction, using: &generator)
                self.lastAction = action
                let plan = VacationMotionPlan.make(action)
                self.play(plan)
                try? await Task.sleep(for: .seconds(plan.duration))
                delay = Self.debugRest ?? Double.random(in: VacationAction.rest, using: &generator)
            }
        }
    }

    /// 움직임을 내리고 쉬는 자세로 돌아간다.
    private func stop() {
        isAnimating = false
        actions?.cancel()
        actions = nil
        for layer in [swing, breather, leaf, sipHands, adjustHands] + Array(fronds.values) + cloudLayers {
            for key in layer.animationKeys() ?? [] where key.hasPrefix(Self.actionKey) || key.hasPrefix(Self.loopKey) {
                layer.removeAnimation(forKey: key)
            }
        }
    }

    // MARK: - 가끔 하는 행동

    private func play(_ plan: VacationMotionPlan) {
        let degrees = Double.pi / 180
        add(plan.sipOpacity, to: sipHands, "opacity", plan: plan)
        add(plan.adjustOpacity, to: adjustHands, "opacity", plan: plan)
        // 잎과 숨쉬기는 늘 도는 움직임 위에 더한다.
        add(plan.leaf, to: leaf, "transform.rotation.z", scale: degrees, plan: plan, additive: true)
        add(plan.stretch, to: breather, "transform.scale.y", plan: plan, additive: true)
    }

    private func add(
        _ track: SaessagiTrack, to layer: CALayer, _ keyPath: String, scale: Double = 1, plan: VacationMotionPlan, additive: Bool = false
    ) {
        // 변하지 않는 값은 걸지 않는다.
        guard !track.isConstant else { return }
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = track.values.map { $0 * scale }
        animation.keyTimes = track.times.map { NSNumber(value: $0 / plan.duration) }
        animation.duration = plan.duration
        animation.calculationMode = .linear
        animation.isAdditive = additive
        animation.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: max(track.values.count - 1, 0))
        layer.add(animation, forKey: "\(Self.actionKey).\(keyPath)")
    }

    /// 화면 검증용: `-DaylogDebugVacationAction sip`처럼 주면 그 행동만 한다(sip, adjust, flutter, sigh. Debug 빌드만).
    private static var debugAction: VacationAction? {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "DaylogDebugVacationAction") {
        case "sip": return .sip
        case "adjust": return .adjust
        case "flutter": return .flutter
        case "sigh": return .sigh
        default: return nil
        }
        #else
        return nil
        #endif
    }

    /// 화면 검증용: `-DaylogDebugSaessagiRest 2`처럼 주면 쉬는 시간을 그 초로 고정한다(Debug 빌드만. 새싹이와 같은 값을 쓴다).
    private static var debugRest: Double? {
        #if DEBUG
        let value = UserDefaults.standard.double(forKey: "DaylogDebugSaessagiRest")
        return value > 0 ? value : nil
        #else
        return nil
        #endif
    }
}

#if os(macOS)
import AppKit

final class VacationSceneHostView: NSView {
    var onLayout: ((CGSize) -> Void)?

    override func layout() {
        super.layout()
        onLayout?(bounds.size)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct VacationSceneLayerView: NSViewRepresentable {
    let slot: CGRect?
    let topInset: CGFloat
    let isDark: Bool
    let displayScale: CGFloat
    let isAnimating: Bool

    func makeCoordinator() -> VacationSceneCoordinator { VacationSceneCoordinator() }

    func makeNSView(context: Context) -> VacationSceneHostView {
        let view = VacationSceneHostView()
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        let coordinator = context.coordinator
        view.onLayout = { size in coordinator.apply(pane: size) }
        return view
    }

    static func dismantleNSView(_ view: VacationSceneHostView, coordinator: VacationSceneCoordinator) {
        coordinator.stage.halt()
    }

    func updateNSView(_ view: VacationSceneHostView, context: Context) {
        guard let layer = view.layer else { return }
        let coordinator = context.coordinator
        coordinator.stage.install(in: layer)
        coordinator.set(slot: slot, topInset: topInset, isDark: isDark, displayScale: displayScale, isAnimating: isAnimating)
        coordinator.apply(pane: view.bounds.size)
    }
}
#else
import UIKit

final class VacationSceneHostView: UIView {
    var onLayout: ((CGSize) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?(bounds.size)
    }
}

struct VacationSceneLayerView: UIViewRepresentable {
    let slot: CGRect?
    let topInset: CGFloat
    let isDark: Bool
    let displayScale: CGFloat
    let isAnimating: Bool

    func makeCoordinator() -> VacationSceneCoordinator { VacationSceneCoordinator() }

    func makeUIView(context: Context) -> VacationSceneHostView {
        let view = VacationSceneHostView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.clipsToBounds = true
        let coordinator = context.coordinator
        view.onLayout = { size in coordinator.apply(pane: size) }
        return view
    }

    static func dismantleUIView(_ view: VacationSceneHostView, coordinator: VacationSceneCoordinator) {
        coordinator.stage.halt()
    }

    func updateUIView(_ view: VacationSceneHostView, context: Context) {
        let coordinator = context.coordinator
        coordinator.stage.install(in: view.layer)
        coordinator.set(slot: slot, topInset: topInset, isDark: isDark, displayScale: displayScale, isAnimating: isAnimating)
        coordinator.apply(pane: view.bounds.size)
    }
}
#endif

/// SwiftUI가 알려 준 값을 기억해 두었다가, 뷰의 크기가 정해질 때마다 무대에 넘긴다.
@MainActor
final class VacationSceneCoordinator {
    lazy var stage = VacationSceneStage()
    private var slot: CGRect?
    private var topInset: CGFloat = 0
    private var isDark = false
    private var displayScale: CGFloat = 1
    private var isAnimating = false

    func set(slot: CGRect?, topInset: CGFloat, isDark: Bool, displayScale: CGFloat, isAnimating: Bool) {
        self.slot = slot
        self.topInset = topInset
        self.isDark = isDark
        self.displayScale = max(displayScale, 1)
        self.isAnimating = isAnimating
    }

    func apply(pane: CGSize) {
        guard pane.width > 0, pane.height > 0 else { return }
        // 자리를 아직 모르면 가운데에 둔다(곧 제자리가 온다).
        let slot = slot ?? {
            let side = VacationArt.hammockSide(pane: pane, reserved: pane.height * 0.5)
            let height = side * VacationArt.slotHeight / VacationArt.canvas
            return CGRect(x: (pane.width - side) / 2, y: (pane.height - height) / 2, width: side, height: height)
        }()
        guard slot.width > 0 else { return }
        stage.update(
            VacationSceneStage.Configuration(
                layout: VacationSceneLayout(pane: pane, slot: slot, topInset: topInset), isDark: isDark, displayScale: displayScale
            ),
            isAnimating: isAnimating
        )
    }
}

/// 늘 도는 움직임의 크기와 박자.
enum VacationHammockMotion {
    /// 해먹이 좌우로 흔들리는 정도: 줄이 묶인 높이에서 아래로 1 내려갈 때 옆으로 가는 거리.
    static let swing: CGFloat = 0.032
    /// 한쪽 끝에서 반대쪽 끝까지 가는 시간(초).
    static let swingHalfPeriod: Double = 2.6
    /// 숨쉴 때 해먹이 늘어나는 비율(매듭 아래 길이에 대한)과, 들이쉬는(내쉬는) 시간.
    static let breath: CGFloat = 0.012
    static let breathHalfPeriod: Double = 1.9
    /// 머리 위 잎이 좌우로 기우는 각도(도)와 한쪽으로 가는 시간.
    static let leafAngle: Double = 3
    static let leafHalfPeriod: Double = 1.6
    /// 야자나무 잎이 기우는 각도(도).
    static let frondAngle: Double = 1.6
}
