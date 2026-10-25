import SwiftUI
#if os(iOS)
import UIKit
#endif

/// 앱을 열 때 한 번 보여 주는 Routimori 스플래시(iPhone·iPad·Mac). 피오가 위에서 폴짝 내려앉아 몸을 찌부렸다 펴고,
/// 새싹을 살랑이고, 좌우를 둘러보며 날개로 인사하고, 눈을 한 번 깜빡인 뒤 걷힌다.
///
/// - 첫 장면은 시스템 Launch Screen과 같다(같은 아이보리 배경, 그림 없음). 그래서 넘어올 때 번쩍이거나 튀지 않는다.
/// - iPhone·iPad의 색은 앱의 테마 설정이 아니라 시스템의 라이트/다크를 따른다. Launch Screen이 시스템 모드로 그려지기 때문이다.
///   Mac은 Launch Screen이 없어 창의 모드를 따른다.
/// - 피오는 부위별 그림(몸·새싹·날개·발·눈·감은 눈)을 같은 좌표에 겹친 것이다. 양 날개와 새싹은 저마다의 밑동을 중심으로 돌고,
///   눈은 감은 눈 그림으로 바뀐다. 몸 전체는 발밑을 중심으로 뜨고, 찌부러지고, 기운다.
/// - 꾸밈일 뿐이라 접근성 요소에서 뺀다. 밑의 화면은 처음부터 VoiceOver로 탐색할 수 있다.
struct SplashView: View {
    /// 스플래시가 걷히기 시작할 때 한 번 불린다. 이때부터 시작 안내 같은 시트를 올려도 된다.
    var onLeaving: () -> Void = {}
    /// 스플래시가 다 걷힌 뒤 한 번 불린다.
    let onFinish: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage: SplashTimeline.Stage = .start
    @State private var hasStarted = false
    @State private var hasFinished = false
    /// 이번 실행의 시간표. 재생 시간은 앱을 켤 때의 원격 UI 설정(저장해 둔 것)에서 온다.
    @State private var timeline = SplashTimeline.standard
    /// 바뀔 때마다 등장 연기(내려앉기·둘러보기·인사·깜빡임)를 한 번 한다.
    @State private var performances = 0
    #if os(iOS)
    /// Launch Screen을 그린 시스템의 모드. 앱의 테마 설정과 다를 수 있다.
    @State private var isDark = UIScreen.main.traitCollection.userInterfaceStyle == .dark
    #else
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    #endif

