import QuartzCore
import SwiftUI

/// 첫 동기화 장면을 Core Animation 레이어로 올리고 움직인다.
///
/// 조각(구름·카드·수첩·체크·별·빗방울·새싹 장식)은 처음에 한 번만 그림으로 만들고, 새싹이는 공식 원화 레이어를 쓴다.
/// 움직이는 값마다(`SyncSceneMotion.Property`) 그 값이 되풀이되는 방식(`loop`)대로 한 바퀴만 키프레임으로 뽑아 무한 반복을 건다.
/// 그래서 앱은 매 프레임 아무것도 계산하지 않고, 그리는 일은 시스템(렌더 서버)이 한다. 값 자체는 테스트된 `SyncSceneMotion`과 같다.
@MainActor
final class SyncSceneStage {
    struct Configuration: Equatable {
        var kind: SyncSceneKind
        var height: CGFloat
        var dark: Bool
        var scale: CGFloat
        var reduceMotion: Bool
    }

    /// 값 하나를 레이어의 한 속성에 잇는다. `map`은 장면의 값(장면 단위·도)을 레이어 값(pt·라디안)으로 바꾼다.
    private struct Binding {
        let property: SyncSceneMotion.Property
        let layer: CALayer
        let keyPath: String
        let map: (Double) -> CGFloat
    }

    let root = CALayer()
    private var configuration: Configuration?
    private var bindings: [Binding] = []
    /// 장면이 처음 움직이기 시작한 시각. 뒤로 갔다가 돌아오면 이 시각을 기준으로 다시 걸어 이어서 움직인다.
    private var start: CFTimeInterval?
    private var isAnimating = false
    /// 키프레임을 뽑는 간격(1초에 몇 번). 0.16초 깜빡임도 여섯 번에 나뉘어 매끄럽다.
    private static let samplesPerSecond = 40.0

    #if os(macOS)
    /// AppKit 레이어는 아래가 원점이다: 위아래와 회전 방향을 뒤집어 놓는다.
    private static let flipsY = true
    #else
    private static let flipsY = false
    #endif

    func update(_ configuration: Configuration, isAnimating: Bool) {
        if configuration != self.configuration {
            self.configuration = configuration
            build(configuration)
            apply(isAnimating, force: true)
        } else {
            apply(isAnimating, force: false)
        }
    }

    /// 뷰가 사라질 때: 걸어 둔 애니메이션을 모두 내린다.
    func halt() {
        apply(false, force: true)
    }

    // MARK: - 움직임 걸기

    private func apply(_ animating: Bool, force: Bool) {
        guard let configuration, force || animating != isAnimating else { return }
        isAnimating = animating
        let kind = configuration.kind
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for binding in bindings { binding.layer.removeAllAnimations() }
        // 멈춰 있을 때(움직임 줄이기)는 장면의 한 순간을, 움직일 때는 처음 모습을 바탕 값으로 둔다.
        let still = configuration.reduceMotion ? SyncSceneMotion.stillTime(kind) : 0
        for binding in bindings {
            binding.layer.setValue(binding.map(SyncSceneMotion.value(binding.property, kind, at: still)), forKeyPath: binding.keyPath)
        }
        if animating {
            let start = self.start ?? CACurrentMediaTime()
            self.start = start
            for (index, binding) in bindings.enumerated() {
                for (part, animation) in animations(binding, kind: kind, start: start).enumerated() {
                    binding.layer.add(animation, forKey: "sync.\(index).\(part)")
                }
            }
        }
        CATransaction.commit()
    }

