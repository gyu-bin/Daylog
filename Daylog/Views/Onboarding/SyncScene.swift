import SwiftUI

/// 첫 동기화 화면 위쪽의 움직이는 그림. 장면마다 배경·구름·새싹이 자세·효과가 다르다(`SyncSceneMotion`이 계산한다).
///
/// 새싹이는 공식 원화의 레이어(몸·눈·입·잎·발)를 겹쳐 그리고, 수첩·기록 카드·구름·별·빗방울은 SwiftUI로 그린다.
/// 원화를 늘리거나 비틀어 새 자세를 만들지 않는다: 몸통 전체를 기울이고 띄우고 발밑 기준으로 조금 누를 뿐이다.
/// 움직임 줄이기를 켜면 장면의 한 순간을 멈춘 그림으로 보여 주고, 화면이 앞에 있지 않으면 멈춘다.
struct SyncScene: View {
    let kind: SyncSceneKind
    /// 장면의 높이(pt). 가로는 높이와 같게 그린다.
    var height: CGFloat = 340
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var start = Date()

    private var unit: CGFloat { height / 340 }

    var body: some View {
        let paused = reduceMotion || scenePhase != .active
        // 1초에 24번 그린다(화면이 앞에 없거나 움직임 줄이기면 멈춘다).
        TimelineView(.animation(minimumInterval: 1 / 24, paused: paused)) { context in
            let t = reduceMotion ? SyncSceneMotion.stillTime(kind) : max(0, context.date.timeIntervalSince(start))
            canvas(SyncSceneMotion.frame(kind, at: t))
        }
        .frame(width: 340 * unit, height: height)
        .accessibilityHidden(true)
        .onAppear { start = Date() }
    }

    private var dark: Bool { colorScheme == .dark }

