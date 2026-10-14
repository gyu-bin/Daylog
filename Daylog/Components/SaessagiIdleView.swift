import QuartzCore
import SwiftUI

/// 기본 모습의 새싹이를 대기·걷기 애니메이션용으로 나눈 레이어. 기본 그림(`saessagi_idle`)과 크기·자리가 같다.
/// `Tools/saessagi-layers.swift`가 원본에서 잘라 만든다. 아래 좌표는 그 스크립트의 값과 맞춰야 한다(1024 기준 픽셀, 위에서 아래로).
enum SaessagiIdleLayers {
    static let body = "saessagi_idle_body"
    static let leaf = "saessagi_idle_leaf"
    static let eyes = "saessagi_idle_eyes"
    static let mouth = "saessagi_idle_mouth"
    static let footLeft = "saessagi_idle_foot_left"
    static let footRight = "saessagi_idle_foot_right"
    static let all = [body, leaf, eyes, mouth, footLeft, footRight]

    /// 잎이 도는 중심: 줄기가 머리로 들어가는 자리.
    static let leafPivot = CGPoint(x: 512, y: 288)
    /// 눈이 접히는 중심: 두 눈의 한가운데 높이.
    static let eyeCenter = CGPoint(x: 509.5, y: 569.5)
    /// 걸을 때 몸이 좌우로 기우는 중심: 다리 사이.
    static let hip = CGPoint(x: 512, y: 905)
}

/// 대기 애니메이션의 크기와 박자. 작고 느리게: 눈에 띄되 거슬리지 않게.
enum SaessagiIdleMotion {
    /// 잎이 좌우로 기우는 각도(도). 48pt로 작게 그려도 움직임이 보일 만큼.
    static let leafAngle = 6.0
    /// 잎이 한쪽 끝에서 반대쪽 끝까지 가는 시간(초).
    static let leafHalfPeriod = 1.3
    /// 숨을 들이쉴 때 키가 늘어나는 비율. 48pt에서 2pt쯤.
    static let breathStretch = 0.04
    /// 들숨 또는 날숨 한 번의 시간(초).
    static let breathHalfPeriod = 1.6
    /// 눈을 감는 시간과 뜨는 시간(초). 합쳐 약 0.2초.
    static let blinkClose = 0.09
    static let blinkOpen = 0.11
    /// 감았을 때 눈의 높이(원래의 몇 배). 0이면 선이 사라지므로 조금 남긴다.
    static let closedEyeScale = 0.1
    /// 깜빡임이 시작되는 때(초)와 한 바퀴의 길이. 사이가 3~5초이고, 마지막은 두 번 연달아 깜빡인다.
    /// 앱이 때마다 깨어나 정하지 않도록 한 바퀴를 정해 두고 되풀이한다(한 바퀴가 길어 규칙적으로 보이지 않는다).
    static let blinkStarts = [3.4, 7.9, 11.6, 11.92]
    static let blinkCycle = 12.6

    /// 눈 높이의 변화를 키프레임으로 푼 것: 떠 있다가(1) 감고(`closedEyeScale`) 다시 뜬다.
    static var blinkTrack: (values: [Double], keyTimes: [Double], duration: Double) {
        var values = [1.0], times = [0.0]
        for start in blinkStarts {
            values += [1, closedEyeScale, 1]
            times += [start, start + blinkClose, start + blinkClose + blinkOpen]
        }
        values.append(1)
        times.append(blinkCycle)
        return (values, times.map { $0 / blinkCycle }, blinkCycle)
    }
}