    /// 한 값의 애니메이션: 처음 한 번 하는 부분(`intro`)과 그 뒤로 되풀이하는 한 바퀴(`period`).
    private func animations(_ binding: Binding, kind: SyncSceneKind, start: CFTimeInterval) -> [CAAnimation] {
        let loop = SyncSceneMotion.loop(binding.property, kind)
        func values(from: Double, length: Double) -> [CGFloat] {
            let count = max(2, Int((length * Self.samplesPerSecond).rounded()))
            return (0...count).map { step in
                binding.map(SyncSceneMotion.value(binding.property, kind, at: from + length * Double(step) / Double(count)))
            }
        }
        func keyframes(_ values: [CGFloat], duration: Double, begin: Double) -> CAKeyframeAnimation {
            let animation = CAKeyframeAnimation(keyPath: binding.keyPath)
            animation.values = values.map { NSNumber(value: Double($0)) }
            animation.duration = duration
            animation.beginTime = start + begin
            animation.calculationMode = .linear
            return animation
        }
        func isConstant(_ values: [CGFloat]) -> Bool { values.allSatisfy { abs($0 - values[0]) < 1e-6 } }
        let model = binding.map(SyncSceneMotion.value(binding.property, kind, at: 0))
        var result: [CAAnimation] = []
        if loop.intro > 0 {
            let intro = values(from: 0, length: loop.intro)
            if !isConstant(intro) {
                let animation = keyframes(intro, duration: loop.intro, begin: 0)
                if loop.period == nil {
                    // 끝난 뒤로는 마지막 값에 머문다.
                    animation.fillMode = .forwards
                    animation.isRemovedOnCompletion = false
                }
                result.append(animation)
            }
        }
        if let period = loop.period {
            // 한 바퀴의 끝은 처음과 같은 값이다(되풀이할 때 이음매에서 튀지 않게).
            var cycle = values(from: loop.intro, length: period)
            cycle[cycle.count - 1] = cycle[0]
            if !isConstant(cycle) || abs(cycle[0] - model) > 1e-6 {
                let animation = keyframes(cycle, duration: period, begin: loop.intro)
                animation.repeatCount = .infinity
                result.append(animation)
            }
        }
        return result
    }

    // MARK: - 레이어 짓기

    private func build(_ configuration: Configuration) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        root.sublayers?.forEach { $0.removeFromSuperlayer() }
        bindings = []
        let height = configuration.height
        root.bounds = CGRect(x: 0, y: 0, width: height, height: height)
        let u = height / 340
        let kind = configuration.kind
        let mascot = 128 * u
        let ground = 328 * u
        let pad = SaessagiRenderer.padding
        let side = mascot + pad * 2
        // 수첩의 가운데(장면 안, 위쪽 가운데가 원점, pt).
        let bookAnchor = SaessagiRenderer.unitPoint(of: Self.bookSource, pose: .idle, size: mascot)
        let book = CGPoint(x: (bookAnchor.x - 0.5) * side, y: ground - mascot - pad + bookAnchor.y * side)

        root.addSublayer(piece(SyncBackdrop(kind: kind, unit: u, dark: configuration.dark), at: CGPoint(x: 0, y: 180 * u)))
        // 바닥의 새싹 장식: 밑동을 기준으로 살랑인다.
        for (index, x) in [-140.0, -112.0, 108.0, 138.0].enumerated() {
            let scale = [1.0, 0.75, 0.8, 1.05][index]
            let sprout = image(SyncSprout(kind: kind, unit: u * scale))
            sprout.anchorPoint = CGPoint(x: 0.5, y: Self.flipsY ? 0 : 1)
            sprout.position = point(x * u, ground)
            root.addSublayer(sprout)
            let direction = index.isMultiple(of: 2) ? 1.0 : -1.0
            bind(.leafSway, sprout, "transform.rotation.z") { Self.radians($0 * 0.25 * direction) }
        }