    @ViewBuilder
    private func canvas(_ frame: SyncSceneFrame) -> some View {
        let u = unit
        let mascot = 128 * u
        let ground = 328 * u
        ZStack(alignment: .top) {
            backdrop(frame)
            SyncSprouts(kind: kind, unit: u, sway: frame.saessagi.leaf)
                .offset(y: ground - 26 * u)
            switch kind {
            case .receiving:
                SyncCloud(unit: u, tone: .white, glow: frame.glow, face: false)
                    .overlay {
                        Image(systemName: "icloud.fill")
                            .font(.system(size: 42 * u, weight: .regular))
                            .foregroundStyle(LinearGradient(
                                colors: [Color(red: 0.42, green: 0.72, blue: 1), Color(red: 0.13, green: 0.47, blue: 0.96)],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .offset(y: 6 * u)
                    }
                    .offset(x: frame.cloudX * u, y: (14 + frame.cloudY) * u)
            case .ready:
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(red: 1, green: 0.93, blue: 0.55).opacity(dark ? 0.35 : 0.75), .clear],
                        center: .center, startRadius: 0, endRadius: 120 * u
                    ))
                    .frame(width: 240 * u, height: 240 * u)
                    .opacity(frame.glow)
                    .offset(y: -50 * u)
                SyncCheck(unit: u)
                    .scaleEffect(frame.check)
                    .opacity(min(1, frame.check * 3))
                    .offset(y: 22 * u)
                SyncStars(values: frame.stars, unit: u)
            case .trouble:
                SyncCloud(unit: u, tone: .gray, glow: 0, face: true)
                    .offset(x: frame.cloudX * u, y: (8 + frame.cloudY) * u)
                ForEach(0..<frame.drops.count, id: \.self) { index in
                    SyncRaindrop(progress: frame.drops[index], unit: u)
                        .offset(x: (frame.cloudX + [-30, 4, 32][index % 3]) * u, y: (112 + frame.cloudY) * u)
                }
            }
            SyncSaessagi(size: mascot, pose: frame.saessagi, book: book(frame))
                .offset(y: ground - mascot - SaessagiRenderer.padding)
            if kind == .trouble {
                // 머리 위(오른쪽)에 톡 나타나는 물음표.
                Text("?")
                    .font(.system(size: 30 * u, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.42, green: 0.55, blue: 0.82))
                    .scaleEffect(frame.question)
                    .rotationEffect(.degrees(frame.questionTilt))
                    .opacity(min(1, frame.question * 2))
                    .offset(x: 58 * u, y: ground - mascot - 6 * u)
            }
            if kind == .receiving {
                // 카드는 새싹이 앞으로 내려와 수첩에 들어간다.
                ForEach(Array(frame.cards.enumerated()), id: \.offset) { _, card in
                    SyncRecordCard(card: card, unit: u)
                        .modifier(CardFlight(card: card, unit: u, book: bookCenter(frame, mascot: mascot, ground: ground)))
                }
            }
            if kind == .receiving, frame.bookSparkle > 0 {
                let point = bookCenter(frame, mascot: mascot, ground: ground)
                SyncSparkle(unit: u)
                    .scaleEffect(0.4 + 0.8 * frame.bookSparkle)
                    .opacity(frame.bookSparkle)
                    .offset(x: point.x + 26 * u, y: point.y - 26 * u)
            }
        }
        .frame(width: 340 * u, height: height, alignment: .top)
    }

    private func book(_ frame: SyncSceneFrame) -> SyncNotebook.Style? {
        switch kind {
        case .receiving: return .open(flip: frame.pageFlip)
        case .ready: return .closed
        case .trouble: return nil
        }
    }

    /// 수첩의 가운데(장면 안, 위쪽 가운데가 원점). 카드는 여기로 내려와 사라진다.
    private func bookCenter(_ frame: SyncSceneFrame, mascot: CGFloat, ground: CGFloat) -> CGPoint {
        let anchor = SyncSaessagi.bookAnchor(size: mascot)
        let side = mascot + SaessagiRenderer.padding * 2
        return CGPoint(x: (anchor.x - 0.5) * side, y: ground - mascot - SaessagiRenderer.padding + anchor.y * side)
    }

    @ViewBuilder
    private func backdrop(_ frame: SyncSceneFrame) -> some View {
        // 장면 뒤의 둥근 빛: 하늘(받는 중), 햇살(완료), 흐린 하늘(문제).
        let color: Color = switch kind {
        case .receiving: dark ? Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.22) : Color.white.opacity(0.7)
        case .ready: dark ? Color(red: 0.55, green: 0.8, blue: 0.4).opacity(0.18) : Color.white.opacity(0.75)
        case .trouble: dark ? Color.white.opacity(0.06) : Color.white.opacity(0.55)
        }
        Ellipse()
            .fill(RadialGradient(colors: [color, .clear], center: .center, startRadius: 0, endRadius: 170 * unit))
            .frame(width: 340 * unit, height: 300 * unit)
            .offset(y: 30 * unit)
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

// MARK: - 새싹이

/// 공식 기본 모습의 레이어를 겹친 새싹이. 몸통(몸·얼굴·잎·수첩)이 함께 기울고, 눈은 눈 가운데를 기준으로 감고, 잎은 줄기 밑동을 기준으로 돈다.
struct SyncSaessagi: View {
    let size: CGFloat
    let pose: SyncSaessagiPose
    var book: SyncNotebook.Style?
    @Environment(\.displayScale) private var displayScale

    /// 수첩을 드는 자리(원화 1024 기준): 두 손이 배 앞에 모인 곳.
    static let bookSource = CGPoint(x: 512, y: 770)

    static func bookAnchor(size: CGFloat) -> CGPoint {
        SaessagiRenderer.unitPoint(of: bookSource, pose: .idle, size: size)
    }

    private func image(_ asset: String) -> CGImage? {
        SaessagiRenderer.image(asset: asset, pose: .idle, size: size, displayScale: displayScale)
    }

    /// 원화 위의 점(1024 기준)을 그림 틀 안의 기준점으로.
    private func anchor(_ point: CGPoint) -> UnitPoint {
        let unit = SaessagiRenderer.unitPoint(of: point, pose: .idle, size: size)
        return UnitPoint(x: unit.x, y: unit.y)
    }

