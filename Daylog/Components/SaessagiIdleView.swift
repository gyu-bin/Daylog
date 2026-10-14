import QuartzCore
import SwiftUI

/// 기본 모습의 새싹이를 대기 애니메이션용으로 나눈 레이어. 기본 그림(`saessagi_idle`)과 크기·자리가 같다.
/// `Tools/saessagi-layers.swift`가 원본에서 잘라 만든다. 아래 좌표는 그 스크립트의 값과 맞춰야 한다(1024 기준 픽셀, 위에서 아래로).
enum SaessagiIdleLayers {
    static let body = "saessagi_idle_body"
    static let leaf = "saessagi_idle_leaf"
    static let eyes = "saessagi_idle_eyes"

    /// 잎이 도는 중심: 줄기가 머리로 들어가는 자리.
    static let leafPivot = CGPoint(x: 512, y: 288)
    /// 눈이 접히는 중심: 두 눈의 한가운데 높이.
    static let eyeCenter = CGPoint(x: 509.5, y: 569.5)
}

/// 대기 애니메이션의 크기와 박자. 작고 느리게: 눈에 띄되 거슬리지 않게.
enum SaessagiIdleMotion {
    /// 잎이 좌우로 기우는 각도(도).
    static let leafAngle = 2.2
    /// 잎이 한쪽 끝에서 반대쪽 끝까지 가는 시간(초).
    static let leafHalfPeriod = 1.9
    /// 숨을 들이쉴 때 키가 늘어나는 비율. 48pt에서 1pt가 안 된다.
    static let breathStretch = 0.018
    /// 들숨 또는 날숨 한 번의 시간(초).
    static let breathHalfPeriod = 2.4
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

/// 살아 있는 기본 모습: 잎이 바람에 살짝 흔들리고, 가끔 눈을 깜빡이고, 아주 조금 숨을 쉰다.
///
/// 몸·눈·잎 세 장을 겹쳐 그리고 잎과 눈만 따로 움직인다(그림 전체를 흔들지 않는다). 세 장은 기본 그림과 같은 방식으로
/// 미리 줄여 둔 것이라 가만히 있을 때는 한 장짜리 그림과 똑같이 보인다.
/// 움직임 줄이기를 켰거나 레이어를 만들지 못하면 정지 그림을 보여 준다. 화면에서 사라지거나 앱이 뒤로 가면 멈춘다.
///
/// 움직임은 Core Animation에 맡긴다. SwiftUI의 반복 애니메이션으로 돌리면 프레임마다 앱이 다시 계산해서
/// 이 작은 그림 하나에 CPU를 10% 넘게 썼다(실측). 레이어 애니메이션은 앱이 프레임마다 할 일이 없다.
struct SaessagiIdleView: View {
    var size: CGFloat = 48
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    var body: some View {
        if !reduceMotion, let layers = SaessagiIdleImages(size: size, displayScale: displayScale) {
            let side = size + SaessagiRenderer.padding * 2
            SaessagiIdleLayerView(images: layers, size: size, displayScale: displayScale, isAnimating: isVisible && scenePhase == .active)
                // 레이어 그림은 틀보다 사방으로 여백만큼 크다(한 장짜리 그림과 같다).
                .frame(width: side, height: side)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
                .onAppear { isVisible = true }
                .onDisappear { isVisible = false }
        } else {
            SaessagiView(pose: .idle, size: size)
        }
    }
}

/// 미리 줄여 둔 세 레이어.
struct SaessagiIdleImages {
    let body: CGImage
    let eyes: CGImage
    let leaf: CGImage

    @MainActor
    init?(size: CGFloat, displayScale: CGFloat) {
        func layer(_ asset: String) -> CGImage? {
            SaessagiRenderer.image(asset: asset, pose: .idle, size: size, displayScale: displayScale)
        }
        guard let body = layer(SaessagiIdleLayers.body), let eyes = layer(SaessagiIdleLayers.eyes),
              let leaf = layer(SaessagiIdleLayers.leaf) else { return nil }
        self.body = body
        self.eyes = eyes
        self.leaf = leaf
    }
}

/// 세 레이어를 올리고 움직임을 거는 일. macOS와 iOS가 함께 쓴다.
@MainActor
final class SaessagiIdleStage {
    private let container = CALayer()
    private let bodyLayer = CALayer()
    private let eyesLayer = CALayer()
    private let leafLayer = CALayer()
    private var isAnimating = false
    /// 지금 올려 둔 그림의 크기와 배율. 바뀌면 다시 놓는다.
    private var configuration: (size: CGFloat, scale: CGFloat)?