        switch kind {
        case .receiving:
            let cloud = fullLayer()
            root.addSublayer(cloud)
            bind(.cloudY, cloud, "transform.translation.y") { Self.down($0 * u) }
            let glow = piece(SyncGlow(color: .white.opacity(0.9), width: 240 * u, height: 160 * u), at: CGPoint(x: 0, y: 79 * u))
            cloud.addSublayer(glow)
            bind(.glow, glow, "opacity") { CGFloat($0) }
            cloud.addSublayer(piece(SyncCloud(unit: u, tone: .white, dark: configuration.dark), at: CGPoint(x: 0, y: 79 * u)))
        case .ready:
            let sun = configuration.dark ? Color(red: 1, green: 0.93, blue: 0.55).opacity(0.35) : Color(red: 1, green: 0.93, blue: 0.55).opacity(0.75)
            let glow = piece(SyncGlow(color: sun, width: 240 * u, height: 240 * u), at: CGPoint(x: 0, y: 70 * u))
            root.addSublayer(glow)
            bind(.glow, glow, "opacity") { CGFloat($0) }
            let check = piece(SyncCheck(unit: u), at: CGPoint(x: 0, y: 64 * u), padding: 14 * u)
            root.addSublayer(check)
            bind(.check, check, "transform.scale") { CGFloat($0) }
            bind(.check, check, "opacity") { CGFloat(min(1, $0 * 3)) }
            for (index, place) in Self.starPlaces.enumerated() {
                let star = image(SyncSparkle(size: place.size * u))
                star.position = point(place.x * u, place.y * u + star.bounds.height / 2)
                root.addSublayer(star)
                bind(.star(index), star, "transform.scale") { CGFloat($0) }
                bind(.star(index), star, "opacity") { CGFloat(min(1, $0)) }
            }
        case .trouble:
            let cloud = fullLayer()
            root.addSublayer(cloud)
            bind(.cloudX, cloud, "transform.translation.x") { CGFloat($0) * u }
            bind(.cloudY, cloud, "transform.translation.y") { Self.down($0 * u) }
            cloud.addSublayer(piece(SyncCloud(unit: u, tone: .gray, dark: configuration.dark), at: CGPoint(x: 0, y: 73 * u)))
            for (index, x) in [-30.0, 4.0, 32.0].enumerated() where index < SyncSceneMotion.dropCount {
                let drop = piece(SyncRaindrop(unit: u), at: CGPoint(x: x * u, y: 119 * u))
                cloud.addSublayer(drop)
                bind(.drop(index), drop, "transform.translation.y") { Self.down($0 * SyncSceneMotion.dropDistance * u) }
                bind(.drop(index), drop, "opacity") { CGFloat(SyncSceneMotion.dropOpacity($0)) }
            }
        }

        root.addSublayer(saessagi(configuration, size: mascot, side: side, top: ground - mascot - pad))

