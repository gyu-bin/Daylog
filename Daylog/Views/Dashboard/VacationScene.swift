import QuartzCore
import SwiftUI

/// 휴가 화면의 배경: 파스텔 하늘, 햇빛, 언덕, 그리고 천천히 흐르는 구름과 흔들리는 나뭇잎.
///
/// 하늘·햇빛·언덕은 가만히 있는 SwiftUI 도형이고, 움직이는 구름과 잎만 Core Animation 레이어다
/// (SwiftUI의 반복 애니메이션은 프레임마다 앱이 다시 계산해 CPU를 쓴다. 새싹이와 같은 이유).
/// 움직임 줄이기를 켰거나, 화면에서 사라지거나, 앱이 뒤로 가면 움직임을 멈춘다.
struct VacationSceneBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    var body: some View {
        let isDark = colorScheme == .dark
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(colors: VacationPalette.sky(isDark: isDark), startPoint: .top, endPoint: .bottom)
                // 햇빛: 오른쪽 위에서 번진다.
                RadialGradient(
                    colors: [VacationPalette.sun(isDark: isDark), .clear], center: UnitPoint(x: 0.86, y: 0.08),
                    startRadius: 0, endRadius: max(size.width, size.height) * 0.55
                )
                // 언덕: 먼 것(옅게)과 가까운 것.
                Ellipse()
                    .fill(VacationPalette.farHill(isDark: isDark))
                    .frame(width: size.width * 1.5, height: size.height * 0.42)
                    .position(x: size.width * 0.2, y: size.height * 1.03)
                Ellipse()
                    .fill(VacationPalette.nearHill(isDark: isDark))
                    .frame(width: size.width * 1.7, height: size.height * 0.4)
                    .position(x: size.width * 0.82, y: size.height * 1.08)
                VacationSceneLayerView(isDark: isDark, isAnimating: isVisible && !reduceMotion && scenePhase == .active)
            }
        }
        .accessibilityHidden(true)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

/// 휴가 화면의 색. 밝은 모드는 낮의 파스텔, 어두운 모드는 같은 풍경의 저녁.
enum VacationPalette {
    private static func rgb(_ hex: UInt32, _ opacity: Double = 1) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    static func sky(isDark: Bool) -> [Color] {
        isDark ? [rgb(0x14213A), rgb(0x1B3440), rgb(0x21403A)] : [rgb(0xCDE8FB), rgb(0xE3F4F2), rgb(0xFFF5DD)]
    }

    static func sun(isDark: Bool) -> Color { isDark ? rgb(0xFFE9A8, 0.1) : rgb(0xFFF3B8, 0.85) }
    static func farHill(isDark: Bool) -> Color { isDark ? rgb(0x234A41) : rgb(0xC8EACB) }
    static func nearHill(isDark: Bool) -> Color { isDark ? rgb(0x2B5A49) : rgb(0xAEDDB4) }
    static func mound(isDark: Bool) -> [Color] { isDark ? [rgb(0x3E7A5C), rgb(0x2F6149)] : [rgb(0xB5E3A6), rgb(0x8ED198)] }

    static func cloud(isDark: Bool) -> CGColor { CGColor(gray: 1, alpha: isDark ? 0.1 : 0.85) }
    static func leaves(isDark: Bool) -> [CGColor] {
        let alpha: CGFloat = isDark ? 0.5 : 0.9
        return [
            CGColor(red: 0.56, green: 0.84, blue: 0.58, alpha: alpha), CGColor(red: 0.42, green: 0.76, blue: 0.54, alpha: alpha),
            CGColor(red: 0.66, green: 0.88, blue: 0.63, alpha: alpha),
        ]
    }
    static func leafEdge(isDark: Bool) -> CGColor { CGColor(red: 0.2, green: 0.5, blue: 0.34, alpha: isDark ? 0.4 : 0.35) }
}

/// 구름과 잎을 올리고 움직이는 무대. 자리는 화면 크기에 대한 비율로 정한다(위에서 아래로).
@MainActor
final class VacationSceneStage {
    private struct Cloud {
        var x: CGFloat, y: CGFloat, width: CGFloat, drift: CGFloat, duration: Double
    }

    private struct Leaf {
        var x: CGFloat, y: CGFloat, length: CGFloat, angle: CGFloat, sway: CGFloat, duration: Double
    }