    var body: some View {
        GeometryReader { proxy in
            let metrics = Metrics(size: proxy.size)
            ZStack {
                background
                titles(metrics)
                    .position(x: proxy.size.width / 2, y: metrics.titleCenterY)
                figure(metrics)
                    .position(x: proxy.size.width / 2, y: metrics.figureCenterY)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .opacity(stage == .leaving ? 0 : 1)
        .accessibilityHidden(true)
        .onChange(of: scenePhase, initial: true) { _, phase in
            // 화면이 보이기 시작하면(비활성 단계부터) 바로 시작한다. 활성화까지 기다리면 0.2초쯤 가만히 서 있게 된다.
            // 백그라운드로 실행된 동안에는 시작하지 않는다.
            if phase != .background { start() }
        }
        .task {
            // 화면이 보이지 않는 채 실행된 경우(알림의 동작 등): 시작하지 못한 스플래시를 남겨 두지 않는다.
            try? await Task.sleep(for: .seconds(SplashTimeline.startGrace))
            if !hasStarted { finish() }
        }
    }

    // MARK: - 장면

    @ViewBuilder
    private var background: some View {
        #if os(iOS)
        Self.color(named: "SplashBackground", isDark: isDark)
        #else
        Color("SplashBackground")
        #endif
    }

    /// 로고와 한 줄 문구. 로고의 i 위에는 점 대신 피오의 새싹이 난다.
    private func titles(_ metrics: Metrics) -> some View {
        let shown = stage >= .logo
        let nameAnimation: Animation? = shown ? .easeOut(duration: timeline.titleFadeDuration).delay(timeline.nameDelay) : nil
        let taglineAnimation: Animation? = shown ? .easeOut(duration: timeline.titleFadeDuration).delay(timeline.taglineDelay) : nil
        let size = metrics.logoSize
        return VStack(spacing: size * 0.24) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Rout")
                Text("i")
                    .overlay(alignment: .top) {
                        Image("routimori_splash_pio_sprout")
                            .resizable()
                            .interpolation(.high)
                            .frame(width: size * 0.78, height: size * 0.78 * Figure.sproutAspect)
                            // 새싹 줄기의 밑동을 i의 점 자리에 맞춘다.
                            .offset(x: size * 0.03, y: -size * 0.12)
                    }
                Text("Mori")
            }
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(isDark ? Color(red: 0.90, green: 0.95, blue: 0.88) : Color(red: 0.07, green: 0.20, blue: 0.13))
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : size * 0.15)
            .animation(nameAnimation, value: shown)
            Text("Small habits, Lasting growth.")
                .font(.system(size: size * 0.36, weight: .medium, design: .rounded))
                .tracking(size * 0.03)
                .foregroundStyle(isDark ? Color(red: 0.64, green: 0.74, blue: 0.65) : Color(red: 0.33, green: 0.45, blue: 0.35))
                .opacity(shown ? 1 : 0)
                .animation(taglineAnimation, value: shown)
        }
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .fixedSize()
    }

    private func figure(_ metrics: Metrics) -> some View {
        let shown = stage >= (timeline.reducesMotion ? .logo : .grown)
        return KeyframeAnimator(initialValue: Performance(), trigger: performances) { pose in
            Figure(width: metrics.figureWidth, pose: pose, outfitAsset: equippedOutfitAsset)
        } keyframes: { _ in
            Performance.keyframes
        }
        .opacity(shown ? 1 : 0)
    }

    /// 옷장에서 입힌 의상의 그림. 기본 피오면 nil(부위별 그림으로 그린다).
    private var equippedOutfitAsset: String? {
        guard PioCharacter.isEnabled else { return nil }
        let outfit = PioAppearanceCoordinator.shared.equippedOutfit
        return outfit == .basic ? nil : outfit.artAssetName
    }

    // MARK: - 진행

    private func start() {
        guard !hasStarted else { return }
        hasStarted = true
        #if os(iOS)
        isDark = UIScreen.main.traitCollection.userInterfaceStyle == .dark
        #endif
        #if DEBUG
        // 시간 확인용: 화면이 만들어진 뒤 스플래시가 움직이기 시작할 때까지 걸린 시간.
        if UserDefaults.standard.bool(forKey: "DaylogDebugSplashLog") {
            print(String(format: "DAYLOG_SPLASH start +%.3fs after first view", ProcessInfo.processInfo.systemUptime - SplashPolicy.claimedAt))
        }
        // 화면 검증용: `-DaylogDebugSplashHold logo`처럼 한 장면에서 멈춰 둔다(걷히지 않는다). `greeting`은 인사를 되풀이한다.
        if let name = UserDefaults.standard.string(forKey: "DaylogDebugSplashHold") {
            if name == "greeting" {
                stage = .settled
                Task { @MainActor in
                    while true { performances += 1; try? await Task.sleep(for: .seconds(Performance.duration + 0.6)) }
                }
                return
            }
            if let held = SplashTimeline.Stage.allCases.first(where: { "\($0)" == name }) {
                stage = held
                return
            }
        }
        #endif
        // 받아 둔 설정의 재생 시간을 쓴다. 실행 중에 새로 받은 값은 다음 실행부터다.
        let timeline = SplashTimeline.make(reduceMotion: reduceMotion, duration: MobileUIConfigCache.atLaunch.splashDuration)
        self.timeline = timeline
        Task { @MainActor in
            var elapsed = 0.0
            for step in timeline.steps {
                try? await Task.sleep(for: .seconds(max(step.at - elapsed, 0)))
                elapsed = step.at
                if step.stage == .leaving { onLeaving() }
                withAnimation(Self.animation(for: step, reducesMotion: timeline.reducesMotion)) {
                    stage = step.stage
                }
                // 나타나는 순간 등장 연기를 시작한다(동작 줄이기에서는 하지 않는다).
                if step.stage == .grown, !timeline.reducesMotion { performances += 1 }
            }
            try? await Task.sleep(for: .seconds(timeline.total - elapsed))
            finish()
        }
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "DaylogDebugSplashLog") {
            print(String(format: "DAYLOG_SPLASH finish +%.3fs after first view", ProcessInfo.processInfo.systemUptime - SplashPolicy.claimedAt))
        }
        #endif
        onLeaving()
        onFinish()
    }

    private static func animation(for step: SplashTimeline.Step, reducesMotion: Bool) -> Animation {
        switch step.stage {
        case .grown where !reducesMotion: return .easeOut(duration: 0.12)
        case .leaving: return .easeIn(duration: step.duration)
        default: return reducesMotion ? .linear(duration: step.duration) : .easeOut(duration: step.duration)
        }
    }

    // MARK: - 색

    #if os(iOS)
    /// 에셋의 색을 시스템 모드로 풀어서 쓴다(앱의 테마 설정을 타지 않게).
    static func color(named name: String, isDark: Bool) -> Color {
        let traits = UITraitCollection(userInterfaceStyle: isDark ? .dark : .light)
        guard let color = UIColor(named: name)?.resolvedColor(with: traits) else { return Color(uiColor: .systemBackground) }
        return Color(uiColor: color)
    }
    #endif
}

