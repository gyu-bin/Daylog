import SwiftUI

/// 상단 지표 4개. 항상 실제 오늘 기준이다. 같은 줄의 칸은 높이가 같다.
/// 넓은 화면은 네 칸 한 줄, 그보다 좁으면 두 열. iPhone처럼 좁은 화면(`compact`)은 두 열이 기본이고,
/// 큰 글씨나 좁은 창이라 두 열에 담기지 않으면 한 열로 바꾼다. 가로로 넘치게 두지 않는다.
struct StatCardsGrid: View {
    @Environment(AppStore.self) private var store
    let columns: Int
    var compact = false

    @State private var availableWidth: CGFloat = 0
    /// 두 열일 때 칸 하나에 필요한 최소 너비. 큰 글씨 설정을 따라 커진다.
    @ScaledMetric(relativeTo: .subheadline) private var minTileWidth: CGFloat = 150

    static let compactSpacing: CGFloat = 12

    /// 좁은 화면의 열 수. 너비를 아직 모르면 두 열로 시작한다.
    static func compactColumns(availableWidth: CGFloat, minTileWidth: CGFloat) -> Int {
        availableWidth <= 0 || availableWidth >= minTileWidth * 2 + compactSpacing ? 2 : 1
    }

    private var columnCount: Int {
        compact ? Self.compactColumns(availableWidth: availableWidth, minTileWidth: minTileWidth) : columns
    }

    var body: some View {
        let spacing = compact ? Self.compactSpacing : Theme.spacing
        VStack(spacing: 0) {
            // 쓸 수 있는 너비를 잰다(격자 자체를 재면 내용에 밀린 너비가 나올 수 있다).
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 0)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
            Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                switch columnCount {
                case 4...:
                    GridRow {
                        todayTile
                        weekTile
                        streakTile
                        longestTile
                    }
                case 1:
                    GridRow { todayTile }
                    GridRow { weekTile }
                    GridRow { streakTile }
                    GridRow { longestTile }
                default:
                    GridRow {
                        todayTile
                        weekTile
                    }
                    GridRow {
                        streakTile
                        longestTile
                    }
                }
            }
        }
    }

    private var stats: DashboardStats { store.stats }

    private var todayTile: some View {
        let outcome = stats.today
        return StatTile(
            symbol: "checkmark.circle.fill", title: "오늘 달성률", color: .mint,
            value: outcome.status == .vacation || outcome.status == .unrecorded ? outcome.percentLabel : outcome.percent.map { "\($0)%" },
            caption: todayCaption(outcome), isCompact: compact
        ) {
            if outcome.total > 0 {
                ProgressRing(ratio: outcome.ratio, lineWidth: 6, tint: Theme.todayTint)
                    .frame(width: 40, height: 40)
            }
        }
    }

    private func todayCaption(_ outcome: DayOutcome) -> String {
        if outcome.status == .vacation { return "휴가 · 달성률 통계에서 제외돼요." }
        if outcome.status == .unrecorded { return "예정된 루틴 \(outcome.total)개 · 아직 기록하지 않았어요." }
        guard stats.hasStarted else { return "첫 루틴을 완료하면 표시돼요." }
        guard outcome.total > 0 else { return "오늘은 예정된 루틴이 없어요." }
        if outcome.done == outcome.total { return "\(outcome.total)개 모두 완료했어요." }
        return "\(outcome.total)개 중 \(outcome.done)개 완료"
    }

    private var weekTile: some View {
        StatTile(
            symbol: "chart.bar.fill", title: "최근 7일 평균", color: .blue,
            value: stats.weeklyAverage.map { "\($0)%" },
            caption: stats.weeklyAverage == nil ? "집계할 기록 없음" : "휴가는 제외하고 계산해요.", isCompact: compact
        ) {
            if stats.weeklyAverage != nil {
                WeekBars(
                    outcomes: stats.week, today: store.today, threshold: stats.threshold,
                    barWidth: compact ? 7 : 10, spacing: compact ? 2.5 : 3
                )
            }
        }
    }

    private var streakTile: some View {
        StatTile(
            symbol: "flame.fill", title: "연속 달성일", color: .coral,
            value: stats.hasStarted ? "\(stats.currentStreak)" : nil, unit: "일",
            caption: !stats.hasStarted ? "\(stats.threshold)% 이상인 날을 세요."
                : stats.currentStreak > 0 ? "꾸준히 이어가고 있어요." : "오늘 \(stats.threshold)% 이상이면 시작돼요.",
            isCompact: compact
        )
    }

    private var longestTile: some View {
        StatTile(
            symbol: "crown.fill", title: "최장 연속 달성일", color: .yellow,
            value: stats.hasStarted ? "\(stats.longestStreak)" : nil, unit: "일",
            caption: !stats.hasStarted ? "가장 길었던 기록을 보여 줘요."
                : stats.longestStreak > 0 ? "지금까지의 최고 기록이에요." : "아직 달성한 날이 없어요.",
            isCompact: compact
        )
    }
}

/// 요일별 작은 막대. 기준 이상인 날은 진하게, 미만은 옅게, 값이 없는 날(휴식·시작 전)은 받침선만.
struct WeekBars: View {
    let outcomes: [DayOutcome]
    let today: Day
    let threshold: Int

    var barWidth: CGFloat = 10
    var spacing: CGFloat = 3

    private let barHeight: CGFloat = 26

    var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(outcomes) { outcome in
                let isToday = outcome.day == today
                VStack(spacing: 2) {
                    bar(for: outcome)
                        .frame(width: barWidth, height: barHeight, alignment: .bottom)
                    // 오늘은 굵은 글자로 구분한다.
                    Text(outcome.day.weekdaySymbol)
                        .font(.system(size: barWidth < 10 ? 8 : 9, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? .primary : .secondary)
                        .fixedSize()
                        .frame(width: barWidth)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(outcomes.map { $0.spokenSummary(threshold: threshold) }.joined(separator: ". "))
    }

    @ViewBuilder
    private func bar(for outcome: DayOutcome) -> some View {
        if let ratio = outcome.ratio {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Theme.weekTint.opacity(outcome.isAchieved(threshold: threshold) ? 1 : 0.4))
                .frame(height: max(3, barHeight * ratio))
        } else {
            Capsule()
                .fill(Theme.track)
                .frame(height: 3)
        }
    }
}