/// 살아 있는 기본 모습: 잎이 바람에 흔들리고, 눈을 깜빡이고, 숨을 쉬고, 가끔 걷거나 두리번거리거나 폴짝 뛰거나 존다.
///
/// 몸·발·눈·입·잎을 따로 겹쳐 그리고 부분만 움직인다(그림 전체를 흔들거나 밀지 않는다). 레이어는 기본 그림과 같은 방식으로
/// 미리 줄여 둔 것이라 가만히 있을 때는 한 장짜리 그림과 거의 똑같이 보인다.
/// 움직임 줄이기를 켰거나 레이어를 만들지 못하면 정지 그림을 보여 준다. 화면에서 사라지거나 앱이 뒤로 가면 멈춘다.
///
/// 이 뷰는 가로로 늘어난다: 받은 너비에서 새싹이 한 칸을 뺀 만큼이 걸어 다닐 자리다. 자리가 없으면 걷지 않는다.
///
/// 움직임은 Core Animation에 맡긴다. SwiftUI의 반복 애니메이션으로 돌리면 프레임마다 앱이 다시 계산해서
/// 이 작은 그림 하나에 CPU를 10% 넘게 썼다(실측). 레이어 애니메이션은 앱이 프레임마다 할 일이 없다.
struct SaessagiIdleView: View {
    var size: CGFloat = 48
    /// 처음 서 있을 자리(왼쪽 끝에서 오른쪽으로 떨어진 거리).
    var startX: CGFloat = 0
    /// 지금 어디에 있는지 물어볼 수 있게 무대를 이어 두는 고리.
    var link: SaessagiStageLink?
    /// 자리가 넓어도 이보다 멀리는 가지 않는다(pt).
    var maxRange: CGFloat = 60
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    var body: some View {
        if !reduceMotion, let layers = SaessagiIdleImages(size: size, displayScale: displayScale) {
            SaessagiIdleLayerView(
                images: layers, size: size, displayScale: displayScale, startX: startX, link: link, maxRange: maxRange,
                isAnimating: isVisible && scenePhase == .active
            )
            .frame(minWidth: size, idealWidth: size, maxWidth: .infinity)
            .frame(height: size)
            .accessibilityHidden(true)
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
        } else {
            SaessagiView(pose: .idle, size: size)
        }
    }
}

/// 미리 줄여 둔 레이어들.
struct SaessagiIdleImages {
    let body: CGImage
    let eyes: CGImage
    let mouth: CGImage
    let leaf: CGImage
    let footLeft: CGImage
    let footRight: CGImage

    @MainActor
    init?(size: CGFloat, displayScale: CGFloat) {
        func layer(_ asset: String) -> CGImage? {
            SaessagiRenderer.image(asset: asset, pose: .idle, size: size, displayScale: displayScale)
        }
        guard let body = layer(SaessagiIdleLayers.body), let eyes = layer(SaessagiIdleLayers.eyes),
              let mouth = layer(SaessagiIdleLayers.mouth), let leaf = layer(SaessagiIdleLayers.leaf),
              let footLeft = layer(SaessagiIdleLayers.footLeft), let footRight = layer(SaessagiIdleLayers.footRight)
        else { return nil }
        self.body = body
        self.eyes = eyes
        self.mouth = mouth
        self.leaf = leaf
        self.footLeft = footLeft
        self.footRight = footRight
    }
}

/// 걷다가 다른 모습(기쁨·휴식)으로 바뀔 때, 그 그림을 새싹이가 서 있던 자리에 놓으려고 지금 위치를 묻는 고리.
@MainActor
final class SaessagiStageLink {
    fileprivate weak var stage: SaessagiIdleStage?

    /// 제자리에서 오른쪽으로 떨어진 거리(pt). 무대가 없으면(다른 모습이 떠 있으면) nil.
    func currentOffset() -> CGFloat? {
        stage?.currentOffset()
    }
}

/// 레이어를 올리고 움직임을 거는 일. macOS와 iOS가 함께 쓴다.
///
/// 겹치는 순서와 묶음: 걷는 이동(`mover`) → 숨쉬기(`breather`) → 두 발, 그 위에 몸통(`torso`: 몸 → 얼굴(입·눈) → 잎).
@MainActor
final class SaessagiIdleStage {
    private let mover = CALayer()
    private let breather = CALayer()
    private let footLeft = CALayer()
    private let footRight = CALayer()
    private let torso = CALayer()
    private let bodyLayer = CALayer()
    private let face = CALayer()
    private let mouthLayer = CALayer()
    private let eyesLayer = CALayer()
    private let leafLayer = CALayer()
    private var isAnimating = false
    /// 지금 올려 둔 그림의 크기와 배율. 바뀌면 다시 놓는다.
    private var configuration: (size: CGFloat, scale: CGFloat)?
    private var size: CGFloat = 48
    /// 걸어 다닐 수 있는 거리(pt): 받은 너비에서 새싹이 한 칸을 뺀 만큼, 상한(`maxRange`)까지.
    private var range: CGFloat = 0
    private var laneWidth: CGFloat = 0
    private var maxRange: CGFloat = 60
    /// 지금 서 있는 자리(왼쪽 끝에서 오른쪽으로 떨어진 거리). 걸으면 바뀐다.
    private var restingX: CGFloat = 0
    private var actions: Task<Void, Never>?
    private var lastAction: SaessagiAction?

