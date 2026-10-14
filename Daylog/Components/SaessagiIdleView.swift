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

/// 부분만 움직이는 모습의 레이어 묶음: 기본 모습(`idle`)과 성장 단계 세 그림.
/// 성장 단계는 기본 모습의 몸·눈·입·발을 그대로 쓰고 잎 레이어만 바꾼다(새싹은 공식 잎, 잎사귀·꽃은 `Tools/saessagi-growth-compose.swift`).
struct SaessagiLayerSet: Equatable, Sendable {
    let body: String
    let leaf: String
    let eyes: String
    var mouth: String?
    var footLeft: String?
    var footRight: String?
    /// 잎이 도는 중심, 눈이 접히는 중심, 몸이 기우는 중심(1024 기준 픽셀, 위에서 아래로).
    let leafPivot: CGPoint
    let eyeCenter: CGPoint
    let hip: CGPoint

    static let idle = SaessagiLayerSet(
        body: SaessagiIdleLayers.body, leaf: SaessagiIdleLayers.leaf, eyes: SaessagiIdleLayers.eyes, mouth: SaessagiIdleLayers.mouth,
        footLeft: SaessagiIdleLayers.footLeft, footRight: SaessagiIdleLayers.footRight,
        leafPivot: SaessagiIdleLayers.leafPivot, eyeCenter: SaessagiIdleLayers.eyeCenter, hip: SaessagiIdleLayers.hip
    )

    /// 성장 단계: 기본 모습에서 잎만 바꾼다. 잎(꽃)은 기본 모습과 같은 줄기 밑동을 중심으로 흔들린다.
    private static func growth(leaf: String) -> SaessagiLayerSet {
        let idle = SaessagiLayerSet.idle
        return SaessagiLayerSet(
            body: idle.body, leaf: leaf, eyes: idle.eyes, mouth: idle.mouth, footLeft: idle.footLeft, footRight: idle.footRight,
            leafPivot: idle.leafPivot, eyeCenter: idle.eyeCenter, hip: idle.hip
        )
    }

    static func of(_ pose: SaessagiPose) -> SaessagiLayerSet? {
        switch pose {
        case .idle: return .idle
        case .growthSprout: return growth(leaf: SaessagiIdleLayers.leaf)
        case .growthLeaf: return growth(leaf: "saessagi_growth_leaf_layer")
        case .growthFlower: return growth(leaf: "saessagi_growth_flower_layer")
        case .happy, .cheer, .rest, .sleep, .welcome: return nil
        }
    }

    var all: [String] { [body, leaf, eyes] + [mouth, footLeft, footRight].compactMap { $0 } }
}

/// 처음 나타날 때 한 번 하는 연출.
enum SaessagiEntrance: Equatable, Sendable {
    /// 머리 위의 잎(꽃)이 작게 돋아나 자란다: 성장 단계가 바뀐 순간.
    case growLeaf
    /// 반갑게 인사: 나타나자마자 한 번 통 뛴다(회고를 열었을 때).
    case hello
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

/// 움직이는 새싹이. 어느 모습이든, 어느 화면이든 이 뷰 하나를 쓴다.
///
/// - 기본 모습(`idle`)은 몸·발·눈·입·잎을 따로 겹쳐 그리고 부분만 움직인다: 잎이 흔들리고, 눈을 깜빡이고, 걷고, 두리번거린다.
/// - 다른 모습(응원·반가움·기쁨·휴식·잠)은 그림 한 장이라 그림 전체를 발밑 기준으로 기울이고, 띄우고, 눌렀다 늘린다
///   (팔다리를 따로 움직이지 않는다).
/// - 얼마나 자주, 어떤 행동을 할지는 `behavior`로 고른다(정하지 않으면 그 모습에 어울리는 기본값).
///
/// 그림은 `SaessagiView`와 같은 방식으로 미리 줄여 둔 것이라 가만히 있을 때는 정지 그림과 똑같이 보인다.
/// 움직임 줄이기를 켰거나 그림을 만들지 못하면 정지 그림을 보여 준다. 화면에서 사라지거나, 스크롤로 밀려 보이지 않거나,
/// 앱이 뒤로 가면 멈춘다. 움직임은 Core Animation에 맡겨서 앱이 프레임마다 할 일이 없다.
struct SaessagiAnimatedView: View {
    let pose: SaessagiPose
    var size: CGFloat = 48
    var behavior: SaessagiBehavior?
    /// 가로로 늘어나 남는 자리를 걸어 다닐 자리로 쓸지(기본 모습에서 걷는 행동이 있을 때).
    var fillsLane = false
    /// 걸어 다니는 거리의 상한(pt).
    var maxRange: CGFloat = 0
    /// 처음 서 있을 자리(왼쪽 끝에서 오른쪽으로 떨어진 거리).
    var startX: CGFloat = 0
    /// 지금 어디에 있는지 물어볼 수 있게 무대를 이어 두는 고리.
    var link: SaessagiStageLink?
    /// 처음 나타날 때 한 번 하는 연출(예: 성장 단계가 바뀌어 잎이 자라난다).
    var entrance: SaessagiEntrance?
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    /// 스크롤로 밀려 화면 밖에 있지 않은가(알 수 없는 OS에서는 늘 참).
    @State private var isOnScreen = true

