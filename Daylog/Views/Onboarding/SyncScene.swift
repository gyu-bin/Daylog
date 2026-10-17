import SwiftUI

/// 첫 동기화 화면 위쪽의 움직이는 그림. 장면마다 배경·구름·새싹이 자세·효과가 다르다(`SyncSceneMotion`이 계산한다).
///
/// 그리는 방법: 구름·카드·수첩·체크·별·빗방울 같은 조각은 처음에 한 번만 그림으로 만들고(아래의 SwiftUI 조각),
/// 새싹이는 공식 원화 레이어(몸·눈·입·잎·발)를 그대로 쓴다. 움직임은 `SyncSceneStage`가 Core Animation 키프레임으로 걸어
/// 시스템이 그린다: 앱은 매 프레임 SwiftUI 화면을 다시 계산하지 않는다(예전 `TimelineView` 방식은 매 프레임 창 전체를 다시 배치했다).
/// 원화를 늘리거나 비틀어 새 자세를 만들지 않는다: 몸통 전체를 기울이고 띄우고 발밑 기준으로 조금 누를 뿐이다.
/// 움직임 줄이기를 켜면 장면의 한 순간을 멈춘 그림으로 보여 주고, 화면이 앞에 있지 않거나 사라지면 애니메이션을 내린다.
struct SyncScene: View {
    let kind: SyncSceneKind
    /// 장면의 높이(pt). 가로도 같다.
    var height: CGFloat = 340
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @State private var isVisible = false

    var body: some View {
        Group {
            if PioCharacter.isEnabled {
                RoutimoriSyncScene(kind: kind, height: height)
            } else {
                SyncLayerView(
                    configuration: SyncSceneStage.Configuration(
                        kind: kind, height: height, dark: colorScheme == .dark, scale: displayScale, reduceMotion: reduceMotion
                    ),
                    isAnimating: isVisible && !reduceMotion && scenePhase == .active
                )
            }
        }
        .frame(width: height, height: height)
        .accessibilityHidden(true)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

/// 기록을 받는 동안 글 아래에서 부드럽게 움직이는 점 세 개(진행률이 아니다). 장면과 같이 Core Animation으로 움직인다.
struct SyncWaitingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    var body: some View {
        SyncDotsLayerView(isAnimating: isVisible && !reduceMotion && scenePhase == .active)
            .frame(width: SyncDotsStage.width, height: SyncDotsStage.height)
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
            .accessibilityElement()
            .accessibilityLabel("동기화 중")
    }
}

/// 화면 전체의 배경 색. 장면마다 다르고, 다크 모드에서는 어둡게.
enum SyncSceneBackground {
    static func colors(_ kind: SyncSceneKind, dark: Bool) -> [Color] {
        switch (kind, dark) {
        case (.receiving, false): return [Color(red: 0.84, green: 0.92, blue: 1), Color(red: 0.96, green: 0.98, blue: 1)]
        case (.receiving, true): return [Color(red: 0.1, green: 0.16, blue: 0.28), Color(red: 0.06, green: 0.08, blue: 0.12)]
        case (.ready, false): return [Color(red: 0.89, green: 0.97, blue: 0.82), Color(red: 0.97, green: 0.99, blue: 0.94)]
        case (.ready, true): return [Color(red: 0.1, green: 0.21, blue: 0.12), Color(red: 0.06, green: 0.09, blue: 0.07)]
        case (.trouble, false): return [Color(red: 0.88, green: 0.9, blue: 0.94), Color(red: 0.96, green: 0.97, blue: 0.98)]
        case (.trouble, true): return [Color(red: 0.15, green: 0.17, blue: 0.21), Color(red: 0.08, green: 0.09, blue: 0.11)]
        }
    }
}

// MARK: - 조각 (한 번만 그림으로 만든다)

/// 장면 뒤의 둥근 빛: 하늘(받는 중), 햇살(완료), 흐린 하늘(문제).
struct SyncBackdrop: View {
    let kind: SyncSceneKind
    let unit: CGFloat
    let dark: Bool

    var body: some View {
        let color: Color = switch kind {
        case .receiving: dark ? Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.22) : Color.white.opacity(0.7)
        case .ready: dark ? Color(red: 0.55, green: 0.8, blue: 0.4).opacity(0.18) : Color.white.opacity(0.75)
        case .trouble: dark ? Color.white.opacity(0.06) : Color.white.opacity(0.55)
        }
        Ellipse()
            .fill(RadialGradient(colors: [color, .clear], center: .center, startRadius: 0, endRadius: 170 * unit))
            .frame(width: 340 * unit, height: 300 * unit)
    }
}

/// 둥근 구름. 받는 중에는 하얗고 가운데에 iCloud 표시가 있고, 문제가 있을 때는 회색에 순한 얼굴이 있다.
struct SyncCloud: View {
    enum Tone { case white, gray }
    let unit: CGFloat
    let tone: Tone
    let dark: Bool

