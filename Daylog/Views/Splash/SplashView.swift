#if os(iOS)
import SwiftUI
import UIKit

/// 앱을 열 때 한 번 보여 주는 스플래시(iPhone·iPad). 실제 화면 위를 덮고 있다가 약 1초 뒤 걷힌다.
///
/// - 첫 장면은 시스템 Launch Screen과 같다(같은 배경색, 한가운데의 같은 잎사귀). 그래서 넘어올 때 번쩍이거나 튀지 않는다.
/// - 색은 앱의 테마 설정이 아니라 시스템의 라이트/다크를 따른다. Launch Screen이 시스템 모드로 그려지기 때문이다.
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
    /// Launch Screen을 그린 시스템의 모드. 앱의 테마 설정과 다를 수 있다.
    @State private var isDark = UIScreen.main.traitCollection.userInterfaceStyle == .dark

    /// Launch Screen의 잎사귀 크기(그림의 원래 크기).
    static let launchLeafSize: CGFloat = 64

    var body: some View {
        GeometryReader { proxy in
            let metrics = Metrics(size: proxy.size, reducesMotion: reduceMotion)
            ZStack {
                background
                if !reduceMotion {
                    ripples(metrics)
                    leaflets(metrics)
                }
                leaf(metrics)
                titles(metrics)
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

    private var background: some View {
        Self.color(named: "SplashBackground", isDark: isDark)
    }

    /// 잎사귀 뒤에서 잔잔하게 퍼지는 원 둘.
    private func ripples(_ metrics: Metrics) -> some View {
        let tint = Self.leafTint
        return ZStack {
            ForEach(0..<2, id: \.self) { index in
                let reach = metrics.rippleDiameter * (index == 0 ? 1 : 0.68)
                Circle()
                    .strokeBorder(tint.opacity(0.16), lineWidth: 1)
                    .background(Circle().fill(tint.opacity(index == 0 ? 0.035 : 0.05)))
                    .frame(width: reach, height: reach)
                    .scaleEffect(stage >= .grown ? 1 : 0.42)
                    // 퍼지며 나타났다가, 글자가 나올 때 물러난다.
                    .opacity(stage == .grown ? 1 : 0)
            }
        }
        .offset(y: metrics.leafOffset(stage))
    }

    /// 둘레에 흩어진 작은 잎들. 살짝 바깥으로 밀려나며 나타난다(돌거나 반짝이지 않는다).
    private func leaflets(_ metrics: Metrics) -> some View {
        ZStack {
            ForEach(Metrics.leaflets.indices, id: \.self) { index in
                let item = Metrics.leaflets[index]
                let spread: CGFloat = stage >= .grown ? 1 : 0.86
                Image("SplashLeaf")
                    .resizable()
                    .frame(width: item.size * metrics.scale, height: item.size * metrics.scale)
                    .rotationEffect(.degrees(item.angle))
                    .offset(x: item.x * metrics.scale * spread, y: item.y * metrics.scale * spread)
                    .opacity(stage >= .grown ? item.opacity : 0)
            }
        }
        .offset(y: metrics.groupOffset)
    }

    private func leaf(_ metrics: Metrics) -> some View {
        Image("SplashLeaf")
            .resizable()
            .frame(width: metrics.leafFinalSize, height: metrics.leafFinalSize)
            // 큰 크기로 그려 두고 줄여서 시작한다(커질 때 흐려지지 않게).
            .scaleEffect(metrics.leafSize(stage) / metrics.leafFinalSize)
            // 올라가는 동안 살짝 기울었다가 제자리에서 멈춘다.
            .rotationEffect(.degrees(stage == .logo && !reduceMotion ? -5 : 0), anchor: .bottomLeading)
            .offset(y: metrics.leafOffset(stage))
    }

    private func titles(_ metrics: Metrics) -> some View {
        let shown = stage >= .logo
        // 잎사귀가 위로 비켜난 뒤에 나타난다(올라가는 잎사귀와 겹치지 않게). 문구는 이름보다 한 박자 늦다.
        let nameAnimation: Animation? = shown ? .easeOut(duration: 0.20).delay(reduceMotion ? 0 : SplashTimeline.titleDelay) : nil
        let taglineAnimation: Animation? = shown ? .easeOut(duration: 0.20).delay(reduceMotion ? 0.06 : SplashTimeline.titleDelay + 0.08) : nil
        return VStack(spacing: 6 * metrics.scale) {
            Text("Daylog")
                .font(.system(size: 36 * metrics.scale, weight: .semibold, design: .rounded))
                .foregroundStyle(isDark ? Color(red: 0.91, green: 0.96, blue: 0.93) : Color(red: 0.13, green: 0.31, blue: 0.24))
                .opacity(shown ? 1 : 0)
                .offset(y: shown || reduceMotion ? 0 : 8 * metrics.scale)
                .animation(nameAnimation, value: shown)
            Text("하루를, 조금 더 가볍게")
                .font(.system(size: 15 * metrics.scale, weight: .regular))
                .foregroundStyle(isDark ? Color(red: 0.62, green: 0.73, blue: 0.68) : Color(red: 0.42, green: 0.54, blue: 0.48))
                .opacity(shown ? 1 : 0)
                .animation(taglineAnimation, value: shown)
        }
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .fixedSize()
        .offset(y: metrics.titleOffset)
    }

    // MARK: - 진행

    private func start() {
        guard !hasStarted else { return }
        hasStarted = true
        isDark = UIScreen.main.traitCollection.userInterfaceStyle == .dark
        #if DEBUG
        // 시간 확인용: 화면이 만들어진 뒤 스플래시가 움직이기 시작할 때까지 걸린 시간.
        if UserDefaults.standard.bool(forKey: "DaylogDebugSplashLog") {
            print(String(format: "DAYLOG_SPLASH start +%.3fs after first view", ProcessInfo.processInfo.systemUptime - SplashPolicy.claimedAt))
        }
        #endif
        #if DEBUG
        // 화면 검증용: `-DaylogDebugSplashHold logo`처럼 한 장면에서 멈춰 둔다(걷히지 않는다).
        if let name = UserDefaults.standard.string(forKey: "DaylogDebugSplashHold"),
           let held = SplashTimeline.Stage.allCases.first(where: { "\($0)" == name }) {
            stage = held
            return
        }
        #endif
        let timeline = SplashTimeline.make(reduceMotion: reduceMotion)
        Task { @MainActor in
            var elapsed = 0.0
            for step in timeline.steps {
                try? await Task.sleep(for: .seconds(max(step.at - elapsed, 0)))
                elapsed = step.at
                if step.stage == .leaving { onLeaving() }
                withAnimation(Self.animation(for: step, reducesMotion: timeline.reducesMotion)) {
                    stage = step.stage
                }
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
        case .settled: return .spring(duration: step.duration, bounce: 0.35)
        case .leaving: return .easeIn(duration: step.duration)
        // 잎사귀는 빠르게 올라가 천천히 멈춘다(글자 자리를 먼저 비워 준다).
        case .logo where !reducesMotion: return .timingCurve(0.3, 0, 0.2, 1, duration: step.duration)
        default: return reducesMotion ? .linear(duration: step.duration) : .easeInOut(duration: step.duration)
        }
    }

    // MARK: - 색

    static let leafTint = Color(red: 0.26, green: 0.72, blue: 0.56)

    /// 에셋의 색을 시스템 모드로 풀어서 쓴다(앱의 테마 설정을 타지 않게).
    static func color(named name: String, isDark: Bool) -> Color {
        let traits = UITraitCollection(userInterfaceStyle: isDark ? .dark : .light)
        guard let color = UIColor(named: name)?.resolvedColor(with: traits) else { return Color(uiColor: .systemBackground) }
        return Color(uiColor: color)
    }
}

extension SplashView {
    /// 화면 크기에 맞춘 치수. iPhone 기준(짧은 변 402pt)으로 잡고 iPad에서는 조금 키운다.
    struct Metrics {
        let scale: CGFloat
        let reducesMotion: Bool

        init(size: CGSize, reducesMotion: Bool) {
            scale = min(max(min(size.width, size.height) / 402, 0.9), 1.5)
            self.reducesMotion = reducesMotion
        }

        /// 잎사귀의 마지막 크기.
        var leafFinalSize: CGFloat { reducesMotion ? SplashView.launchLeafSize : 100 * scale }
        var rippleDiameter: CGFloat { 220 * scale }
        /// 잎사귀·글자 묶음이 놓이는 높이(화면 한가운데보다 조금 위).
        var groupOffset: CGFloat { reducesMotion ? 0 : -40 * scale }
        /// 글자의 세로 위치(화면 한가운데 기준).
        var titleOffset: CGFloat { reducesMotion ? 78 : groupOffset + 62 * scale }

        func leafSize(_ stage: SplashTimeline.Stage) -> CGFloat {
            guard !reducesMotion else { return SplashView.launchLeafSize }
            switch stage {
            case .start: return SplashView.launchLeafSize
            case .grown: return 86 * scale
            case .logo, .settled, .leaving: return leafFinalSize
            }
        }

        /// 잎사귀의 세로 위치. 처음에는 Launch Screen과 같은 한가운데.
        func leafOffset(_ stage: SplashTimeline.Stage) -> CGFloat {
            guard !reducesMotion else { return 0 }
            return stage >= .logo ? groupOffset - 48 * scale : 0
        }

        struct Leaflet {
            let x: CGFloat, y: CGFloat, size: CGFloat, angle: Double, opacity: Double
        }

        /// 둘레의 작은 잎들(묶음의 한가운데 기준, iPhone 치수).
        static let leaflets: [Leaflet] = [
            Leaflet(x: 62, y: -150, size: 13, angle: 18, opacity: 0.34),
            Leaflet(x: -98, y: -82, size: 12, angle: -62, opacity: 0.28),
            Leaflet(x: 92, y: -28, size: 12, angle: 40, opacity: 0.30),
            Leaflet(x: -104, y: 34, size: 10, angle: -24, opacity: 0.22),
            Leaflet(x: 104, y: 70, size: 9, angle: 64, opacity: 0.18)
        ]
    }
}
#endif