        switch kind {
        case .receiving:
            let bookInScene = CGPoint(x: book.x / u, y: book.y / u)
            for kindIndex in 0..<SyncFallingCard.Kind.allCases.count {
                let startX = SyncSceneMotion.cardStarts[kindIndex % SyncSceneMotion.cardStarts.count]
                // 이동(자리·불투명도)과 모양(기울기·크기)을 나눠 둔다: 작아질 때 자리까지 같이 줄지 않게.
                let mover = CALayer()
                mover.position = point(0, 0)
                let card = image(SyncRecordCard(kind: SyncFallingCard.Kind(rawValue: kindIndex)!, unit: u), padding: 8 * u)
                mover.bounds = card.bounds
                card.position = CGPoint(x: card.bounds.midX, y: card.bounds.midY)
                mover.addSublayer(card)
                root.addSublayer(mover)
                func placed(_ progress: Double) -> (x: Double, y: Double, rotation: Double, scale: Double, opacity: Double) {
                    SyncSceneMotion.cardPlacement(progress: progress, startX: startX, book: bookInScene)
                }
                bind(.card(kindIndex), mover, "transform.translation.x") { CGFloat(placed($0).x) * u }
                bind(.card(kindIndex), mover, "transform.translation.y") { Self.down(placed($0).y * u) }
                bind(.card(kindIndex), mover, "opacity") { CGFloat(placed($0).opacity) }
                bind(.card(kindIndex), card, "transform.rotation.z") { Self.radians(placed($0).rotation) }
                bind(.card(kindIndex), card, "transform.scale") { CGFloat(placed($0).scale) }
            }
            let sparkle = image(SyncSparkle(size: 16 * u))
            sparkle.position = point(book.x + 26 * u, book.y - 26 * u + sparkle.bounds.height / 2)
            root.addSublayer(sparkle)
            bind(.bookSparkle, sparkle, "transform.scale") { CGFloat(0.4 + 0.8 * $0) }
            bind(.bookSparkle, sparkle, "opacity") { CGFloat($0) }
        case .trouble:
            let question = image(SyncQuestion(unit: u))
            question.position = point(58 * u, ground - mascot - 6 * u + question.bounds.height / 2)
            root.addSublayer(question)
            bind(.question, question, "transform.scale") { CGFloat($0) }
            bind(.question, question, "opacity") { CGFloat(min(1, $0 * 2)) }
            bind(.questionTilt, question, "transform.rotation.z") { Self.radians($0) }
        case .ready:
            break
        }
    }

    /// 새싹이: 이동·눌림(`mover`) → 숨(`breather`) → 두 발과 몸통(`torso`: 몸 → 얼굴(입·눈) → 잎 → 수첩).
    private func saessagi(_ configuration: Configuration, size: CGFloat, side: CGFloat, top: CGFloat) -> CALayer {
        let scale = configuration.scale
        let holder = CALayer()
        holder.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        holder.position = point(0, top + side / 2)
        func unit(_ source: CGPoint) -> CGPoint { SaessagiRenderer.unitPoint(of: source, pose: .idle, size: size) }
        func layer(_ asset: String?, anchor: CGPoint = CGPoint(x: 0.5, y: 0.5)) -> CALayer {
            let layer = CALayer()
            place(layer, anchor: anchor, side: side)
            if let asset, let image = SaessagiRenderer.image(asset: asset, pose: .idle, size: size, displayScale: scale) {
                layer.contents = image
                layer.contentsScale = scale
                layer.contentsGravity = .resize
            }
            return layer
        }
        let content = SaessagiPose.idle.content
        let feet = unit(CGPoint(x: content.midX, y: content.maxY))
        let mover = layer(nil, anchor: feet)
        let breather = layer(nil, anchor: feet)
        let torso = layer(nil, anchor: unit(SaessagiIdleLayers.hip))
        let face = layer(nil)
        let eyes = layer(SaessagiIdleLayers.eyes, anchor: unit(SaessagiIdleLayers.eyeCenter))
        let sway = layer(nil, anchor: unit(SaessagiIdleLayers.leafPivot))
        let leaf = layer(SaessagiIdleLayers.leaf, anchor: unit(SaessagiIdleLayers.leafPivot))
        holder.addSublayer(mover)
        mover.addSublayer(breather)
        breather.addSublayer(layer(SaessagiIdleLayers.footLeft))
        breather.addSublayer(layer(SaessagiIdleLayers.footRight))
        breather.addSublayer(torso)
        torso.addSublayer(layer(SaessagiIdleLayers.body))
        torso.addSublayer(face)
        face.addSublayer(layer(SaessagiIdleLayers.mouth))
        face.addSublayer(eyes)
        torso.addSublayer(sway)
        sway.addSublayer(leaf)

        bind(.lift, mover, "transform.translation.y") { Self.down(-$0 * size) }
        bind(.squashX, mover, "transform.scale.x") { CGFloat($0) }
        bind(.squashY, mover, "transform.scale.y") { CGFloat($0) }
        bind(.breath, breather, "transform.scale.y") { CGFloat($0) }
        bind(.tilt, torso, "transform.rotation.z") { Self.radians($0) }
        bind(.faceX, face, "transform.translation.x") { CGFloat($0) * size }
        bind(.faceY, face, "transform.translation.y") { Self.down($0 * size) }
        bind(.eyes, eyes, "transform.scale.y") { CGFloat($0) }
        bind(.leafSway, sway, "transform.rotation.z") { Self.radians($0) }
        bind(.leaf, leaf, "transform.rotation.z") { Self.radians($0) }

        // 수첩: 두 손이 모인 자리에. 펼친 수첩은 기록이 들어올 때 들썩이고 가끔 쪽이 넘어간다.
        let style: SyncNotebook.Style? = switch configuration.kind {
        case .receiving: .open
        case .ready: .closed
        case .trouble: nil
        }
        if let style {
            let anchor = unit(Self.bookSource)
            let base = image(SyncNotebook(style: style, size: size), padding: 0.04 * size)
            let bookMover = CALayer()
            bookMover.bounds = base.bounds
            let y = anchor.y * side + (style == .closed ? 0.035 * side : 0)
            bookMover.position = CGPoint(x: anchor.x * side, y: Self.flipsY ? side - y : y)
            let tilt = CALayer()
            tilt.bounds = base.bounds
            tilt.position = CGPoint(x: base.bounds.midX, y: base.bounds.midY)
            tilt.transform = CATransform3DMakeRotation(Self.radians(style == .open ? -4 : -6), 0, 0, 1)
            base.position = tilt.position
            tilt.addSublayer(base)
            bookMover.addSublayer(tilt)
            torso.addSublayer(bookMover)
            if style == .open {
                bind(.bookLift, bookMover, "transform.translation.y") { Self.down(-$0 * side) }
                let pageSize = SyncNotebook.pageSize(size)
                let page = image(SyncNotebookPage(size: size, page: pageSize, lines: 0))
                page.anchorPoint = CGPoint(x: 0, y: 0.5)
                page.position = CGPoint(x: base.bounds.midX + 0.006 * size, y: base.bounds.midY)
                var perspective = CATransform3DIdentity
                perspective.m34 = -1 / (pageSize.width * 4)
                tilt.sublayerTransform = perspective
                tilt.addSublayer(page)
                bind(.pageFlip, page, "transform.rotation.y") { -CGFloat.pi * CGFloat($0) }
                bind(.pageFlip, page, "opacity") { $0 > 0.001 && $0 < 0.999 ? 1 : 0 }
            }
        }
        return holder
    }

    // MARK: - 도움 함수

    /// 수첩을 드는 자리(원화 1024 기준): 두 손이 배 앞에 모인 곳.
    static let bookSource = CGPoint(x: 512, y: 770)
    /// 준비 완료의 별 자리(장면 단위, 위쪽 가운데가 원점)와 크기.
    static let starPlaces: [(x: Double, y: Double, size: Double)] = [
        (-74, 40, 18), (76, 58, 15), (-108, 196, 14), (104, 184, 18), (-62, 128, 11), (66, 140, 12),
    ]

    private func bind(_ property: SyncSceneMotion.Property, _ layer: CALayer, _ keyPath: String, _ map: @escaping (Double) -> CGFloat) {
        bindings.append(Binding(property: property, layer: layer, keyPath: keyPath, map: map))
    }

    /// 장면 안의 점(가운데에서 오른쪽으로 `x`, 위에서 아래로 `y`, pt)을 레이어 좌표로.
    private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        let height = root.bounds.height
        return CGPoint(x: root.bounds.width / 2 + x, y: Self.flipsY ? height - y : y)
    }

    /// 아래쪽으로 옮기는 거리(pt)를 레이어의 y 이동으로.
    private static func down(_ value: Double) -> CGFloat { CGFloat(flipsY ? -value : value) }
    /// 시계 방향 각도(도)를 레이어의 회전(라디안)으로.
    private static func radians(_ degrees: Double) -> CGFloat { CGFloat(degrees * .pi / 180 * (flipsY ? -1 : 1)) }

    /// 장면 전체 크기의 빈 레이어(구름과 빗방울을 함께 옮길 때).
    private func fullLayer() -> CALayer {
        let layer = CALayer()
        layer.bounds = root.bounds
        layer.position = CGPoint(x: root.bounds.midX, y: root.bounds.midY)
        return layer
    }

    /// 조각 하나를 그림으로 만들어 그 가운데를 장면의 `center`에 둔다.
    private func piece(_ view: some View, at center: CGPoint, padding: CGFloat = 0) -> CALayer {
        let layer = image(view, padding: padding)
        layer.position = point(center.x, center.y)
        return layer
    }

    /// SwiftUI 조각을 한 번 그림으로 만든 레이어. 그림자가 잘리지 않게 `padding`만큼 둘레를 둔다(가운데는 그대로).
    private func image(_ view: some View, padding: CGFloat = 0) -> CALayer {
        let layer = CALayer()
        guard let configuration else { return layer }
        let renderer = ImageRenderer(
            content: view.padding(padding).environment(\.colorScheme, configuration.dark ? .dark : .light)
        )
        renderer.scale = configuration.scale
        if let image = renderer.cgImage {
            layer.contents = image
            layer.contentsScale = configuration.scale
            layer.bounds = CGRect(
                x: 0, y: 0, width: CGFloat(image.width) / configuration.scale, height: CGFloat(image.height) / configuration.scale
            )
        }
        return layer
    }

    /// `anchor`(왼쪽 위가 원점인 0…1)를 중심으로 삼아 한 변이 `side`인 레이어를 제자리에 놓는다.
    private func place(_ layer: CALayer, anchor: CGPoint, side: CGFloat) {
        let point = CGPoint(x: anchor.x, y: Self.flipsY ? 1 - anchor.y : anchor.y)
        layer.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        layer.anchorPoint = point
        layer.position = CGPoint(x: point.x * side, y: point.y * side)
    }
}

