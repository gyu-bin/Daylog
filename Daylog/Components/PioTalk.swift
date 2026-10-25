import SwiftUI

// 피오의 한마디(2026-10-25). 오늘 화면은 첫 줄에서 늘 말하고, 다른 탭은 제목 줄 끝에서 잠깐 말한다.
// 대사 목록: docs/design/pio-header-2026-10-25/LINES.md

/// 말풍선을 보일지(이 기기 설정). 끄면 피오만 보이고 말은 하지 않는다.
enum PioTalkPreference {
    static let key = "pio.speechBubbles.v1"
}

/// 왼쪽(피오 쪽)에 짧은 꼬리가 달린 말풍선. 오른쪽에 피오가 있으면 `scaleEffect(x: -1)`로 뒤집어 쓴다.
struct PioSpeechBubble: Shape {
    func path(in rect: CGRect) -> Path {
        let tail: CGFloat = 8
        let body = CGRect(x: rect.minX + tail, y: rect.minY, width: rect.width - tail, height: rect.height)
        var path = Path(roundedRect: body, cornerRadius: min(16, body.height / 2), style: .continuous)
        let mid = body.midY
        var tip = Path()
        tip.move(to: CGPoint(x: body.minX + 1, y: mid - 7))
        tip.addQuadCurve(to: CGPoint(x: rect.minX, y: mid + 3), control: CGPoint(x: body.minX - 2, y: mid))
        tip.addQuadCurve(to: CGPoint(x: body.minX + 1, y: mid + 6), control: CGPoint(x: body.minX - 1, y: mid + 5))
        tip.closeSubpath()
        path.addPath(tip)
        return path
    }
}

private struct PioBubbleText: View {
    let line: String
    var font: Font = .subheadline.weight(.semibold)
    var lineLimit = 2
    /// 피오가 오른쪽에 있으면 꼬리를 오른쪽으로.
    var tailOnTrailing = false
    var body: some View {
        Text(verbatim: line)
            .font(font)
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, tailOnTrailing ? 12 : 18).padding(.trailing, tailOnTrailing ? 18 : 12).padding(.vertical, 7)
            .background(PioSpeechBubble().fill(Theme.cardBackground).scaleEffect(x: tailOnTrailing ? -1 : 1))
            .overlay(PioSpeechBubble().stroke(Theme.cardBorder, lineWidth: 1).scaleEffect(x: tailOnTrailing ? -1 : 1))
            .contentTransition(.opacity)
    }
}

/// 오늘 화면 첫 줄: 피오와 늘 보이는 말풍선. 피오를 누르면 다음 대사, 체크하면 잠깐 반응한다.
struct TodayPioTalk: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var pioSize: CGFloat = 50
    @State private var tapIndex = 0
    @State private var reaction: String?
    @State private var reactionTask: Task<Void, Never>?

    private var done: Int { store.checkSections.reduce(0) { $0 + $1.done } }
    private var skipped: Int { store.checkSections.reduce(0) { $0 + $1.skipped } }
    private var total: Int { store.checkSections.reduce(0) { $0 + $1.total } }
    private var lines: [String] {
        PioLines.today(done: done, total: total, streak: store.stats.currentStreak,
                       isToday: store.isViewingToday, isVacation: store.isVacation(on: store.selectedDay),
                       outfit: PioAppearanceCoordinator.shared.resolve(level: store.growth.level, context: .dashboard).outfit)
    }
    private var line: String {
        if let reaction { return reaction }
        let all = lines
        return all[(PioLines.startIndex(count: all.count) + tapIndex) % all.count]
    }

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            PioHeaderCompanion(size: pioSize, onTap: next)
            PioBubbleText(line: line)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: line)
                .accessibilityLabel("피오: \(line)")
        }
        .onChange(of: done) { old, new in
            if new > old, new < total { react(PioLines.checked) }
            else { clearReaction() }
        }
        .onChange(of: skipped) { old, new in if new > old { react(PioLines.skipped) } }
        .onChange(of: store.selectedDay) { _, _ in tapIndex = 0; clearReaction() }
    }

    private func next() { clearReaction(); tapIndex += 1 }
    private func react(_ text: String) {
        reactionTask?.cancel()
        reaction = text
        reactionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            reaction = nil
        }
    }
    private func clearReaction() { reactionTask?.cancel(); reaction = nil }
}

/// 다른 탭의 제목 줄 오른쪽 끝에 앉은 작은 피오. 말풍선은 탭을 열 때 3초만 보이고, 피오를 누르면 다시 보인다.
struct PioPeekBubble: View {
    let line: String
    var pioSize: CGFloat = 40
    @AppStorage(PioTalkPreference.key) private var talks = true
    @State private var showsLine = true
    @State private var hideTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // 아주 큰 글자에서는 제목 줄이 좁아 말풍선을 띄우지 않는다(피오와 화면 읽기 문장은 그대로).
            if talks && showsLine && !dynamicTypeSize.isAccessibilitySize {
                PioBubbleText(line: line, font: .footnote.weight(.semibold), lineLimit: 1, tailOnTrailing: true)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
            }
            PioHeaderCompanion(size: pioSize, onTap: show)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(talks ? "피오: \(line)" : "피오")
        .onAppear { scheduleHide() }
        .onDisappear { hideTask?.cancel() }
    }

    private func show() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { showsLine = true }
        scheduleHide()
    }
    private func scheduleHide() {
        hideTask?.cancel()
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "DaylogDebugKeepPioBubble") { return }
        #endif
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeIn(duration: 0.25)) { showsLine = false }
        }
    }
}