    var body: some View {
        let layers = SaessagiIdleLayers.self
        if let bodyImage = image(layers.body), let eyes = image(layers.eyes), let mouth = image(layers.mouth),
           let leaf = image(layers.leaf), let footLeft = image(layers.footLeft), let footRight = image(layers.footRight) {
            let side = size + SaessagiRenderer.padding * 2
            let content = SaessagiPose.idle.content
            let feet = anchor(CGPoint(x: content.midX, y: content.maxY))
            let bookPoint = Self.bookAnchor(size: size)
            ZStack {
                Image(decorative: footLeft, scale: displayScale)
                Image(decorative: footRight, scale: displayScale)
                ZStack {
                    Image(decorative: bodyImage, scale: displayScale)
                    ZStack {
                        Image(decorative: mouth, scale: displayScale)
                        Image(decorative: eyes, scale: displayScale)
                            .scaleEffect(x: 1, y: pose.eyes, anchor: anchor(SaessagiIdleLayers.eyeCenter))
                    }
                    .offset(x: pose.faceX * size, y: pose.faceY * size)
                    Image(decorative: leaf, scale: displayScale)
                        .rotationEffect(.degrees(pose.leaf), anchor: anchor(SaessagiIdleLayers.leafPivot))
                    if let book {
                        SyncNotebook(style: book, size: size)
                            .position(x: bookPoint.x * side, y: (bookPoint.y - pose.bookLift + (book == .closed ? 0.035 : 0)) * side)
                    }
                }
                .frame(width: side, height: side)
                .rotationEffect(.degrees(pose.tilt), anchor: anchor(SaessagiIdleLayers.hip))
            }
            .frame(width: side, height: side)
            .scaleEffect(x: pose.squashX, y: pose.squashY, anchor: feet)
            .offset(y: -pose.lift * size)
        } else {
            SaessagiView(pose: .idle, size: size)
        }
    }
}

/// 새싹이가 든 초록 수첩. 기록을 받는 동안은 펼쳐 들고 가끔 쪽을 넘기고, 준비가 끝나면 덮어서 꼭 안는다.
struct SyncNotebook: View {
    enum Style: Equatable {
        /// 펼친 수첩. `flip`은 오른쪽 쪽이 넘어가는 정도(0…1).
        case open(flip: Double)
        case closed
    }

    let style: Style
    let size: CGFloat

    private let cover = Color(red: 0.33, green: 0.66, blue: 0.36)
    private let coverDark = Color(red: 0.24, green: 0.52, blue: 0.27)
    private let paper = Color(red: 1, green: 0.99, blue: 0.95)

    var body: some View {
        switch style {
        case .open(let flip):
            let width = 0.6 * size, height = 0.27 * size
            ZStack {
                RoundedRectangle(cornerRadius: 0.035 * size, style: .continuous)
                    .fill(cover)
                    .shadow(color: .black.opacity(0.15), radius: 0.02 * size, y: 0.01 * size)
                HStack(spacing: 0.012 * size) {
                    page(width: width / 2 - 0.035 * size, height: height - 0.05 * size, lines: 3)
                    page(width: width / 2 - 0.035 * size, height: height - 0.05 * size, lines: 2)
                }
                Rectangle()
                    .fill(coverDark)
                    .frame(width: 0.012 * size, height: height - 0.03 * size)
                if flip > 0, flip < 1 {
                    // 넘어가는 쪽: 가운데(책등)를 축으로 오른쪽에서 왼쪽으로.
                    page(width: width / 2 - 0.035 * size, height: height - 0.05 * size, lines: 0)
                        .rotation3DEffect(.degrees(-180 * flip), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.4)
                        .offset(x: (width / 2 - 0.035 * size) / 2 + 0.006 * size)
                }
            }
            .frame(width: width, height: height)
            .rotationEffect(.degrees(-4))
        case .closed:
            // 입(웃는 얼굴)을 가리지 않게 배 아래쪽에 낮게 안는다.
            let width = 0.34 * size, height = 0.32 * size
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 0.04 * size, style: .continuous)
                    .fill(LinearGradient(colors: [cover, coverDark], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .black.opacity(0.15), radius: 0.02 * size, y: 0.01 * size)
                RoundedRectangle(cornerRadius: 0.02 * size, style: .continuous)
                    .fill(coverDark)
                    .frame(width: 0.06 * size)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 0.13 * size, weight: .semibold))
                    .foregroundStyle(paper.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .padding(.leading, 0.05 * size)
            }
            .frame(width: width, height: height)
            .rotationEffect(.degrees(-6))
        }
    }

    private func page(width: CGFloat, height: CGFloat, lines: Int) -> some View {
        RoundedRectangle(cornerRadius: 0.015 * size, style: .continuous)
            .fill(paper)
            .frame(width: width, height: height)
            .overlay(alignment: .top) {
                VStack(alignment: .leading, spacing: 0.035 * size) {
                    ForEach(0..<lines, id: \.self) { index in
                        Capsule()
                            .fill(Color(red: 0.55, green: 0.75, blue: 0.55).opacity(0.55))
                            .frame(width: width * (index == lines - 1 ? 0.45 : 0.7), height: 0.012 * size)
                    }
                }
                .padding(.top, 0.035 * size)
            }
    }
}