    #if os(macOS)
    /// AppKit의 레이어는 아래가 원점이다: 위쪽이 +y, 양의 회전이 시계 반대 방향.
    private static let up: CGFloat = 1
    private static let clockwise: CGFloat = -1
    #else
    private static let up: CGFloat = -1
    private static let clockwise: CGFloat = 1
    #endif

    private static let walkKey = "walk"

    func install(in host: CALayer, startX: CGFloat, link: SaessagiStageLink?) {
        link?.stage = self
        guard mover.superlayer !== host else { return }
        host.addSublayer(mover)
        mover.addSublayer(breather)
        for layer in [footLeft, footRight, torso] { breather.addSublayer(layer) }
        for layer in [bodyLayer, face, leafLayer] { torso.addSublayer(layer) }
        for layer in [mouthLayer, eyesLayer] { face.addSublayer(layer) }
        restingX = max(startX, 0)
    }

    /// 걸어 다닐 자리의 너비가 정해졌다(레이아웃 때마다).
    func setLaneWidth(_ width: CGFloat) {
        laneWidth = width
        range = min(max(width - size, 0), maxRange)
        // 자리가 좁아졌으면(창 크기 변경) 그 안으로 들어온다. 걷는 중이 아닐 때만.
        if restingX > range + 0.5, !isActing {
            restingX = range
            setModelX(restingX)
        }
    }

    /// 걷기 같은 행동이 돌고 있는가.
    private var isActing: Bool {
        mover.animationKeys()?.contains { $0.hasPrefix(Self.walkKey) } ?? false
    }

    private func setModelX(_ x: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mover.setValue(x, forKeyPath: "transform.translation.x")
        CATransaction.commit()
    }

    /// 뷰가 사라질 때: 움직임과 예약해 둔 행동을 모두 내린다.
    func halt() {
        stop()
    }

    func update(images: SaessagiIdleImages, size: CGFloat, displayScale: CGFloat, maxRange: CGFloat, isAnimating: Bool) {
        self.maxRange = maxRange
        if configuration?.size != size || configuration?.scale != displayScale {
            // 크기가 바뀌었으면 움직임을 내리고 새 기준점으로 다시 건다.
            if self.isAnimating { stop() }
            configuration = (size, displayScale)
            self.size = size
            layout(images: images, size: size, displayScale: displayScale)
        }
        setLaneWidth(laneWidth)
        guard isAnimating != self.isAnimating else { return }
        if isAnimating { start() } else { stop() }
    }

    /// 제자리에서 오른쪽으로 떨어진 거리(pt). 걷는 중이면 화면에 보이는 그 순간의 값이다.
    func currentOffset() -> CGFloat {
        let layer = mover.presentation() ?? mover
        return (layer.value(forKeyPath: "transform.translation.x") as? CGFloat) ?? 0
    }