/// 기다리는 점 세 개: 차례로 커지며 밝아지고 살짝 떠오른다(1.2초 주기).
@MainActor
final class SyncDotsStage {
    static let width: CGFloat = 50
    static let height: CGFloat = 16
    static let period = 1.2

    let root = CALayer()
    private var dots: [CALayer] = []
    private var isAnimating: Bool?

    #if os(macOS)
    private static let up: CGFloat = 1
    #else
    private static let up: CGFloat = -1
    #endif

    init() {
        root.bounds = CGRect(x: 0, y: 0, width: Self.width, height: Self.height)
        for index in 0..<3 {
            let dot = CALayer()
            dot.bounds = CGRect(x: 0, y: 0, width: 10, height: 10)
            dot.cornerRadius = 5
            dot.backgroundColor = CGColor(red: 0.25, green: 0.55, blue: 0.95, alpha: 1)
            dot.position = CGPoint(x: 6 + CGFloat(index) * 19, y: Self.height / 2)
            root.addSublayer(dot)
            dots.append(dot)
        }
    }

    /// 그 점이 얼마나 커졌는가(0…1).
    static func phase(_ index: Int, at t: Double) -> Double {
        (sin(2 * .pi * (t / period - Double(index) * 0.18)) + 1) / 2
    }

    func update(isAnimating: Bool) {
        guard isAnimating != self.isAnimating else { return }
        self.isAnimating = isAnimating
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, dot) in dots.enumerated() {
            dot.removeAllAnimations()
            // 멈춰 있을 때는 가운데 크기.
            dot.setValue(0.9, forKeyPath: "transform.scale")
            dot.opacity = 0.67
            guard isAnimating else { continue }
            let count = 48
            let samples = (0...count).map { Self.phase(index, at: Self.period * Double($0) / Double(count)) }
            let tracks: [(String, (Double) -> Double)] = [
                ("transform.scale", { 0.75 + 0.3 * $0 }), ("opacity", { 0.35 + 0.65 * $0 }),
                ("transform.translation.y", { Double(Self.up) * 3 * $0 }),
            ]
            for (keyPath, map) in tracks {
                let animation = CAKeyframeAnimation(keyPath: keyPath)
                animation.values = samples.map { NSNumber(value: map($0)) }
                animation.duration = Self.period
                animation.repeatCount = .infinity
                dot.add(animation, forKey: keyPath)
            }
        }
        CATransaction.commit()
    }
}