    /// 구름: 위쪽 하늘에 셋.
    private static let clouds = [
        Cloud(x: 0.16, y: 0.13, width: 0.34, drift: 18, duration: 11),
        Cloud(x: 0.8, y: 0.2, width: 0.28, drift: 14, duration: 14),
        Cloud(x: 0.55, y: 0.06, width: 0.2, drift: 10, duration: 9),
    ]
    /// 위쪽 두 구석에서 늘어진 큰 잎(구석을 중심으로 조금씩 흔들린다)과, 떠 있는 작은 잎.
    private static let foliage = [
        Leaf(x: -0.02, y: -0.01, length: 0.42, angle: 28, sway: 2.5, duration: 3.4),
        Leaf(x: -0.02, y: 0.02, length: 0.3, angle: 58, sway: 3, duration: 2.9),
        Leaf(x: 1.02, y: -0.01, length: 0.36, angle: 150, sway: 2.5, duration: 3.1),
        Leaf(x: 1.02, y: 0.03, length: 0.26, angle: 122, sway: 3, duration: 3.7),
    ]
    private static let floating = [
        Leaf(x: 0.12, y: 0.4, length: 0.05, angle: -24, sway: 14, duration: 2.6),
        Leaf(x: 0.9, y: 0.47, length: 0.045, angle: 200, sway: 16, duration: 3.2),
        Leaf(x: 0.2, y: 0.7, length: 0.04, angle: 32, sway: 12, duration: 2.9),
        Leaf(x: 0.83, y: 0.74, length: 0.05, angle: 160, sway: 15, duration: 3.5),
    ]

    private let root = CALayer()
    private var movers: [(layer: CALayer, animations: [(key: String, animation: CAAnimation)])] = []
    private var size = CGSize.zero
    private var isDark = false
    private var isAnimating = false

    func install(in host: CALayer) {
        guard root.superlayer !== host else { return }
        #if os(macOS)
        // AppKit의 레이어는 아래가 원점이다. 이 무대 안에서는 iOS처럼 위에서 아래로 놓는다.
        root.isGeometryFlipped = true
        #endif
        host.addSublayer(root)
    }

    func update(size: CGSize, isDark: Bool, isAnimating: Bool) {
        if size != self.size || isDark != self.isDark {
            self.size = size
            self.isDark = isDark
            build()
            self.isAnimating = false
        }
        guard isAnimating != self.isAnimating else { return }
        self.isAnimating = isAnimating
        for mover in movers {
            for item in mover.animations {
                if isAnimating { mover.layer.add(item.animation, forKey: item.key) } else { mover.layer.removeAnimation(forKey: item.key) }
            }
        }
    }

    func halt() {
        update(size: size, isDark: isDark, isAnimating: false)
    }

    private func build() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.sublayers?.forEach { $0.removeFromSuperlayer() }
        movers = []
        root.frame = CGRect(origin: .zero, size: size)
        guard size.width > 0, size.height > 0 else {
            CATransaction.commit()
            return
        }
        // 크기의 기준: 너무 넓은 창에서 구름과 잎이 지나치게 커지지 않게 한다.
        let unit = min(size.width, 720)
        let ease = CAMediaTimingFunction(name: .easeInEaseOut)

        for (index, cloud) in Self.clouds.enumerated() {
            let width = cloud.width * unit
            let layer = CAShapeLayer()
            layer.path = Self.cloudPath(width: width)
            layer.fillColor = VacationPalette.cloud(isDark: isDark)
            layer.bounds = CGRect(x: 0, y: 0, width: width, height: width * 0.46)
            layer.position = CGPoint(x: cloud.x * size.width, y: cloud.y * size.height)
            root.addSublayer(layer)
            let drift = CABasicAnimation(keyPath: "transform.translation.x")
            drift.fromValue = -cloud.drift
            drift.toValue = cloud.drift
            drift.duration = cloud.duration
            drift.autoreverses = true
            drift.repeatCount = .infinity
            drift.timingFunction = ease
            drift.timeOffset = Double(index) * 3.1
            movers.append((layer, [("drift", drift)]))
        }