    var body: some View {
        let u = unit
        let fill: Color = switch tone {
        case .white: dark ? Color(red: 0.88, green: 0.93, blue: 1) : .white
        case .gray: dark ? Color(red: 0.52, green: 0.56, blue: 0.63) : Color(red: 0.74, green: 0.77, blue: 0.82)
        }
        ZStack {
            CloudShape()
                .fill(fill)
                .frame(width: 176 * u, height: 98 * u)
                .shadow(color: .black.opacity(tone == .white ? 0.08 : 0.12), radius: 10 * u, y: 5 * u)
            switch tone {
            case .white:
                Image(systemName: "icloud.fill")
                    .font(.system(size: 42 * u, weight: .regular))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(red: 0.42, green: 0.72, blue: 1), Color(red: 0.13, green: 0.47, blue: 0.96)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .offset(y: 6 * u)
            case .gray:
                // 순한 얼굴: 동그란 눈 두 개와 살짝 처진 입. 무섭지 않게 작고 흐리게.
                let ink = Color(red: 0.33, green: 0.36, blue: 0.42)
                HStack(spacing: 30 * u) {
                    Capsule().fill(ink).frame(width: 7 * u, height: 10 * u)
                    Capsule().fill(ink).frame(width: 7 * u, height: 10 * u)
                }
                .offset(y: 8 * u)
                Capsule()
                    .trim(from: 0.05, to: 0.45)
                    .stroke(ink, style: StrokeStyle(lineWidth: 2.4 * u, lineCap: .round))
                    .frame(width: 16 * u, height: 12 * u)
                    .rotationEffect(.degrees(180))
                    .offset(y: 26 * u)
            }
        }
        .frame(width: 240 * u, height: 130 * u)
    }
}

/// 몽실몽실한 구름 모양(겹친 원과 둥근 밑동).
struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
            path.addEllipse(in: CGRect(x: rect.minX + x * w - r * w, y: rect.minY + y * h - r * w, width: 2 * r * w, height: 2 * r * w))
        }
        circle(0.2, 0.66, 0.16)
        circle(0.38, 0.42, 0.22)
        circle(0.62, 0.38, 0.24)
        circle(0.82, 0.64, 0.16)
        path.addRoundedRect(
            in: CGRect(x: rect.minX + 0.12 * w, y: rect.minY + 0.5 * h, width: 0.78 * w, height: 0.48 * h),
            cornerSize: CGSize(width: 0.24 * h, height: 0.24 * h)
        )
        return path
    }
}

/// 둥근 빛(구름 뒤의 하얀 빛, 체크 뒤의 햇살).
struct SyncGlow: View {
    let color: Color
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Ellipse()
            .fill(RadialGradient(colors: [color, .clear], center: .center, startRadius: 0, endRadius: max(width, height) / 2))
            .frame(width: width, height: height)
    }
}

/// 구름에서 내려오는 기록 카드 한 장(체크·달력·루틴·통계).
struct SyncRecordCard: View {
    let kind: SyncFallingCard.Kind
    let unit: CGFloat

    var body: some View {
        let (symbol, color): (String, Color) = switch kind {
        case .check: ("checkmark.square.fill", Color(red: 0.3, green: 0.72, blue: 0.4))
        case .calendar: ("calendar", Color(red: 0.95, green: 0.45, blue: 0.4))
        case .routine: ("checklist", Color(red: 0.45, green: 0.5, blue: 0.95))
        case .chart: ("chart.bar.fill", Color(red: 0.25, green: 0.55, blue: 0.95))
        }
        RoundedRectangle(cornerRadius: 7 * unit, style: .continuous)
            .fill(Color.white)
            .frame(width: 32 * unit, height: SyncSceneMotion.cardHeight * unit)
            .shadow(color: .black.opacity(0.12), radius: 4 * unit, y: 2 * unit)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 15 * unit, weight: .semibold))
                    .foregroundStyle(color)
            }
    }
}

/// 수첩에 기록이 들어올 때의 반짝임, 준비 완료의 별.
struct SyncSparkle: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(Color(red: 1, green: 0.8, blue: 0.25))
    }
}

/// 준비 완료의 큰 초록 체크.
struct SyncCheck: View {
    let unit: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.42, green: 0.82, blue: 0.42), Color(red: 0.24, green: 0.66, blue: 0.3)],
                    startPoint: .top, endPoint: .bottom
                ))
                .shadow(color: Color(red: 0.2, green: 0.55, blue: 0.25).opacity(0.3), radius: 8 * unit, y: 4 * unit)
            Image(systemName: "checkmark")
                .font(.system(size: 40 * unit, weight: .heavy))
                .foregroundStyle(.white)
        }
        .frame(width: 84 * unit, height: 84 * unit)
    }
}