    private func layout(images: SaessagiIdleImages, size: CGFloat, displayScale: CGFloat) {
        let side = size + SaessagiRenderer.padding * 2
        let content = SaessagiPose.idle.content
        func unit(_ source: CGPoint) -> CGPoint { SaessagiRenderer.unitPoint(of: source, pose: .idle, size: size) }
        let center = CGPoint(x: 0.5, y: 0.5)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // 눌리고 늘어나는 기준과 숨쉬기의 기준은 발밑 가운데, 몸이 기우는 기준은 다리 사이. 눈과 잎은 각자의 중심.
        let feet = unit(CGPoint(x: content.midX, y: content.maxY))
        place(mover, anchor: feet, side: side)
        // 레이어 그림은 틀보다 사방으로 여백만큼 크다(한 장짜리 그림과 같다).
        mover.position.x -= SaessagiRenderer.padding
        mover.position.y -= SaessagiRenderer.padding
        place(breather, anchor: feet, side: side)
        place(footLeft, anchor: center, side: side)
        place(footRight, anchor: center, side: side)
        place(torso, anchor: unit(SaessagiIdleLayers.hip), side: side)
        place(bodyLayer, anchor: center, side: side)
        place(face, anchor: center, side: side)
        place(mouthLayer, anchor: center, side: side)
        place(eyesLayer, anchor: unit(SaessagiIdleLayers.eyeCenter), side: side)
        place(leafLayer, anchor: unit(SaessagiIdleLayers.leafPivot), side: side)
        let contents: [(CALayer, CGImage)] = [
            (footLeft, images.footLeft), (footRight, images.footRight), (bodyLayer, images.body),
            (mouthLayer, images.mouth), (eyesLayer, images.eyes), (leafLayer, images.leaf),
        ]
        for (layer, image) in contents {
            layer.contents = image
            layer.contentsScale = displayScale
            layer.contentsGravity = .resize
        }
        mover.setValue(restingX, forKeyPath: "transform.translation.x")
        CATransaction.commit()
    }

    /// `anchor`(왼쪽 위가 원점인 0…1)를 중심으로 삼아 한 변이 `side`인 레이어를 제자리에 놓는다.
    private func place(_ layer: CALayer, anchor: CGPoint, side: CGFloat) {
        #if os(macOS)
        let point = CGPoint(x: anchor.x, y: 1 - anchor.y)
        #else
        let point = anchor
        #endif
        layer.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        layer.anchorPoint = point
        layer.position = CGPoint(x: point.x * side, y: point.y * side)
    }

    // MARK: - 평소의 움직임