        let colors = VacationPalette.leaves(isDark: isDark)
        for (index, leaf) in (Self.foliage + Self.floating).enumerated() {
            let isFoliage = index < Self.foliage.count
            let length = leaf.length * unit
            let layer = CAShapeLayer()
            layer.path = Self.leafPath(length: length)
            layer.fillColor = colors[index % colors.count]
            layer.strokeColor = VacationPalette.leafEdge(isDark: isDark)
            layer.lineWidth = isFoliage ? 1.5 : 1
            // 잎자루(왼쪽 끝)를 중심으로 돈다.
            layer.bounds = CGRect(x: 0, y: -length * 0.2, width: length, height: length * 0.4)
            layer.anchorPoint = CGPoint(x: 0, y: 0.5)
            layer.position = CGPoint(x: leaf.x * size.width, y: leaf.y * size.height)
            let base = leaf.angle * .pi / 180
            layer.setValue(base, forKeyPath: "transform.rotation.z")
            root.addSublayer(layer)
            let sway = CABasicAnimation(keyPath: "transform.rotation.z")
            sway.fromValue = base - leaf.sway * .pi / 180
            sway.toValue = base + leaf.sway * .pi / 180
            sway.duration = leaf.duration
            sway.autoreverses = true
            sway.repeatCount = .infinity
            sway.timingFunction = ease
            sway.timeOffset = Double(index) * 0.7
            var animations: [(String, CAAnimation)] = [("sway", sway)]
            if !isFoliage {
                // 떠 있는 잎은 위아래로도 조금 움직인다.
                let float = CABasicAnimation(keyPath: "transform.translation.y")
                float.fromValue = -5
                float.toValue = 5
                float.duration = leaf.duration * 1.3
                float.autoreverses = true
                float.repeatCount = .infinity
                float.timingFunction = ease
                float.timeOffset = Double(index) * 0.9
                animations.append(("float", float))
            }
            movers.append((layer, animations.map { (key: $0.0, animation: $0.1) }))
        }
        CATransaction.commit()
    }

    /// 뭉게구름: 납작한 바닥 위에 둥근 덩어리 셋.
    private static func cloudPath(width: CGFloat) -> CGPath {
        let height = width * 0.46
        let path = CGMutablePath()
        path.addRoundedRect(
            in: CGRect(x: 0, y: height * 0.45, width: width, height: height * 0.55), cornerWidth: height * 0.27, cornerHeight: height * 0.27
        )
        path.addEllipse(in: CGRect(x: width * 0.12, y: height * 0.18, width: width * 0.36, height: height * 0.7))
        path.addEllipse(in: CGRect(x: width * 0.36, y: 0, width: width * 0.4, height: height * 0.86))
        path.addEllipse(in: CGRect(x: width * 0.62, y: height * 0.26, width: width * 0.28, height: height * 0.6))
        return path
    }

    /// 잎 한 장: 잎자루(0, 0)에서 끝(length, 0)까지의 아몬드 꼴.
    private static func leafPath(length: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addQuadCurve(to: CGPoint(x: length, y: 0), control: CGPoint(x: length * 0.5, y: -length * 0.36))
        path.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.5, y: length * 0.36))
        return path
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
    let isDark: Bool
    let isAnimating: Bool

    final class Coordinator {
        @MainActor lazy var stage = VacationSceneStage()
        var isDark = false
        var isAnimating = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> VacationSceneHostView {
        let view = VacationSceneHostView()
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        let coordinator = context.coordinator
        view.onLayout = { size in
            coordinator.stage.update(size: size, isDark: coordinator.isDark, isAnimating: coordinator.isAnimating)
        }
        return view
    }

    static func dismantleNSView(_ view: VacationSceneHostView, coordinator: Coordinator) {
        coordinator.stage.halt()
    }

    func updateNSView(_ view: VacationSceneHostView, context: Context) {
        guard let layer = view.layer else { return }
        let coordinator = context.coordinator
        coordinator.isDark = isDark
        coordinator.isAnimating = isAnimating
        coordinator.stage.install(in: layer)
        coordinator.stage.update(size: view.bounds.size, isDark: isDark, isAnimating: isAnimating)
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
    let isDark: Bool
    let isAnimating: Bool

    final class Coordinator {
        @MainActor lazy var stage = VacationSceneStage()
        var isDark = false
        var isAnimating = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> VacationSceneHostView {
        let view = VacationSceneHostView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.clipsToBounds = true
        let coordinator = context.coordinator
        view.onLayout = { size in
            coordinator.stage.update(size: size, isDark: coordinator.isDark, isAnimating: coordinator.isAnimating)
        }
        return view
    }

    static func dismantleUIView(_ view: VacationSceneHostView, coordinator: Coordinator) {
        coordinator.stage.halt()
    }

    func updateUIView(_ view: VacationSceneHostView, context: Context) {
        let coordinator = context.coordinator
        coordinator.isDark = isDark
        coordinator.isAnimating = isAnimating
        coordinator.stage.install(in: view.layer)
        coordinator.stage.update(size: view.bounds.size, isDark: isDark, isAnimating: isAnimating)
    }
}
#endif