/// 회색 구름에서 떨어지는 빗방울 하나.
struct SyncRaindrop: View {
    let unit: CGFloat

    var body: some View {
        Capsule()
            .fill(Color(red: 0.55, green: 0.72, blue: 0.95))
            .frame(width: 6 * unit, height: 14 * unit)
    }
}

/// 머리 위에 나타나는 물음표.
struct SyncQuestion: View {
    let unit: CGFloat

    var body: some View {
        Text(verbatim: "?")
            .font(.system(size: 30 * unit, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(red: 0.42, green: 0.55, blue: 0.82))
    }
}

/// 바닥의 작은 새싹 장식 하나(문제가 있을 때는 빛바랜 색). 밑동을 기준으로 살랑인다.
struct SyncSprout: View {
    let kind: SyncSceneKind
    let unit: CGFloat

    var body: some View {
        let color: Color = kind == .trouble ? Color(red: 0.55, green: 0.7, blue: 0.6) : Color(red: 0.42, green: 0.74, blue: 0.4)
        let u = unit
        ZStack(alignment: .bottom) {
            Capsule().fill(color).frame(width: 2.5 * u, height: 14 * u)
            Image(systemName: "leaf.fill")
                .font(.system(size: 12 * u))
                .foregroundStyle(color)
                .rotationEffect(.degrees(-40))
                .offset(x: -6 * u, y: -10 * u)
            Image(systemName: "leaf.fill")
                .font(.system(size: 12 * u))
                .foregroundStyle(color)
                .scaleEffect(x: -1)
                .rotationEffect(.degrees(40))
                .offset(x: 6 * u, y: -10 * u)
        }
        .frame(width: 34 * u, height: 30 * u, alignment: .bottom)
    }
}

/// 새싹이가 든 초록 수첩. 기록을 받는 동안은 펼쳐 들고(넘어가는 쪽은 `SyncNotebookPage`로 따로 움직인다), 준비가 끝나면 덮어서 꼭 안는다.
/// 기울기는 그림 밖(레이어)에서 준다.
struct SyncNotebook: View {
    enum Style: Equatable { case open, closed }

    let style: Style
    let size: CGFloat

    static let cover = Color(red: 0.33, green: 0.66, blue: 0.36)
    static let coverDark = Color(red: 0.24, green: 0.52, blue: 0.27)
    static let paper = Color(red: 1, green: 0.99, blue: 0.95)

    /// 펼친 수첩의 크기와 한 쪽의 크기.
    static func openSize(_ size: CGFloat) -> CGSize { CGSize(width: 0.6 * size, height: 0.27 * size) }
    static func pageSize(_ size: CGFloat) -> CGSize {
        let open = openSize(size)
        return CGSize(width: open.width / 2 - 0.035 * size, height: open.height - 0.05 * size)
    }

    var body: some View {
        switch style {
        case .open:
            let open = Self.openSize(size), page = Self.pageSize(size)
            ZStack {
                RoundedRectangle(cornerRadius: 0.035 * size, style: .continuous)
                    .fill(Self.cover)
                    .shadow(color: .black.opacity(0.15), radius: 0.02 * size, y: 0.01 * size)
                HStack(spacing: 0.012 * size) {
                    SyncNotebookPage(size: size, page: page, lines: 3)
                    SyncNotebookPage(size: size, page: page, lines: 2)
                }
                Rectangle()
                    .fill(Self.coverDark)
                    .frame(width: 0.012 * size, height: open.height - 0.03 * size)
            }
            .frame(width: open.width, height: open.height)
        case .closed:
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 0.04 * size, style: .continuous)
                    .fill(LinearGradient(colors: [Self.cover, Self.coverDark], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .black.opacity(0.15), radius: 0.02 * size, y: 0.01 * size)
                RoundedRectangle(cornerRadius: 0.02 * size, style: .continuous)
                    .fill(Self.coverDark)
                    .frame(width: 0.06 * size)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 0.13 * size, weight: .semibold))
                    .foregroundStyle(Self.paper.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .padding(.leading, 0.05 * size)
            }
            .frame(width: 0.34 * size, height: 0.32 * size)
        }
    }
}

/// 수첩의 한 쪽(줄 몇 개가 적힌 종이).
struct SyncNotebookPage: View {
    let size: CGFloat
    let page: CGSize
    let lines: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 0.015 * size, style: .continuous)
            .fill(SyncNotebook.paper)
            .frame(width: page.width, height: page.height)
            .overlay(alignment: .top) {
                VStack(alignment: .leading, spacing: 0.035 * size) {
                    ForEach(0..<lines, id: \.self) { index in
                        Capsule()
                            .fill(Color(red: 0.55, green: 0.75, blue: 0.55).opacity(0.55))
                            .frame(width: page.width * (index == lines - 1 ? 0.45 : 0.7), height: 0.012 * size)
                    }
                }
                .padding(.top, 0.035 * size)
            }
    }
}