    var body: some View {
        if !reduceMotion, let rig = SaessagiRig(pose: pose, size: size, displayScale: displayScale) {
            SaessagiStageView(
                rig: rig, size: size, displayScale: displayScale, startX: startX, link: link, maxRange: maxRange,
                behavior: behavior ?? .standard(for: pose), entrance: entrance,
                isAnimating: isVisible && isOnScreen && scenePhase == .active
            )
            .frame(minWidth: size, idealWidth: size, maxWidth: fillsLane ? .infinity : size)
            .frame(height: size)
            .accessibilityHidden(true)
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
            .modifier(SaessagiOnScreen(isOnScreen: $isOnScreen))
        } else {
            SaessagiView(pose: pose, size: size)
        }
    }
}

/// 스크롤 화면 안에서 보이는지를 알려 준다. 그 기능이 없는 OS에서는 아무것도 하지 않는다(늘 보이는 것으로 둔다).
private struct SaessagiOnScreen: ViewModifier {
    @Binding var isOnScreen: Bool

    func body(content: Content) -> some View {
        if #available(macOS 15.0, iOS 18.0, *) {
            content.onScrollVisibilityChange(threshold: 0.05) { isOnScreen = $0 }
        } else {
            content
        }
    }
}

/// 한 모습을 그릴 그림들. 기본 모습은 나뉜 레이어 여섯 장, 성장 단계는 세 장(몸·잎·눈), 그 밖에는 한 장.
struct SaessagiRig {
    let pose: SaessagiPose
    /// 나뉜 레이어의 이름과 중심점. 한 장짜리 모습은 nil.
    let layers: SaessagiLayerSet?
    /// 몸(나뉜 모습) 또는 그림 전체(한 장짜리 모습).
    let body: CGImage
    let eyes: CGImage?
    let mouth: CGImage?
    let leaf: CGImage?
    let footLeft: CGImage?
    let footRight: CGImage?

    /// 발·눈·입·잎이 따로 있는가.
    var isLayered: Bool { leaf != nil }