extension SplashView {
    /// 화면 크기에 맞춘 치수. 세로로 긴 화면(iPhone)은 로고를 위쪽 4분의 1, 피오를 가운데보다 조금 아래에 둔다.
    /// 가로로 넓은 창(iPad 가로, Mac)은 높이에 맞춰 줄인다.
    struct Metrics {
        let size: CGSize

        var logoSize: CGFloat { min(size.width * 0.105, size.height * 0.058, 60) }
        var figureWidth: CGFloat { min(size.width * 0.58, size.height * 0.36, 400) }
        var titleCenterY: CGFloat { size.height * 0.285 }
        var figureCenterY: CGFloat { size.height * 0.60 }
    }

    /// 등장 연기 한 번. 시간은 피오가 나타나는 순간부터 잰다.
    ///
    /// 0.00–0.24 위에서 폴짝 내려앉는다(양 날개를 들고, 새싹은 뒤로 젖혀진다) → 0.24–0.55 찌부렸다 튕기며 펴지고 새싹이 살랑인다 →
    /// 0.50–0.95 왼쪽·오른쪽을 둘러본다 → 0.60–1.12 오른쪽 날개로 손을 흔든다 → 0.94 눈을 한 번 깜빡인다.
    struct Performance {
        /// 몸 전체의 높이(캔버스 단위, 음수가 위).
        var lift: Double = 0
        /// 몸 전체의 가로·세로 늘이기(발밑 기준). 내려앉을 때 찌부러진다.
        var stretchX: Double = 1
        var stretchY: Double = 1
        /// 몸 전체의 기울기(도). 발밑을 중심으로 돈다.
        var lean: Double = 0
        /// 오른쪽(화면 기준) 날개의 회전(도). 음수가 위로.
        var rightWing: Double = 0
        /// 왼쪽 날개의 회전(도). 양수가 위로.
        var leftWing: Double = 0
        /// 새싹의 회전(도). 줄기 밑동을 중심으로 돈다.
        var sprout: Double = 0
        /// 1이면 눈을 감는다.
        var blink: Double = 0

        /// 그림을 돌려 보며 밑동이 몸 밖으로 드러나지 않음을 확인한 범위.
        static let rightWingRange: ClosedRange<Double> = -16...18
        static let leftWingRange: ClosedRange<Double> = -20...20
        static let sproutRange: ClosedRange<Double> = -12...12
        /// 연기 전체의 길이(초). 기본 재생 시간(1.5초)에서 피오가 나타난 뒤 걷히기 전까지(약 1.32초) 안에 끝난다.
        static let duration: Double = 1.2

