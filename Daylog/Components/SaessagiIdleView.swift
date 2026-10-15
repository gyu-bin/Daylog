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
    /// 날개(피오 시범): 왼쪽·오른쪽 날개와 날개가 몸에 드리운 그림자, 날개가 도는 중심(어깨). 새싹이에는 없다.
    var wingLeft: String?
    var wingRight: String?
    var wingShadowLeft: String?
    var wingShadowRight: String?
    var wingLeftPivot: CGPoint = .zero
    var wingRightPivot: CGPoint = .zero
    /// 발을 굴리는 중심(피오). 없으면 그림 가운데(새싹이는 발을 굴리지 않는다).
    var footLeftPivot: CGPoint?
    var footRightPivot: CGPoint?
    /// 눈 위에 겹치는 눈꺼풀(감은 눈·웃는 눈·졸린 눈). 있으면 깜빡임을 눈 접기 대신 눈꺼풀로 한다.
    var lidClosed: String?
    var lidHappy: String?
    var lidSleepy: String?

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
        // 피오 시범: 기본 모습은 부위로 나눈 피오, 그 밖의 모습은 한 장짜리 마스터.
        if PioTrial.art(for: pose) != nil { return pose == .idle ? PioTrial.rigLayers : nil }
        switch pose {
        case .idle: return .idle
        case .growthSprout: return growth(leaf: SaessagiIdleLayers.leaf)
        case .growthLeaf: return growth(leaf: "saessagi_growth_leaf_layer")
        case .growthFlower: return growth(leaf: "saessagi_growth_flower_layer")
        case .happy, .cheer, .rest, .sleep, .welcome: return nil
        }
    }

    var all: [String] {
        [body, leaf, eyes] + [mouth, footLeft, footRight, wingLeft, wingRight, wingShadowLeft, wingShadowRight, lidClosed, lidHappy, lidSleepy]
            .compactMap { $0 }
    }
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
    /// 걸을 자리 끝에서 잘라 내 숨바꼭질을 할 수 있게 할지(머리말의 새싹이).
    var clipsLaneEnd = false
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
                behavior: behavior ?? .standard(for: pose), entrance: entrance, clipsLaneEnd: clipsLaneEnd,
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
    /// 날개·날개 그림자·눈꺼풀(피오 시범). 없으면 nil.
    var wingLeft: CGImage?
    var wingRight: CGImage?
    var wingShadowLeft: CGImage?
    var wingShadowRight: CGImage?
    var lidClosed: CGImage?
    var lidHappy: CGImage?
    var lidSleepy: CGImage?

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
        wingLeft = set.wingLeft.flatMap(layer)
        wingRight = set.wingRight.flatMap(layer)
        wingShadowLeft = set.wingShadowLeft.flatMap(layer)
        wingShadowRight = set.wingShadowRight.flatMap(layer)
        lidClosed = set.lidClosed.flatMap(layer)
        lidHappy = set.lidHappy.flatMap(layer)
        lidSleepy = set.lidSleepy.flatMap(layer)
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
    /// 날개(어깨를 중심으로 돈다): 늘 하는 살랑임(`wingSway…`) 안에 행동의 움직임(`wing…`)과 그림자.
    private let wingSwayLeft = CALayer(), wingSwayRight = CALayer()
    private let wingLeftLayer = CALayer(), wingRightLayer = CALayer()
    private let wingShadowLeftLayer = CALayer(), wingShadowRightLayer = CALayer()
    private let wingImageLeft = CALayer(), wingImageRight = CALayer()
    /// 눈꺼풀: 평소에는 보이지 않고, 깜빡이거나 표정을 지을 때 눈 위에 나타난다.
    private let lidClosedLayer = CALayer(), lidHappyLayer = CALayer(), lidSleepyLayer = CALayer()
    private var hasWings = false
    private var hasLids = false
    private var isAnimating = false
    /// 지금 올려 둔 그림의 모습·크기·배율. 바뀌면 다시 놓는다.
    private var configuration: (pose: SaessagiPose, size: CGFloat, scale: CGFloat)?
    private var isLayered = false
    private var size: CGFloat = 48
    private var behavior = SaessagiBehavior.calm
    /// 걸어 다닐 수 있는 거리(pt): 받은 너비에서 새싹이 한 칸을 뺀 만큼, 상한(`maxRange`)까지.
    private var range: CGFloat = 0
    private var laneWidth: CGFloat = 0
    /// 레이어를 얹은 뷰의 레이어와, 자리 끝에서 잘라 내는 가리개.
    private weak var host: CALayer?
    private let laneMask = CAGradientLayer()
    /// 머리말에서 걸을 자리 끝과 첫 단추 사이의 빈칸(HStack 간격 8pt). 숨을 때는 단추 바로 앞(1pt 남김)까지 보이고, 그 끝에서
    /// `laneFeather`만큼 흐려지며 사라진다: 빈 곳에서 칼로 자른 듯 끊기지 않고 단추 뒤로 들어가는 것처럼 보인다.
    static let laneEndGap: CGFloat = 7
    static let laneFeather: CGFloat = 10
    private var clipsLaneEnd = false
    private var maxRange: CGFloat = 0
    /// 지금 서 있는 자리(왼쪽 끝에서 오른쪽으로 떨어진 거리). 걸으면 바뀐다.
    private var restingX: CGFloat = 0
    private var actions: Task<Void, Never>?
    private var lastAction: SaessagiAction?
    /// 머리말에서 다음 행동의 순서를 정한다(`behavior.isDirected`일 때). 움직이기 시작할 때마다 처음부터.
    private var director = SaessagiDirector()
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
        self.host = host
        host.addSublayer(mover)
        mover.addSublayer(breather)
        for layer in [footLeft, footRight, torso] { breather.addSublayer(layer) }
        for layer in [bodyLayer, wingSwayLeft, wingSwayRight, face, leafLayer] { torso.addSublayer(layer) }
        for layer in [mouthLayer, eyesLayer, lidClosedLayer, lidHappyLayer, lidSleepyLayer] { face.addSublayer(layer) }
        wingSwayLeft.addSublayer(wingLeftLayer)
        wingSwayRight.addSublayer(wingRightLayer)
        for layer in [wingShadowLeftLayer, wingImageLeft] { wingLeftLayer.addSublayer(layer) }
        for layer in [wingShadowRightLayer, wingImageRight] { wingRightLayer.addSublayer(layer) }
        restingX = max(startX, 0)
    }

    /// 자리 끝에서 새싹이를 잘라 낼지(숨바꼭질을 할 수 있는 자리). 세로로는 자르지 않는다(뛰어도 머리가 잘리지 않는다).
    func setClipsLaneEnd(_ clips: Bool) {
        guard clips != clipsLaneEnd else { return }
        clipsLaneEnd = clips
        updateLaneMask()
    }

    private func updateLaneMask() {
        guard let host else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if clipsLaneEnd, laneWidth > 0 {
            // 왼쪽(글자 쪽)으로는 가지 않으니 넉넉히 두고, 오른쪽은 첫 단추 바로 앞에서 흐려지며 잘라 낸다. 세로로는 자르지 않는다.
            let left = -size * 2, right = laneWidth + Self.laneEndGap
            let width = right - left
            laneMask.frame = CGRect(x: left, y: -size * 3, width: width, height: size * 7)
            laneMask.colors = [CGColor(gray: 0, alpha: 1), CGColor(gray: 0, alpha: 1), CGColor(gray: 0, alpha: 0)]
            let fade = Double((width - Self.laneFeather) / width)
            laneMask.locations = [0, NSNumber(value: fade), 1]
            laneMask.startPoint = CGPoint(x: 0, y: 0.5)
            laneMask.endPoint = CGPoint(x: 1, y: 0.5)
            if host.mask !== laneMask { host.mask = laneMask }
        } else if host.mask === laneMask {
            host.mask = nil
        }
        CATransaction.commit()
    }

    /// 걸어 다닐 자리의 너비가 정해졌다(레이아웃 때마다). 머리말에서는 제목 끝에서 첫 단추 앞까지의 실제 빈자리다.
    func setLaneWidth(_ width: CGFloat) {
        let changed = width != laneWidth
        laneWidth = width
        if changed { updateLaneMask() }
        let oldRange = range
        range = min(max(width - size, 0), maxRange)
        // 숨바꼭질 중에 자리 끝이 옮겨 갔으면(창 크기 변경) 숨을 곳이 사라졌다: 빈 곳에서 숨지 않게 그 자리에서 멈춘다.
        if abs(range - oldRange) > 0.5, lastAction == .peek, isActing {
            let now = currentOffset()
            removeActionAnimations()
            restingX = min(max(now, 0), range)
            setModelX(restingX)
        }
        // 자리가 좁아졌으면(창 크기 변경) 그 안으로 들어온다. 걷던 중이면 걷기를 멈추고 지금 자리에서 들어온다
        // (잘라 내는 가리개가 있어 단추 위로는 그려지지 않지만, 다음 행동은 새 자리 안에서 시작해야 한다).
        if restingX > range + 0.5 {
            if isActing {
                let now = currentOffset()
                removeActionAnimations()
                restingX = min(max(now, 0), range)
            } else {
                restingX = range
            }
            setModelX(restingX)
        }
        if changed || oldRange != range { logLane() }
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
            updateLaneMask()
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
        hasWings = rig.wingLeft != nil && rig.wingRight != nil
        hasLids = rig.lidClosed != nil
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
        place(footLeft, anchor: rig.layers?.footLeftPivot.map(unit) ?? center, side: side)
        place(footRight, anchor: rig.layers?.footRightPivot.map(unit) ?? center, side: side)
        place(torso, anchor: rig.layers.map { unit($0.hip) } ?? feet, side: side)
        place(bodyLayer, anchor: center, side: side)
        place(face, anchor: center, side: side)
        place(mouthLayer, anchor: center, side: side)
        place(eyesLayer, anchor: rig.layers.map { unit($0.eyeCenter) } ?? center, side: side)
        place(leafLayer, anchor: rig.layers.map { unit($0.leafPivot) } ?? center, side: side)
        let wingLeftAnchor = rig.layers.map { unit($0.wingLeftPivot) } ?? center
        let wingRightAnchor = rig.layers.map { unit($0.wingRightPivot) } ?? center
        for layer in [wingSwayLeft, wingLeftLayer] { place(layer, anchor: wingLeftAnchor, side: side) }
        for layer in [wingSwayRight, wingRightLayer] { place(layer, anchor: wingRightAnchor, side: side) }
        // 그림자는 날개 안에서 날개와 같은 자리(날개보다 아래에 그린다)
        for layer in [wingShadowLeftLayer, wingShadowRightLayer, wingImageLeft, wingImageRight, lidClosedLayer, lidHappyLayer, lidSleepyLayer] {
            place(layer, anchor: center, side: side)
        }
        for layer in [lidClosedLayer, lidHappyLayer, lidSleepyLayer] { layer.opacity = 0 }
        let contents: [(CALayer, CGImage?)] = [
            (footLeft, rig.footLeft), (footRight, rig.footRight), (bodyLayer, rig.body),
            (mouthLayer, rig.mouth), (eyesLayer, rig.eyes), (leafLayer, rig.leaf),
            (wingShadowLeftLayer, rig.wingShadowLeft), (wingShadowRightLayer, rig.wingShadowRight),
            (wingImageLeft, rig.wingLeft), (wingImageRight, rig.wingRight),
            (lidClosedLayer, rig.lidClosed), (lidHappyLayer, rig.lidHappy), (lidSleepyLayer, rig.lidSleepy),
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
            if hasLids {
                // 눈꺼풀이 있으면: 눈은 조금만 접히고, 같은 박자로 감은 눈꺼풀이 나타났다 사라진다(선이 아니라 둥근 얼굴 위의 눈매).
                blink.values = track.values.map { Self.lidEyeScale($0) }
                // 눈꺼풀은 서서히 겹치면 반쯤 비친 눈이 회색으로 보인다: 눈이 감기는 순간 한 번에 덮었다가 뜨는 순간 걷는다.
                let lid = Self.lidSwitch(duration: track.duration, threshold: 0.75) { time in
                    var value = track.values[0]
                    for index in 1..<track.keyTimes.count where time / track.duration <= track.keyTimes[index] {
                        let t0 = track.keyTimes[index - 1], t1 = track.keyTimes[index]
                        let f = t1 > t0 ? (time / track.duration - t0) / (t1 - t0) : 1
                        value = track.values[index - 1] + (track.values[index] - track.values[index - 1]) * f
                        break
                    }
                    return value
                }
                lid.repeatCount = .infinity
                lidClosedLayer.add(lid, forKey: "blink")
            }
            eyesLayer.add(blink, forKey: "blink")
        }
        if hasWings {
            // 날개: 어깨를 중심으로 아주 작게, 고르지 않게 들썩인다(숨에 맞춰 살짝, 가끔 조금 더). 양쪽이 어긋난다.
            for (layer, sign, offset) in [(wingSwayLeft, 1.0, 0.0), (wingSwayRight, -1.0, 1.3)] {
                let sway = CAKeyframeAnimation(keyPath: "transform.rotation.z")
                let values = [0.0, 2.2, 0.8, 3.4, 1.2, 0.3, 2.6, 0.9, 0.0]
                sway.values = values.map { $0 * Double.pi / 180 * Self.clockwise * sign }
                sway.keyTimes = [0, 0.12, 0.26, 0.4, 0.55, 0.66, 0.8, 0.9, 1].map { NSNumber(value: $0) }
                sway.timingFunctions = Array(repeating: ease, count: values.count - 1)
                sway.duration = 4.6
                sway.repeatCount = .infinity
                sway.timeOffset = offset
                layer.add(sway, forKey: "sway")
            }
        }

        if let entrance = pendingEntrance {
            pendingEntrance = nil
            playEntrance(entrance)
        }

        // 가끔 하는 행동. 행동 하나를 걸어 두고 끝날 때까지, 그리고 다음 행동까지 잠든다(한 번에 하나만 돈다).
        // 다시 시작하면 앞의 순서를 지우고 새로 돈다(타이머가 겹쳐 쌓이지 않는다).
        actions?.cancel()
        director = SaessagiDirector()
        actions = Task { [weak self] in
            var generator = SystemRandomNumberGenerator()
            var delay = Self.debugRest ?? self?.behavior.firstRest ?? 2
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let self else { return }
                let action = self.nextAction(using: &generator)
                self.lastAction = action
                let duration = self.play(action, using: &generator)
                try? await Task.sleep(for: .seconds(duration))
                delay = Self.debugRest ?? self.pause(after: action, using: &generator)
            }
        }
    }

    private func nextAction(using generator: inout some RandomNumberGenerator) -> SaessagiAction {
        if let debugAction { return debugAction }
        guard behavior.isDirected else { return behavior.next(after: lastAction, using: &generator) }
        // 날개가 있으면(피오 시범): 처음 나타날 때 날개로 인사하고, 제자리 동작에 퍼덕이기·인사를 더한다.
        if hasWings, !PioTrial.hasWaved {
            PioTrial.hasWaved = true
            return .wave
        }
        return director.next(
            x: restingX, range: range, size: size, canPeek: canPeek,
            flourishes: hasWings ? PioTrial.flourishes(adding: behavior.choices) : behavior.choices, using: &generator
        )
    }

    /// 다음 행동까지 쉬는 시간. 머리말의 쉬기 박자에서는 조금 더 오래 가만히 있는다.
    private func pause(after action: SaessagiAction, using generator: inout some RandomNumberGenerator) -> Double {
        let span = behavior.isDirected && action == .stay ? SaessagiDirector.restPause : behavior.rest
        return Double.random(in: span, using: &generator)
    }

    /// 숨바꼭질을 할 수 있는가: 자리 끝에서 새싹이만 잘라 내고, 걸을 자리가 실제 빈자리 전체일 때(상한에 걸리지 않았을 때).
    /// 그렇지 않으면 숨지 못하고 머리말 밖으로 걸어 나간다.
    private var canPeek: Bool {
        clipsLaneEnd && laneWidth > 0 && range >= laneWidth - size - 0.5
    }

    /// 움직임을 내리고 서 있던 자리에 가만히 선 모습으로 돌아간다.
    private func stop() {
        isAnimating = false
        actions?.cancel()
        actions = nil
        leafLayer.removeAnimation(forKey: "sway")
        breather.removeAnimation(forKey: "breath")
        eyesLayer.removeAnimation(forKey: "blink")
        lidClosedLayer.removeAnimation(forKey: "blink")
        wingSwayLeft.removeAnimation(forKey: "sway")
        wingSwayRight.removeAnimation(forKey: "sway")
        removeActionAnimations()
        setModelX(restingX)
    }

    private func removeActionAnimations() {
        for layer in [mover, footLeft, footRight, torso, bodyLayer, face, eyesLayer, leafLayer, wingLeftLayer, wingRightLayer,
                      wingImageLeft, wingImageRight,
                      wingShadowLeftLayer, wingShadowRightLayer, lidClosedLayer, lidHappyLayer, lidSleepyLayer] {
            for key in layer.animationKeys() ?? [] where key.hasPrefix(Self.actionKey) { layer.removeAnimation(forKey: key) }
        }
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
    private func play(_ requested: SaessagiAction, using generator: inout some RandomNumberGenerator) -> Double {
        // 피오 시범(한 장짜리 그림): 레이어가 있어야 하는 제자리 동작은 비슷한 몸 전체 동작으로 바꾸고, 걷기는 몸 전체로 한다.
        let walksWholeBody = !isLayered && PioTrial.isEnabled
        let action = walksWholeBody ? PioTrial.wholeImageSubstitute(for: requested) : requested
        // 걸을 자리가 줄어든 뒤라면 그 안에서 시작한다.
        if restingX > range {
            restingX = range
            setModelX(restingX)
        }
        // 숨바꼭질은 자리 끝에서 잘라 낼 때만 한다(그렇지 않으면 숨지 못하고 머리말 밖으로 걸어 나간다).
        // 나뉜 레이어가 있어야 하는 행동은 그림 한 장짜리 모습에서는 하지 않는다.
        guard action != .peek || canPeek,
              (isLayered && (hasFeet || !action.travels)) || !action.needsLayers || (walksWholeBody && action.travels),
              let plan = SaessagiMotionPlan.make(
                  action, at: restingX, range: range, size: size, style: hasWings ? .pio : .standard, using: &generator
              )
        else {
            log(action, plan: nil)
            return 0
        }
        log(action, plan: plan)
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
        if walksWholeBody, action.travels { face(along: plan) }
        guard isLayered else { return plan.duration }
        add(plan.footLeftX, to: footLeft, keyPath: "transform.translation.x", plan: plan, eased: false)
        add(plan.footLeftLift, to: footLeft, keyPath: "transform.translation.y", scale: Self.up, plan: plan)
        add(plan.footRightX, to: footRight, keyPath: "transform.translation.x", plan: plan, eased: false)
        add(plan.footRightLift, to: footRight, keyPath: "transform.translation.y", scale: Self.up, plan: plan)
        add(plan.footLeftTilt, to: footLeft, keyPath: "transform.rotation.z", scale: degrees, plan: plan)
        add(plan.footRightTilt, to: footRight, keyPath: "transform.rotation.z", scale: degrees, plan: plan)
        // 잎은 늘 도는 흔들림 위에 행동의 흔들림을 더한다.
        add(plan.leaf, to: leafLayer, keyPath: "transform.rotation.z", scale: degrees, plan: plan, additive: true)
        // 피오(눈꺼풀이 있는 리그)는 부리가 몸에 붙어 있어 눈만 옆으로 옮기면 얼굴이 어긋나 보인다: 눈을 옮기지 않는다.
        if !hasLids { add(plan.face, to: face, keyPath: "transform.translation.x", plan: plan) }
        // 눈은 행동이 도는 동안 평소의 깜빡임 대신 이 값을 따른다(나중에 건 애니메이션이 이긴다).
        add(plan.eyes, to: eyesLayer, keyPath: "transform.scale.y", plan: plan)
        if hasWings {
            // 왼쪽 날개는 들면 시계 방향, 오른쪽은 반대. 그림자는 날개가 몸에서 떨어질수록 옅어진다.
            // 몸 쪽으로는 3도 넘게 접지 않는다(몸통 안으로 파고들지 않게).
            let left = plan.wingLeft.mapped { max($0, -3) }, right = plan.wingRight.mapped { max($0, -3) }
            add(left, to: wingLeftLayer, keyPath: "transform.rotation.z", scale: degrees, plan: plan)
            add(right, to: wingRightLayer, keyPath: "transform.rotation.z", scale: -degrees, plan: plan)
            // 들어 올린 날개는 앞뒤로 기울어 길이가 조금 짧고 넓어 보인다(그림을 비틀지 않고 원근만 흉내 낸다).
            for (track, image) in [(left, wingImageLeft), (right, wingImageRight)] {
                add(track.mapped { 1 - 0.1 * min(max($0, 0), 60) / 60 }, to: image, keyPath: "transform.scale.y", plan: plan)
                add(track.mapped { 1 + 0.04 * min(max($0, 0), 60) / 60 }, to: image, keyPath: "transform.scale.x", plan: plan)
            }
            add(plan.wingLeft.mapped(Self.shadowOpacity), to: wingShadowLeftLayer, keyPath: "opacity", plan: plan)
            add(plan.wingRight.mapped(Self.shadowOpacity), to: wingShadowRightLayer, keyPath: "opacity", plan: plan)
        }
        if hasLids, !plan.eyes.isConstant {
            // 눈을 감는 동작은 눈꺼풀로: 잎을 털 때는 웃는 눈, 졸 때는 졸린 눈, 그 밖에는 감은 눈.
            let lid = action == .leafShake || action == .flap ? lidHappyLayer : (action == .doze ? lidSleepyLayer : lidClosedLayer)
            let threshold = action == .leafShake || action == .flap ? 0.8 : 0.75
            let switching = Self.lidSwitch(duration: plan.duration, threshold: threshold) { plan.eyes.value(at: $0) }
            lid.add(switching, forKey: "\(Self.actionKey).lid")
            add(plan.eyes.mapped { Self.lidEyeScale($0) }, to: eyesLayer, keyPath: "transform.scale.y", plan: plan)
        }
        return plan.duration
    }

    /// 한 장짜리 그림이 걸을 때 가는 쪽을 보게 좌우를 뒤집는다(그림은 오른쪽을 보고 있다). 멈추면 마지막으로 간 쪽을 본 채로 있다.
    private func face(along plan: SaessagiMotionPlan) {
        let xs = plan.moverX.values, times = plan.moverX.times
        guard xs.count > 1, plan.duration > 0 else { return }
        var facing = (bodyLayer.value(forKeyPath: "transform.scale.x") as? Double) ?? 1
        var values: [Double] = []
        for index in 0..<(xs.count - 1) {
            let step = xs[index + 1] - xs[index]
            if abs(step) > 0.01 { facing = step > 0 ? 1 : -1 }
            values.append(facing)
        }
        let animation = CAKeyframeAnimation(keyPath: "transform.scale.x")
        animation.values = values
        // 한 칸씩 끊어 바꾼다: 시각은 값보다 하나 많다(처음 0, 끝 1).
        var keyTimes = times.map { NSNumber(value: min($0 / plan.duration, 1)) }
        keyTimes[keyTimes.count - 1] = 1
        animation.keyTimes = keyTimes
        animation.calculationMode = .discrete
        animation.duration = plan.duration
        bodyLayer.add(animation, forKey: "\(Self.actionKey).facing")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bodyLayer.setValue(facing, forKeyPath: "transform.scale.x")
        CATransaction.commit()
    }

    /// 눈꺼풀이 있을 때 눈 자체의 세로 배율: 거의 접지 않는다(눈꺼풀이 덮는다).
    private static func lidEyeScale(_ scale: Double) -> Double { scale >= 1 ? scale : 0.85 + 0.15 * scale }

    /// 눈꺼풀을 켜고 끄는 애니메이션: 눈의 세로 배율(`eye(time)`)이 `threshold`보다 작은 동안 보인다. 1/60초마다 본다.
    private static func lidSwitch(duration: Double, threshold: Double, eye: (Double) -> Double) -> CAKeyframeAnimation {
        let count = max(2, Int((duration * 60).rounded()))
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = (0..<count).map { eye(duration * (Double($0) + 0.5) / Double(count)) < threshold ? 1.0 : 0.0 }
        animation.keyTimes = (0...count).map { NSNumber(value: Double($0) / Double(count)) }
        animation.calculationMode = .discrete
        animation.duration = duration
        return animation
    }

    /// 날개가 든 각도에 따른 날개 그림자의 불투명도.
    private static func shadowOpacity(_ angle: Double) -> Double { max(0, 1 - abs(angle) / 18) }

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
    /// (walk, stroll, dash, peek, lookAround, hop, bigHop, doubleHop, leafShake, doze. Debug 빌드만).
    private var debugAction: SaessagiAction? {
        #if DEBUG
        guard isLayered else { return nil }
        switch UserDefaults.standard.string(forKey: "DaylogDebugSaessagiAction") {
        case "walk": return .walk
        case "lookAround": return .lookAround
        case "hop": return .hop
        case "doze": return .doze
        case "stroll": return .stroll
        case "dash": return .dash
        case "peek": return .peek
        case "bigHop": return .bigHop
        case "doubleHop": return .doubleHop
        case "leafShake": return .leafShake
        case "flap": return .flap
        case "wave": return .wave
        default: return nil
        }
        #else
        return nil
        #endif
    }

    /// 화면 검증용: `-DaylogDebugSaessagiLog YES`면 머리말 새싹이의 걸을 자리와 행동마다의 좌표를 표준 오류에 적는다(Debug 빌드만).
    /// 좌표는 걸을 자리의 왼쪽 끝에서 잰 pt이고, 자리의 창 안 위치는 `TodaySaessagi`가 따로 적는다.
    static var logsEnabled: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "DaylogDebugSaessagiLog")
        #else
        false
        #endif
    }

    private func logLane() {
        #if DEBUG
        guard Self.logsEnabled, behavior.isDirected else { return }
        Self.write(String(
            format: "lane width=%.1f range=%.1f size=%.0f clips=%@ canPeek=%@", laneWidth, range, size,
            clipsLaneEnd ? "Y" : "N", canPeek ? "Y" : "N"
        ))
        #endif
    }

    private func log(_ action: SaessagiAction, plan: SaessagiMotionPlan?) {
        #if DEBUG
        guard Self.logsEnabled, behavior.isDirected else { return }
        guard let plan else {
            Self.write("action=\(action) skipped x=\(String(format: "%.1f", restingX)) range=\(String(format: "%.1f", range))")
            return
        }
        // 몸(그림의 투명한 여백 제외)이 차지한 가장 왼쪽·오른쪽. 자리 끝 + `laneEndGap` 너머는 잘려 보이지 않는다.
        let pose = configuration?.pose ?? .idle
        let inset = (1 - pose.content.width / pose.fitted) / 2 * size
        let low = plan.moverX.values.min() ?? restingX, high = plan.moverX.values.max() ?? restingX
        Self.write(String(
            format: "action=%@ from=%.1f to=%.1f min=%.1f max=%.1f dur=%.2f steps=%d lane=%.1f range=%.1f body=%.1f...%.1f visibleMax=%.1f",
            "\(action)", restingX, plan.finalX, low, high, plan.duration, plan.steps, laneWidth, range,
            low + inset, high + size - inset, min(high + size - inset, laneWidth + Self.laneEndGap)
        ))
        #endif
    }

    static func write(_ line: String) {
        #if DEBUG
        let stamp = String(format: "%.2f", CACurrentMediaTime())
        FileHandle.standardError.write(Data("[Saessagi \(stamp)] \(line)\n".utf8))
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
    var clipsLaneEnd = false
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
        stage.setClipsLaneEnd(clipsLaneEnd)
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
    var clipsLaneEnd = false
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
        stage.setClipsLaneEnd(clipsLaneEnd)
        stage.setLaneWidth(view.bounds.width)
        stage.update(
            rig: rig, size: size, displayScale: displayScale, maxRange: maxRange, behavior: behavior, entrance: entrance,
            isAnimating: isAnimating
        )
    }
}
#endif