    @MainActor
    init?(pose: SaessagiPose, size: CGFloat, displayScale: CGFloat) {
        func layer(_ asset: String) -> CGImage? {
            SaessagiRenderer.image(asset: asset, pose: pose, size: size, displayScale: displayScale)
        }
        self.pose = pose
        guard let set = SaessagiLayerSet.of(pose) else {
            guard let whole = SaessagiRenderer.image(pose: pose, size: size, displayScale: displayScale) else { return nil }
            layers = nil
            body = whole
            eyes = nil
            mouth = nil
            leaf = nil
            footLeft = nil
            footRight = nil
            return
        }
        guard let body = layer(set.body), let eyes = layer(set.eyes), let leaf = layer(set.leaf) else { return nil }
        // 입과 발은 따로 있는 모습만 나눠 그린다(성장 단계는 몸에 붙어 있다).
        let mouth = set.mouth.flatMap(layer), footLeft = set.footLeft.flatMap(layer), footRight = set.footRight.flatMap(layer)
        guard (set.mouth == nil || mouth != nil) && (set.footLeft == nil || footLeft != nil) && (set.footRight == nil || footRight != nil)
        else { return nil }
        layers = set
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
    fileprivate weak var stage: SaessagiStage?

    /// 제자리에서 오른쪽으로 떨어진 거리(pt). 걸어 다니는 무대가 없으면 nil.
    func currentOffset() -> CGFloat? {
        stage?.currentOffset()
    }
}

/// 레이어를 올리고 움직임을 거는 일. macOS와 iOS가 함께 쓴다.
///
/// 겹치는 순서와 묶음: 이동·뜀·눌림(`mover`) → 숨쉬기(`breather`) → 두 발, 그 위에 몸통(`torso`: 몸 → 얼굴(입·눈) → 잎).
/// 그림 한 장짜리 모습은 `bodyLayer`에 그림 전체를 올리고 나머지 레이어는 비워 둔다.
@MainActor
final class SaessagiStage {
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
    /// 지금 올려 둔 그림의 모습·크기·배율. 바뀌면 다시 놓는다.
    private var configuration: (pose: SaessagiPose, size: CGFloat, scale: CGFloat)?
    private var isLayered = false
    private var size: CGFloat = 48
    private var behavior = SaessagiBehavior.calm
    /// 걸어 다닐 수 있는 거리(pt): 받은 너비에서 새싹이 한 칸을 뺀 만큼, 상한(`maxRange`)까지.
    private var range: CGFloat = 0
    private var laneWidth: CGFloat = 0
    private var maxRange: CGFloat = 0
    /// 지금 서 있는 자리(왼쪽 끝에서 오른쪽으로 떨어진 거리). 걸으면 바뀐다.
    private var restingX: CGFloat = 0
    private var actions: Task<Void, Never>?
    private var lastAction: SaessagiAction?
    /// 다음에 움직이기 시작할 때 한 번 할 연출.
    private var pendingEntrance: SaessagiEntrance?
    /// 발이 따로 있는가(걷기는 발이 있어야 한다).
    private var hasFeet = false

    #if os(macOS)
    /// AppKit의 레이어는 아래가 원점이다: 위쪽이 +y, 양의 회전이 시계 반대 방향.
    private static let up: CGFloat = 1
    private static let clockwise: CGFloat = -1
    #else
    private static let up: CGFloat = -1
    private static let clockwise: CGFloat = 1
    #endif

    private static let actionKey = "action"

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
        // 자리가 좁아졌으면(창 크기 변경) 그 안으로 들어온다. 행동 중이 아닐 때만.
        if restingX > range + 0.5, !isActing {
            restingX = range
            setModelX(restingX)
        }
    }