        @KeyframesBuilder<Performance>
        static var keyframes: some Keyframes<Performance> {
            KeyframeTrack(\.lift) {
                MoveKeyframe(-110)
                CubicKeyframe(0, duration: 0.24)
                CubicKeyframe(-18, duration: 0.14)
                CubicKeyframe(0, duration: 0.14)
                LinearKeyframe(0, duration: 0.68)
            }
            KeyframeTrack(\.stretchX) {
                MoveKeyframe(0.94)
                CubicKeyframe(0.96, duration: 0.22)
                CubicKeyframe(1.10, duration: 0.06)
                CubicKeyframe(0.97, duration: 0.12)
                SpringKeyframe(1, duration: 0.3, spring: .init(duration: 0.3, bounce: 0.3))
                LinearKeyframe(1, duration: 0.5)
            }
            KeyframeTrack(\.stretchY) {
                MoveKeyframe(1.07)
                CubicKeyframe(1.05, duration: 0.22)
                CubicKeyframe(0.88, duration: 0.06)
                CubicKeyframe(1.05, duration: 0.12)
                SpringKeyframe(1, duration: 0.3, spring: .init(duration: 0.3, bounce: 0.3))
                LinearKeyframe(1, duration: 0.5)
            }
            KeyframeTrack(\.lean) {
                LinearKeyframe(0, duration: 0.5)
                CubicKeyframe(-6, duration: 0.16)
                CubicKeyframe(5, duration: 0.2)
                SpringKeyframe(0, duration: 0.34, spring: .init(duration: 0.35, bounce: 0.2))
            }
            KeyframeTrack(\.rightWing) {
                MoveKeyframe(-12)
                CubicKeyframe(-14, duration: 0.2)
                CubicKeyframe(4, duration: 0.16)
                CubicKeyframe(0, duration: 0.24)
                CubicKeyframe(-14, duration: 0.12)
                CubicKeyframe(8, duration: 0.12)
                CubicKeyframe(-12, duration: 0.12)
                CubicKeyframe(4, duration: 0.1)
                SpringKeyframe(0, duration: 0.14, spring: .init(duration: 0.25, bounce: 0.2))
            }
            KeyframeTrack(\.leftWing) {
                MoveKeyframe(14)
                CubicKeyframe(16, duration: 0.2)
                CubicKeyframe(-6, duration: 0.16)
                SpringKeyframe(0, duration: 0.3, spring: .init(duration: 0.35, bounce: 0.25))
                LinearKeyframe(0, duration: 0.54)
            }
            KeyframeTrack(\.sprout) {
                MoveKeyframe(-8)
                CubicKeyframe(-10, duration: 0.24)
                CubicKeyframe(10, duration: 0.12)
                CubicKeyframe(-7, duration: 0.12)
                CubicKeyframe(4, duration: 0.12)
                SpringKeyframe(0, duration: 0.2, spring: .init(duration: 0.3, bounce: 0.2))
                CubicKeyframe(5, duration: 0.16)
                SpringKeyframe(0, duration: 0.24, spring: .init(duration: 0.3, bounce: 0.2))
            }
            KeyframeTrack(\.blink) {
                LinearKeyframe(0, duration: 0.94)
                MoveKeyframe(1)
                LinearKeyframe(1, duration: 0.1)
                MoveKeyframe(0)
            }
        }
    }

    /// 부위별 그림을 1254 캔버스의 같은 좌표에 겹친 피오. 그림 자리와 회전 중심은 부위를 나눌 때 맞춘 값이다.
    struct Figure: View {
        let width: CGFloat
        var pose = Performance()
        /// 의상을 입었으면 그 의상의 한 장짜리 그림. 이때는 날개·새싹·눈이 따로 움직이지 않고, 몸 전체의 연기(내려앉기·찌부러짐·기울기)만 한다.
        var outfitAsset: String? = nil

        struct Part {
            let asset: String
            let rect: CGRect
            let pivot: CGPoint
        }