    private func start() {
        isAnimating = true
        let ease = CAMediaTimingFunction(name: .easeInEaseOut)

        // 잎: 줄기 밑동을 중심으로 좌우로.
        let angle = SaessagiIdleMotion.leafAngle * .pi / 180
        let sway = CABasicAnimation(keyPath: "transform.rotation.z")
        sway.fromValue = -angle
        sway.toValue = angle
        sway.duration = SaessagiIdleMotion.leafHalfPeriod
        sway.autoreverses = true
        sway.repeatCount = .infinity
        sway.timingFunction = ease
        // 가운데에서 시작하는 것처럼 보이게 반 박자 앞에서 출발한다.
        sway.timeOffset = SaessagiIdleMotion.leafHalfPeriod / 2
        leafLayer.add(sway, forKey: "sway")

        // 숨쉬기: 발은 제자리, 키만 조금.
        let breath = CABasicAnimation(keyPath: "transform.scale.y")
        breath.fromValue = 1
        breath.toValue = 1 + SaessagiIdleMotion.breathStretch
        breath.duration = SaessagiIdleMotion.breathHalfPeriod
        breath.autoreverses = true
        breath.repeatCount = .infinity
        breath.timingFunction = ease
        breather.add(breath, forKey: "breath")

        // 눈: 정해 둔 박자대로 감았다 뜬다.
        let blink = CAKeyframeAnimation(keyPath: "transform.scale.y")
        let track = SaessagiIdleMotion.blinkTrack
        blink.values = track.values
        blink.keyTimes = track.keyTimes.map { NSNumber(value: $0) }
        blink.duration = track.duration
        blink.repeatCount = .infinity
        blink.calculationMode = .linear
        eyesLayer.add(blink, forKey: "blink")

        // 가끔 하는 행동. 행동 하나를 걸어 두고 끝날 때까지, 그리고 다음 행동까지 잠든다(한 번에 하나만 돈다).
        actions?.cancel()
        actions = Task { [weak self] in
            var delay = Self.firstRest
            var generator = SystemRandomNumberGenerator()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let self else { return }
                let action = Self.debugAction ?? SaessagiAction.next(after: self.lastAction, using: &generator)
                self.lastAction = action
                let duration = self.play(action, using: &generator)
                try? await Task.sleep(for: .seconds(duration))
                delay = Self.rest(using: &generator)
            }
        }
    }

    /// 움직임을 내리고 서 있던 자리에 가만히 선 모습으로 돌아간다.
    private func stop() {
        isAnimating = false
        actions?.cancel()
        actions = nil
        leafLayer.removeAnimation(forKey: "sway")
        breather.removeAnimation(forKey: "breath")
        eyesLayer.removeAnimation(forKey: "blink")
        for layer in [mover, footLeft, footRight, torso, face, eyesLayer, leafLayer] {
            for key in layer.animationKeys() ?? [] where key.hasPrefix(Self.walkKey) { layer.removeAnimation(forKey: key) }
        }
        setModelX(restingX)
    }

    // MARK: - 가끔 하는 행동

    /// 행동 하나를 시작하고 걸리는 시간(초)을 돌려준다. 하지 않으면 0.
    private func play(_ action: SaessagiAction, using generator: inout some RandomNumberGenerator) -> Double {
        let plan: SaessagiMotionPlan?
        switch action {
        case .stay:
            plan = nil
        case .walk:
            plan = SaessagiMotionPlan.walkTarget(from: restingX, range: range, size: size, using: &generator)
                .flatMap { SaessagiMotionPlan.walk(from: restingX, to: $0, size: size) }
        case .lookAround:
            plan = .lookAround(at: restingX, size: size)
        case .hop:
            plan = .hop(at: restingX, size: size)
        case .doze:
            plan = .doze(at: restingX, size: size)
        case .tumble, .peek:
            // 아직 만들지 않은 동작.
            plan = nil
        }
        guard let plan else { return 0 }
        // 끝나면 걸어간 자리에 서 있다.
        restingX = plan.finalX
        setModelX(restingX)
        let degrees = Double.pi / 180 * Self.clockwise
        // 몸의 이동과 발의 좌우 위치는 곧게 이어야 디딘 발이 땅에서 미끄러지지 않는다.
        add(plan.moverX, to: mover, keyPath: "transform.translation.x", plan: plan, eased: false)
        add(plan.bob, to: mover, keyPath: "transform.translation.y", scale: Self.up, plan: plan)
        add(plan.squashX, to: mover, keyPath: "transform.scale.x", plan: plan)
        add(plan.squashY, to: mover, keyPath: "transform.scale.y", plan: plan)
        add(plan.footLeftX, to: footLeft, keyPath: "transform.translation.x", plan: plan, eased: false)
        add(plan.footLeftLift, to: footLeft, keyPath: "transform.translation.y", scale: Self.up, plan: plan)
        add(plan.footRightX, to: footRight, keyPath: "transform.translation.x", plan: plan, eased: false)
        add(plan.footRightLift, to: footRight, keyPath: "transform.translation.y", scale: Self.up, plan: plan)
        add(plan.rock, to: torso, keyPath: "transform.rotation.z", scale: degrees, plan: plan)
        // 잎은 평소의 흔들림 위에 행동의 흔들림을 더한다.
        add(plan.leaf, to: leafLayer, keyPath: "transform.rotation.z", scale: degrees, plan: plan, additive: true)
        add(plan.face, to: face, keyPath: "transform.translation.x", plan: plan)
        // 눈은 행동이 도는 동안 평소의 깜빡임 대신 이 값을 따른다(나중에 건 애니메이션이 이긴다).
        add(plan.eyes, to: eyesLayer, keyPath: "transform.scale.y", plan: plan)
        return plan.duration
    }

    private func add(
        _ track: SaessagiTrack, to layer: CALayer, keyPath: String, scale: Double = 1, plan: SaessagiMotionPlan,
        eased: Bool = true, additive: Bool = false
    ) {
        // 변하지 않는 값은 걸지 않는다.
        guard !track.isConstant else { return }
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = track.values.map { $0 * scale }
        animation.keyTimes = track.times.map { NSNumber(value: $0 / plan.duration) }
        animation.duration = plan.duration
        animation.calculationMode = .linear
        animation.isAdditive = additive
        if eased {
            animation.timingFunctions = Array(
                repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: max(track.values.count - 1, 0)
            )
        }
        layer.add(animation, forKey: "\(Self.walkKey).\(keyPath)")
    }

    private static var firstRest: Double {
        debugRest ?? SaessagiWalkMotion.firstRest
    }

    private static func rest(using generator: inout some RandomNumberGenerator) -> Double {
        debugRest ?? Double.random(in: SaessagiWalkMotion.rest, using: &generator)
    }

    /// 화면 검증용: `-DaylogDebugSaessagiAction hop`처럼 주면 그 행동만 한다(walk, lookAround, hop, doze. Debug 빌드만).
    private static var debugAction: SaessagiAction? {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "DaylogDebugSaessagiAction") {
        case "walk": return .walk
        case "lookAround": return .lookAround
        case "hop": return .hop
        case "doze": return .doze
        default: return nil
        }
        #else
        return nil
        #endif
    }

    /// 화면 검증용: `-DaylogDebugSaessagiRest 2`처럼 주면 쉬는 시간을 그 초로 고정한다(Debug 빌드만).
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