    func install(in host: CALayer) {
        guard container.superlayer !== host else { return }
        host.addSublayer(container)
        for layer in [bodyLayer, eyesLayer, leafLayer] { container.addSublayer(layer) }
    }

    func update(images: SaessagiIdleImages, size: CGFloat, displayScale: CGFloat, isAnimating: Bool) {
        if configuration?.size != size || configuration?.scale != displayScale {
            configuration = (size, displayScale)
            layout(images: images, size: size, displayScale: displayScale)
            // 자리가 바뀌었으니 움직임도 새 기준점으로 다시 건다.
            removeAnimations()
            self.isAnimating = false
        }
        guard isAnimating != self.isAnimating else { return }
        self.isAnimating = isAnimating
        if isAnimating { addAnimations() } else { removeAnimations() }
    }

    private func layout(images: SaessagiIdleImages, size: CGFloat, displayScale: CGFloat) {
        let side = size + SaessagiRenderer.padding * 2
        let content = SaessagiPose.idle.content
        func unit(_ source: CGPoint) -> CGPoint { SaessagiRenderer.unitPoint(of: source, pose: .idle, size: size) }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // 숨쉬기의 기준: 발밑 가운데. 눈과 잎은 각자의 중심.
        place(container, anchor: unit(CGPoint(x: content.midX, y: content.maxY)), side: side)
        place(bodyLayer, anchor: CGPoint(x: 0.5, y: 0.5), side: side)
        place(eyesLayer, anchor: unit(SaessagiIdleLayers.eyeCenter), side: side)
        place(leafLayer, anchor: unit(SaessagiIdleLayers.leafPivot), side: side)
        for (layer, image) in [(bodyLayer, images.body), (eyesLayer, images.eyes), (leafLayer, images.leaf)] {
            layer.contents = image
            layer.contentsScale = displayScale
            layer.contentsGravity = .resize
        }
        CATransaction.commit()
    }

    /// `anchor`(왼쪽 위가 원점인 0…1)를 중심으로 삼아 한 변이 `side`인 레이어를 제자리에 놓는다.
    private func place(_ layer: CALayer, anchor: CGPoint, side: CGFloat) {
        #if os(macOS)
        // AppKit의 레이어는 아래가 원점이다.
        let point = CGPoint(x: anchor.x, y: 1 - anchor.y)
        #else
        let point = anchor
        #endif
        layer.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        layer.anchorPoint = point
        layer.position = CGPoint(x: point.x * side, y: point.y * side)
    }

    private func addAnimations() {
        let ease = CAMediaTimingFunction(name: .easeInEaseOut)

        // 잎: 줄기 밑동을 중심으로 좌우로 살짝.
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

        // 숨쉬기: 발은 제자리, 키만 아주 조금.
        let breath = CABasicAnimation(keyPath: "transform.scale.y")
        breath.fromValue = 1
        breath.toValue = 1 + SaessagiIdleMotion.breathStretch
        breath.duration = SaessagiIdleMotion.breathHalfPeriod
        breath.autoreverses = true
        breath.repeatCount = .infinity
        breath.timingFunction = ease
        container.add(breath, forKey: "breath")

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

    private func removeAnimations() {
        leafLayer.removeAnimation(forKey: "sway")
        container.removeAnimation(forKey: "breath")
        eyesLayer.removeAnimation(forKey: "blink")
    }
}

#if os(macOS)
import AppKit

struct SaessagiIdleLayerView: NSViewRepresentable {
    let images: SaessagiIdleImages
    let size: CGFloat
    let displayScale: CGFloat
    let isAnimating: Bool

    final class Coordinator {
        @MainActor lazy var stage = SaessagiIdleStage()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let layer = view.layer else { return }
        context.coordinator.stage.install(in: layer)
        context.coordinator.stage.update(images: images, size: size, displayScale: displayScale, isAnimating: isAnimating)
    }
}
#else
import UIKit

struct SaessagiIdleLayerView: UIViewRepresentable {
    let images: SaessagiIdleImages
    let size: CGFloat
    let displayScale: CGFloat
    let isAnimating: Bool

    final class Coordinator {
        @MainActor lazy var stage = SaessagiIdleStage()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.stage.install(in: view.layer)
        context.coordinator.stage.update(images: images, size: size, displayScale: displayScale, isAnimating: isAnimating)
    }
}
#endif