// MARK: - 장면 조각

/// 둥근 구름. 받는 중에는 하얗게 빛나고, 문제가 있을 때는 회색에 순한 얼굴이 있다.
struct SyncCloud: View {
    enum Tone { case white, gray }
    let unit: CGFloat
    let tone: Tone
    let glow: Double
    let face: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let u = unit
        let fill: Color = switch tone {
        case .white: colorScheme == .dark ? Color(red: 0.88, green: 0.93, blue: 1) : .white
        case .gray: colorScheme == .dark ? Color(red: 0.52, green: 0.56, blue: 0.63) : Color(red: 0.74, green: 0.77, blue: 0.82)
        }
        ZStack {
            if glow > 0 {
                Ellipse()
                    .fill(RadialGradient(colors: [Color.white.opacity(0.9), .clear], center: .center, startRadius: 0, endRadius: 110 * u))
                    .frame(width: 240 * u, height: 160 * u)
                    .opacity(glow)
            }
            CloudShape()
                .fill(fill)
                .frame(width: 176 * u, height: 98 * u)
                .shadow(color: .black.opacity(tone == .white ? 0.08 : 0.12), radius: 10 * u, y: 5 * u)
            if face {
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

/// 구름에서 내려오는 기록 카드 한 장(체크·달력·루틴·통계).
struct SyncRecordCard: View {
    let card: SyncFallingCard
    let unit: CGFloat

    var body: some View {
        let (symbol, color): (String, Color) = switch card.kind {
        case .check: ("checkmark.square.fill", Color(red: 0.3, green: 0.72, blue: 0.4))
        case .calendar: ("calendar", Color(red: 0.95, green: 0.45, blue: 0.4))
        case .routine: ("checklist", Color(red: 0.45, green: 0.5, blue: 0.95))
        case .chart: ("chart.bar.fill", Color(red: 0.25, green: 0.55, blue: 0.95))
        }
        RoundedRectangle(cornerRadius: 7 * unit, style: .continuous)
            .fill(Color.white)
            .frame(width: 32 * unit, height: 36 * unit)
            .shadow(color: .black.opacity(0.12), radius: 4 * unit, y: 2 * unit)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 15 * unit, weight: .semibold))
                    .foregroundStyle(color)
            }
    }
}

/// 카드가 구름 밑에서 머리 옆(출발한 쪽)으로 비켜 살랑이며 내려오다가, 마지막에 수첩 쪽으로 들어가며 작아지고 사라진다.
/// 얼굴 앞을 지나가지 않는다.
private struct CardFlight: ViewModifier {
    let card: SyncFallingCard
    let unit: CGFloat
    let book: CGPoint