    func update(
        rig: SaessagiRig, size: CGFloat, displayScale: CGFloat, maxRange: CGFloat, behavior: SaessagiBehavior,
        entrance: SaessagiEntrance? = nil, isAnimating: Bool
    ) {
        if configuration == nil { pendingEntrance = entrance }
        self.maxRange = maxRange
        let needsRestart = behavior != self.behavior && self.isAnimating
        self.behavior = behavior
        if configuration?.pose != rig.pose || configuration?.size != size || configuration?.scale != displayScale {
            // 그림이 바뀌었으면 움직임을 내리고 새 기준점으로 다시 건다.
            if self.isAnimating { stop() }
            configuration = (rig.pose, size, displayScale)
            self.size = size
            layout(rig: rig, size: size, displayScale: displayScale)
        } else if needsRestart {
            // 움직이는 방식이 바뀌었다(예: 기다리다가 멈춤): 새 박자로 다시 시작한다.
            stop()
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

    /// 뷰가 사라질 때: 움직임과 예약해 둔 행동을 모두 내린다.
    func halt() {
        stop()
    }

    /// 행동이 돌고 있는가.
    private var isActing: Bool {
        mover.animationKeys()?.contains { $0.hasPrefix(Self.actionKey) } ?? false
    }

    private func setModelX(_ x: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mover.setValue(x, forKeyPath: "transform.translation.x")
        CATransaction.commit()
    }

    private func layout(rig: SaessagiRig, size: CGFloat, displayScale: CGFloat) {
        isLayered = rig.isLayered
        hasFeet = rig.footLeft != nil
        let pose = rig.pose
        let side = size + SaessagiRenderer.padding * 2
        let content = pose.content
        func unit(_ source: CGPoint) -> CGPoint { SaessagiRenderer.unitPoint(of: source, pose: pose, size: size) }
        let center = CGPoint(x: 0.5, y: 0.5)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // 눌리고 늘어나는 기준과 숨쉬기의 기준은 발밑 가운데. 몸이 기우는 기준은 다리 사이(한 장짜리 그림은 발밑).
        let feet = unit(CGPoint(x: content.midX, y: content.maxY))
        place(mover, anchor: feet, side: side)
        // 그림은 틀보다 사방으로 여백만큼 크다(정지 그림과 같다).
        mover.position.x -= SaessagiRenderer.padding
        mover.position.y -= SaessagiRenderer.padding
        place(breather, anchor: feet, side: side)
        place(footLeft, anchor: center, side: side)
        place(footRight, anchor: center, side: side)
        place(torso, anchor: rig.layers.map { unit($0.hip) } ?? feet, side: side)
        place(bodyLayer, anchor: center, side: side)
        place(face, anchor: center, side: side)
        place(mouthLayer, anchor: center, side: side)
        place(eyesLayer, anchor: rig.layers.map { unit($0.eyeCenter) } ?? center, side: side)
        place(leafLayer, anchor: rig.layers.map { unit($0.leafPivot) } ?? center, side: side)
        let contents: [(CALayer, CGImage?)] = [
            (footLeft, rig.footLeft), (footRight, rig.footRight), (bodyLayer, rig.body),
            (mouthLayer, rig.mouth), (eyesLayer, rig.eyes), (leafLayer, rig.leaf),
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

    // MARK: - 늘 도는 움직임

    private func start() {
        isAnimating = true
        let ease = CAMediaTimingFunction(name: .easeInEaseOut)

        // 숨쉬기: 발은 제자리, 키만 조금.
        let breath = CABasicAnimation(keyPath: "transform.scale.y")
        breath.fromValue = 1
        breath.toValue = 1 + behavior.breathStretch
        breath.duration = behavior.breathHalfPeriod
        breath.autoreverses = true
        breath.repeatCount = .infinity
        breath.timingFunction = ease
        breather.add(breath, forKey: "breath")

        if isLayered {
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

            // 눈: 정해 둔 박자대로 감았다 뜬다.
            let blink = CAKeyframeAnimation(keyPath: "transform.scale.y")
            let track = SaessagiIdleMotion.blinkTrack
            blink.values = track.values
            blink.keyTimes = track.keyTimes.map { NSNumber(value: $0) }
            blink.duration = track.duration
            blink.repeatCount = .infinity
            blink.calculationMode = .linear
            eyesLayer.add(blink, forKey: "blink")
        }

        if let entrance = pendingEntrance {
            pendingEntrance = nil
            playEntrance(entrance)
        }

        // 가끔 하는 행동. 행동 하나를 걸어 두고 끝날 때까지, 그리고 다음 행동까지 잠든다(한 번에 하나만 돈다).
        actions?.cancel()
        actions = Task { [weak self] in
            var generator = SystemRandomNumberGenerator()
            var delay = Self.debugRest ?? self?.behavior.firstRest ?? 2
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let self else { return }
                let action = self.debugAction ?? self.behavior.next(after: self.lastAction, using: &generator)
                self.lastAction = action
                let duration = self.play(action, using: &generator)
                try? await Task.sleep(for: .seconds(duration))
                delay = Self.debugRest ?? Double.random(in: self.behavior.rest, using: &generator)
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
            for key in layer.animationKeys() ?? [] where key.hasPrefix(Self.actionKey) { layer.removeAnimation(forKey: key) }
        }
        setModelX(restingX)
    }

    /// 처음 나타날 때의 연출. 늘 도는 움직임 위에 더한다.
    private func playEntrance(_ entrance: SaessagiEntrance) {
        switch entrance {
        case .growLeaf:
            guard isLayered else { return }
            // 머리 위의 잎(꽃)이 줄기 밑동에서 작게 돋아나 조금 넘치게 자랐다가 자리를 잡는다.
            let grow = CAKeyframeAnimation(keyPath: "transform.scale")
            grow.values = [0.12, 0.12, 1.14, 0.95, 1.03, 1]
            grow.keyTimes = [0, 0.18, 0.62, 0.78, 0.9, 1]
            grow.duration = 1.4
            grow.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 5)
            leafLayer.add(grow, forKey: "\(Self.actionKey).grow")
            let appear = CAKeyframeAnimation(keyPath: "opacity")
            appear.values = [0, 0, 1]
            appear.keyTimes = [0, 0.15, 0.3]
            appear.duration = 1.4
            leafLayer.add(appear, forKey: "\(Self.actionKey).appear")
        case .hello:
            var generator = SystemRandomNumberGenerator()
            _ = play(.bounce, using: &generator)
        }
    }

    // MARK: - 가끔 하는 행동

    /// 행동 하나를 시작하고 걸리는 시간(초)을 돌려준다. 하지 않으면 0.
    private func play(_ action: SaessagiAction, using generator: inout some RandomNumberGenerator) -> Double {
        // 나뉜 레이어가 있어야 하는 행동은 그림 한 장짜리 모습에서는 하지 않는다.
        guard (isLayered && (hasFeet || action != .walk)) || !action.needsLayers,
              let plan = SaessagiMotionPlan.make(action, at: restingX, range: range, size: size, using: &generator)
        else { return 0 }
        // 끝나면 걸어간 자리에 서 있다.
        restingX = plan.finalX
        setModelX(restingX)
        let degrees = Double.pi / 180 * Self.clockwise
        // 몸의 이동과 발의 좌우 위치는 곧게 이어야 디딘 발이 땅에서 미끄러지지 않는다.
        add(plan.moverX, to: mover, keyPath: "transform.translation.x", plan: plan, eased: false)
        add(plan.bob, to: mover, keyPath: "transform.translation.y", scale: Self.up, plan: plan)
        add(plan.squashX, to: mover, keyPath: "transform.scale.x", plan: plan)
        add(plan.squashY, to: mover, keyPath: "transform.scale.y", plan: plan)
        add(plan.rock, to: torso, keyPath: "transform.rotation.z", scale: degrees, plan: plan)
        guard isLayered else { return plan.duration }
        add(plan.footLeftX, to: footLeft, keyPath: "transform.translation.x", plan: plan, eased: false)
        add(plan.footLeftLift, to: footLeft, keyPath: "transform.translation.y", scale: Self.up, plan: plan)
        add(plan.footRightX, to: footRight, keyPath: "transform.translation.x", plan: plan, eased: false)
        add(plan.footRightLift, to: footRight, keyPath: "transform.translation.y", scale: Self.up, plan: plan)
        // 잎은 늘 도는 흔들림 위에 행동의 흔들림을 더한다.
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
        layer.add(animation, forKey: "\(Self.actionKey).\(keyPath)")
    }

    /// 화면 검증용: `-DaylogDebugSaessagiAction hop`처럼 주면 기본 모습의 새싹이가 그 행동만 한다
    /// (walk, lookAround, hop, doze. Debug 빌드만).
    private var debugAction: SaessagiAction? {
        #if DEBUG
        guard isLayered else { return nil }
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

struct SaessagiStageView: NSViewRepresentable {
    let rig: SaessagiRig
    let size: CGFloat
    let displayScale: CGFloat
    let startX: CGFloat
    let link: SaessagiStageLink?
    let maxRange: CGFloat
    let behavior: SaessagiBehavior
    var entrance: SaessagiEntrance?
    let isAnimating: Bool

    final class Coordinator {
        @MainActor lazy var stage = SaessagiStage()
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
        stage.update(
            rig: rig, size: size, displayScale: displayScale, maxRange: maxRange, behavior: behavior, entrance: entrance,
            isAnimating: isAnimating
        )
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

struct SaessagiStageView: UIViewRepresentable {
    let rig: SaessagiRig
    let size: CGFloat
    let displayScale: CGFloat
    let startX: CGFloat
    let link: SaessagiStageLink?
    let maxRange: CGFloat
    let behavior: SaessagiBehavior
    var entrance: SaessagiEntrance?
    let isAnimating: Bool

    final class Coordinator {
        @MainActor lazy var stage = SaessagiStage()
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
        stage.update(
            rig: rig, size: size, displayScale: displayScale, maxRange: maxRange, behavior: behavior, entrance: entrance,
            isAnimating: isAnimating
        )
    }
}
#endif