// MARK: - 뷰에 얹기

#if os(macOS)
import AppKit

/// 레이어를 얹는 빈 뷰. 누르기는 받지 않는다.
final class SyncLayerHost: NSView {
    var hosted: CALayer?

    override func layout() {
        super.layout()
        hosted?.position = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct SyncLayerView: NSViewRepresentable {
    let configuration: SyncSceneStage.Configuration
    let isAnimating: Bool

    final class Coordinator {
        @MainActor lazy var stage = SyncSceneStage()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SyncLayerHost {
        let view = SyncLayerHost()
        view.wantsLayer = true
        view.layer?.addSublayer(context.coordinator.stage.root)
        view.hosted = context.coordinator.stage.root
        return view
    }

    func updateNSView(_ view: SyncLayerHost, context: Context) {
        context.coordinator.stage.update(configuration, isAnimating: isAnimating)
        view.needsLayout = true
    }

    static func dismantleNSView(_ view: SyncLayerHost, coordinator: Coordinator) {
        coordinator.stage.halt()
    }
}

struct SyncDotsLayerView: NSViewRepresentable {
    let isAnimating: Bool

    final class Coordinator {
        @MainActor lazy var stage = SyncDotsStage()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SyncLayerHost {
        let view = SyncLayerHost()
        view.wantsLayer = true
        view.layer?.addSublayer(context.coordinator.stage.root)
        view.hosted = context.coordinator.stage.root
        return view
    }

    func updateNSView(_ view: SyncLayerHost, context: Context) {
        context.coordinator.stage.update(isAnimating: isAnimating)
        view.needsLayout = true
    }

    static func dismantleNSView(_ view: SyncLayerHost, coordinator: Coordinator) {
        coordinator.stage.update(isAnimating: false)
    }
}
#else
import UIKit

/// 레이어를 얹는 빈 뷰. 누르기는 받지 않는다.
final class SyncLayerHost: UIView {
    var hosted: CALayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        hosted?.position = CGPoint(x: bounds.midX, y: bounds.midY)
    }
}

struct SyncLayerView: UIViewRepresentable {
    let configuration: SyncSceneStage.Configuration
    let isAnimating: Bool

    final class Coordinator {
        @MainActor lazy var stage = SyncSceneStage()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SyncLayerHost {
        let view = SyncLayerHost()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.layer.addSublayer(context.coordinator.stage.root)
        view.hosted = context.coordinator.stage.root
        return view
    }

    func updateUIView(_ view: SyncLayerHost, context: Context) {
        context.coordinator.stage.update(configuration, isAnimating: isAnimating)
        view.setNeedsLayout()
    }

    static func dismantleUIView(_ view: SyncLayerHost, coordinator: Coordinator) {
        coordinator.stage.halt()
    }
}

struct SyncDotsLayerView: UIViewRepresentable {
    let isAnimating: Bool

    final class Coordinator {
        @MainActor lazy var stage = SyncDotsStage()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SyncLayerHost {
        let view = SyncLayerHost()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.layer.addSublayer(context.coordinator.stage.root)
        view.hosted = context.coordinator.stage.root
        return view
    }

    func updateUIView(_ view: SyncLayerHost, context: Context) {
        context.coordinator.stage.update(isAnimating: isAnimating)
        view.setNeedsLayout()
    }

    static func dismantleUIView(_ view: SyncLayerHost, coordinator: Coordinator) {
        coordinator.stage.update(isAnimating: false)
    }
}
#endif