    func body(content: Content) -> some View {
        let p = card.progress
        let startX = card.startX * unit
        let side = (card.startX >= 0 ? 1 : -1) * SyncSceneMotion.cardLane * unit
        let x: CGFloat = if p < 0.3 {
            startX + (side - startX) * SyncSceneMotion.smooth(p / 0.3)
        } else if p < 0.72 {
            side + sin(p * 2 * .pi * 1.5) * 7 * unit
        } else {
            side + (book.x - side) * SyncSceneMotion.smooth((p - 0.72) / 0.28)
        }
        let startY = 112 * unit
        let y = startY + (book.y - 24 * unit - startY) * pow(p, 1.15)
        let fadeIn = min(1, p / 0.12)
        let fadeOut = p > 0.84 ? max(0, 1 - (p - 0.84) / 0.16) : 1
        let shrink = p > 0.78 ? 1 - (p - 0.78) / 0.22 * 0.5 : 1
        content
            .rotationEffect(.degrees(sin(p * 2 * .pi * 1.1) * 12 * (1 - p)))
            .scaleEffect(shrink)
            .opacity(fadeIn * fadeOut)
            .offset(x: x, y: y)
    }
}

/// 수첩에 기록이 들어올 때의 작은 반짝임.
struct SyncSparkle: View {
    let unit: CGFloat

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 16 * unit, weight: .bold))
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

/// 체크와 새싹이 둘레의 작은 노란 별.
struct SyncStars: View {
    let values: [Double]
    let unit: CGFloat
    /// 별 자리(장면 단위, 위쪽 가운데가 원점)와 크기.
    static let places: [(x: Double, y: Double, size: Double)] = [
        (-74, 40, 18), (76, 58, 15), (-108, 196, 14), (104, 184, 18), (-62, 128, 11), (66, 140, 12),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(0..<min(values.count, Self.places.count), id: \.self) { index in
                let place = Self.places[index]
                Image(systemName: "sparkle")
                    .font(.system(size: place.size * unit, weight: .bold))
                    .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.2))
                    .scaleEffect(values[index])
                    .opacity(min(1, values[index]))
                    .offset(x: place.x * unit, y: place.y * unit)
            }
        }
    }
}

/// 회색 구름에서 떨어지는 빗방울 하나. 떨어지는 동안만 보인다.
struct SyncRaindrop: View {
    let progress: Double
    let unit: CGFloat

    var body: some View {
        let fade = progress < 0.15 ? progress / 0.15 : max(0, 1 - (progress - 0.6) / 0.4)
        Capsule()
            .fill(Color(red: 0.55, green: 0.72, blue: 0.95))
            .frame(width: 6 * unit, height: 14 * unit)
            .opacity(progress > 0 ? min(fade, 1) * 0.85 : 0)
            .offset(y: progress * 72 * unit)
    }
}

/// 바닥의 작은 새싹 장식. 잎이 살랑인다(문제가 있을 때는 빛바랜 색).
struct SyncSprouts: View {
    let kind: SyncSceneKind
    let unit: CGFloat
    let sway: Double

    var body: some View {
        let color: Color = kind == .trouble ? Color(red: 0.55, green: 0.7, blue: 0.6) : Color(red: 0.42, green: 0.74, blue: 0.4)
        ZStack {
            ForEach(Array([(-140.0, 1.0), (-112.0, 0.75), (108.0, 0.8), (138.0, 1.05)].enumerated()), id: \.offset) { index, item in
                sprout(color: color, scale: item.1)
                    .rotationEffect(.degrees(sway * 0.25 * (index.isMultiple(of: 2) ? 1 : -1)), anchor: .bottom)
                    .offset(x: item.0 * unit)
            }
        }
    }

    private func sprout(color: Color, scale: Double) -> some View {
        let u = unit * scale
        return ZStack(alignment: .bottom) {
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
        .frame(height: 26 * u, alignment: .bottom)
    }
}

/// 기록을 받는 동안 글 아래에서 부드럽게 움직이는 점 세 개(진행률이 아니다).
struct SyncWaitingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion || scenePhase != .active)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 9) {
                ForEach(0..<3, id: \.self) { index in
                    let phase = reduceMotion ? 0.5 : (sin(2 * .pi * (t / 1.2 - Double(index) * 0.18)) + 1) / 2
                    Circle()
                        .fill(Color(red: 0.25, green: 0.55, blue: 0.95))
                        .frame(width: 10, height: 10)
                        .scaleEffect(0.75 + 0.3 * phase)
                        .opacity(0.35 + 0.65 * phase)
                        .offset(y: -3 * phase)
                }
            }
        }
        .frame(height: 16)
        .accessibilityElement()
        .accessibilityLabel("동기화 중")
    }
}