/// 레이어를 얹는 빈 뷰. 너비가 정해질 때마다 알려 주고, 누르기는 받지 않는다.
final class SaessagiHostView: NSView {
    var onLayout: ((CGFloat) -> Void)?

    override func layout() {
        super.layout()
        onLayout?(bounds.width)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct SaessagiIdleLayerView: NSViewRepresentable {
    let images: SaessagiIdleImages
    let size: CGFloat
    let displayScale: CGFloat
    let startX: CGFloat
    let link: SaessagiStageLink?
    let maxRange: CGFloat
    let isAnimating: Bool

    final class Coordinator {
        @MainActor lazy var stage = SaessagiIdleStage()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SaessagiHostView {
        let view = SaessagiHostView()
        view.wantsLayer = true
        view.layer?.masksToBounds = false
        let coordinator = context.coordinator
        view.onLayout = { width in coordinator.stage.setLaneWidth(width) }
        return view
    }

    static func dismantleNSView(_ view: SaessagiHostView, coordinator: Coordinator) {
        coordinator.stage.halt()
    }

    func updateNSView(_ view: SaessagiHostView, context: Context) {
        guard let layer = view.layer else { return }
        let stage = context.coordinator.stage
        stage.install(in: layer, startX: startX, link: link)
        stage.setLaneWidth(view.bounds.width)
        stage.update(images: images, size: size, displayScale: displayScale, maxRange: maxRange, isAnimating: isAnimating)
    }
}
#else
import UIKit

/// 레이어를 얹는 빈 뷰. 너비가 정해질 때마다 알려 준다.
final class SaessagiHostView: UIView {
    var onLayout: ((CGFloat) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?(bounds.width)
    }
}

struct SaessagiIdleLayerView: UIViewRepresentable {
    let images: SaessagiIdleImages
    let size: CGFloat
    let displayScale: CGFloat
    let startX: CGFloat
    let link: SaessagiStageLink?
    let maxRange: CGFloat
    let isAnimating: Bool

    final class Coordinator {
        @MainActor lazy var stage = SaessagiIdleStage()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SaessagiHostView {
        let view = SaessagiHostView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.clipsToBounds = false
        let coordinator = context.coordinator
        view.onLayout = { width in coordinator.stage.setLaneWidth(width) }
        return view
    }

    static func dismantleUIView(_ view: SaessagiHostView, coordinator: Coordinator) {
        coordinator.stage.halt()
    }

    func updateUIView(_ view: SaessagiHostView, context: Context) {
        let stage = context.coordinator.stage
        stage.install(in: view.layer, startX: startX, link: link)
        stage.setLaneWidth(view.bounds.width)
        stage.update(images: images, size: size, displayScale: displayScale, maxRange: maxRange, isAnimating: isAnimating)
    }
}
#endif