        /// 그리는 순서대로(뒤에서 앞으로). 날개·발·새싹은 몸 뒤에 있어 밑동이 몸에 가려진다.
        static let parts: [Part] = [
            Part(asset: "wingLeft", rect: CGRect(x: 153, y: 716, width: 397, height: 351), pivot: CGPoint(x: 375, y: 810)),
            Part(asset: "wingRight", rect: CGRect(x: 797, y: 586, width: 336, height: 324), pivot: CGPoint(x: 940, y: 830)),
            Part(asset: "footLeft", rect: CGRect(x: 490, y: 1000, width: 131, height: 115), pivot: CGPoint(x: 550, y: 1010)),
            Part(asset: "footRight", rect: CGRect(x: 755, y: 965, width: 131, height: 115), pivot: CGPoint(x: 815, y: 975)),
            Part(asset: "sprout", rect: CGRect(x: 397, y: 114, width: 501, height: 328), pivot: CGPoint(x: 650, y: 430)),
            Part(asset: "body", rect: CGRect(x: 161, y: 247, width: 962, height: 947), pivot: CGPoint(x: 650, y: 740)),
            Part(asset: "eyeLeft", rect: CGRect(x: 503, y: 623, width: 94, height: 109), pivot: CGPoint(x: 550, y: 689)),
            Part(asset: "eyeRight", rect: CGRect(x: 771, y: 583, width: 88, height: 102), pivot: CGPoint(x: 815, y: 644)),
            Part(asset: "lidLeft", rect: CGRect(x: 500, y: 676, width: 99, height: 37), pivot: CGPoint(x: 550, y: 695)),
            Part(asset: "lidRight", rect: CGRect(x: 767, y: 632, width: 95, height: 35), pivot: CGPoint(x: 815, y: 649))
        ]
        /// 캔버스에서 피오가 보이는 자리를 가운데에 두는 정사각형. 보이는 그림은 x 280…1129, y 117…1115이고
        /// (부위 그림의 투명한 여백은 빼고), 날개가 돌 여유를 둔다.
        static let viewBox = CGRect(x: 175, y: 86, width: 1060, height: 1060)
        static let groundY: CGFloat = 1108
        static let sproutAspect: CGFloat = 328 / 501

        var body: some View {
            let s = width / Self.viewBox.width
            ZStack(alignment: .topLeading) {
                // 발밑의 옅은 그림자. 몸이 기울어도 땅에 붙어 있다.
                Ellipse()
                    .fill(Color.black.opacity(0.07 * max(0.3, 1 + pose.lift / 160)))
                    .frame(width: 470 * s, height: 34 * s)
                    .blur(radius: 10 * s)
                    .offset(x: (690 - 235 - Self.viewBox.minX) * s, y: (Self.groundY - 17 - Self.viewBox.minY) * s)
                ZStack(alignment: .topLeading) {
                    if let outfitAsset {
                        // 의상 그림은 1254 정사각형 안에 피오가 그려져 있다. 발밑을 같은 땅에 맞추고 가운데에 둔다.
                        Image(outfitAsset)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: width * 1.05, height: width * 1.05)
                            .offset(x: -width * 0.025, y: (Self.groundY - Self.viewBox.minY) * s - width * 1.05 * 0.94)
                    } else {
                    ForEach(Self.parts, id: \.asset) { part in
                        Image("routimori_splash_pio_" + part.asset)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: part.rect.width * s, height: part.rect.height * s)
                            .rotationEffect(.degrees(angle(of: part.asset)),
                                            anchor: UnitPoint(x: (part.pivot.x - part.rect.minX) / part.rect.width,
                                                              y: (part.pivot.y - part.rect.minY) / part.rect.height))
                            .opacity(opacity(of: part.asset))
                            .offset(x: (part.rect.minX - Self.viewBox.minX) * s, y: (part.rect.minY - Self.viewBox.minY) * s)
                    }
                    }
                }
                .frame(width: width, height: width, alignment: .topLeading)
                .scaleEffect(x: pose.stretchX, y: pose.stretchY, anchor: Self.footAnchor)
                .rotationEffect(.degrees(pose.lean), anchor: Self.footAnchor)
                .offset(y: pose.lift * s)
            }
            .frame(width: width, height: width, alignment: .topLeading)
        }

        static var footAnchor: UnitPoint {
            UnitPoint(x: (688 - viewBox.minX) / viewBox.width, y: (groundY - viewBox.minY) / viewBox.height)
        }

        private func angle(of asset: String) -> Double {
            switch asset {
            case "wingRight": pose.rightWing
            case "wingLeft": pose.leftWing
            case "sprout": pose.sprout
            default: 0
            }
        }

        private func opacity(of asset: String) -> Double {
            if asset.hasPrefix("lid") { return pose.blink }
            if asset.hasPrefix("eye") { return 1 - pose.blink }
            return 1
        }
    }
}