/// 설정 맨 위: 지금 입은 피오, 옷장 바로가기, 말풍선 켜고 끄기.
struct PioSettingsCard: View {
    @Environment(AppStore.self) private var store
    @AppStorage(PioTalkPreference.key) private var talks = true
    private var outfit: PioOutfitID { PioAppearanceCoordinator.shared.resolve(level: store.growth.level, context: .dashboard).outfit }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                PioHeaderCompanion(size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("지금 입은 옷").font(.caption).foregroundStyle(.secondary)
                    Text(outfit.title).font(.headline)
                }
                Spacer(minLength: 8)
                if AppStore.Section.wardrobe.isAvailable {
                    Button("옷장") { store.section = .wardrobe }
                        .buttonStyle(.bordered)
                        .accessibilityHint("피오 옷장을 엽니다.")
                }
            }
            Toggle("피오 말풍선 보기", isOn: $talks)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

/// 피오의 대사. 제목 줄에 한 줄로 들어가도록 짧게(약 14자) 쓴다.
enum PioLines {
    static let checked = "좋아요! 하나 끝!"
    static let skipped = "괜찮아요, 쉬어 가요"

    /// 오늘 화면. 첫 번째가 기본 대사이고, 피오를 누르면 다음으로 넘어간다.
    static func today(done: Int, total: Int, streak: Int, isToday: Bool, isVacation: Bool,
                      outfit: PioOutfitID, hour: Int = Calendar.current.component(.hour, from: Date())) -> [String] {
        let outfitLine = self.outfit(outfit)
        func with(_ first: String) -> [String] { [first] + (outfitLine.map { [$0] } ?? []) }
        if !isToday { return with("지난 기록을 보고 있어요") }
        if isVacation { return with("오늘은 푹 쉬어요") }
        if total == 0 { return with("첫 루틴, 같이 만들어요!") }
        if done >= total {
            return streak >= 2 ? with("\(streak)일 연속이에요! 최고!") + ["오늘 다 해냈어요!"] : with("오늘 다 해냈어요! 최고!")
        }
        let remaining = total - done
        let first: String
        if done == 0 {
            switch hour {
            case 5..<11: first = "좋은 아침! 하나씩 해요"
            case 11..<18: first = "첫 루틴 해 볼까요?"
            case 18..<23: first = "지금 해도 늦지 않아요"
            default: first = "내일 다시 해도 괜찮아요"
            }
        } else if remaining == 1 {
            first = "하나만 더 하면 끝!"
        } else if done * 2 >= total {
            first = "절반 넘었어요! 좋아요"
        } else {
            first = "\(remaining)개 남았어요, 힘내요!"
        }
        return with(first) + (streak >= 2 ? ["\(streak)일째 함께하고 있어요"] : [])
    }

    /// 같은 상황에서도 날·시간마다 첫 대사를 조금씩 바꾼다(의상 대사가 먼저 나오는 때가 있다). 화면이 다시 그려져도 같은 값이다.
    static func startIndex(count: Int, date: Date = Date(), calendar: Calendar = .current) -> Int {
        guard count > 1 else { return 0 }
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
        let hour = calendar.component(.hour, from: date)
        return (day + hour) % 3 == 0 ? 1 : 0
    }

    static func outfit(_ outfit: PioOutfitID) -> String? {
        switch outfit {
        case .basic: return nil
        case .cherryBlossom: return "꽃잎처럼 가볍게 해요"
        case .summerVacation: return "시원하게 하나 끝내요!"
        case .autumn: return "낙엽처럼 차곡차곡!"
        case .winter: return "따뜻하게 시작해요"
        case .halloween: return "사탕 하나, 루틴 하나!"
        case .christmas: return "선물 같은 하루예요"
        case .hanbok: return "한 걸음씩 차근차근"
        case .cafe: return "커피 한 잔, 루틴 하나"
        case .student: return "오늘 숙제는 루틴이에요"
        case .fitness: return "한 세트 더 가 볼까요?"
        case .rainyDay: return "비 와도 루틴은 챙겨요"
        case .pajamas: return "자기 전에 하나만 더?"
        case .astronaut: return "목표까지 발사 준비!"
        }
    }

    // 탭별 한마디
    static func routines(count: Int) -> String { count == 0 ? "첫 루틴을 만들어 봐요!" : "루틴 \(count)개, 같이 챙길게요" }
    static func meals(hour: Int = Calendar.current.component(.hour, from: Date())) -> String {
        switch hour {
        case 5..<10: return "아침은 챙겨 드셨어요?"
        case 10..<15: return "점심 메뉴는 뭐였어요?"
        case 15..<21: return "저녁은 맛있게 드셨나요?"
        default: return "잊기 전에 적어 둬요!"
        }
    }
    static func statistics(_ stats: DashboardStats) -> String {
        if stats.currentStreak >= 2 { return "\(stats.currentStreak)일 연속 달성 중이에요!" }
        if let average = stats.weeklyAverage { return "최근 7일 평균 \(average)%예요" }
        return "기록이 쌓이면 같이 봐요"
    }
    static let settings = "옷장에서 저를 꾸며 주세요!"
    static let calendar = "다 해낸 날을 모아 봐요"
    static let vacation = "푹 쉬어요, 기록은 지킬게요"
    static let templates = "다른 루틴도 구경해 봐요"
}
