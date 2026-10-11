import SwiftUI

/// 상단 지표 4개. 항상 실제 오늘 기준이다. 네 칸의 높이는 같다.
struct StatCardsGrid: View {
    @Environment(AppStore.self) private var store
    let columns: Int

    var body: some View {
        Grid(horizontalSpacing: Theme.spacing, verticalSpacing: Theme.spacing) {
            if columns >= 4 {
                GridRow {
                    todayTile
                    weekTile
                    streakTile
                    longestTile
                }
            } else {
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

    private var stats: DashboardStats { store.stats }

    private var todayTile: some View {
        let outcome = stats.today
        return StatTile(
            symbol: "checkmark.circle.fill", title: "오늘 달성률", color: .mint,
            value: outcome.status == .vacation ? "휴가" : outcome.percent.map { "\($0)%" },
            caption: todayCaption(outcome)
        ) {
            if outcome.total > 0 {
                ProgressRing(ratio: outcome.ratio, lineWidth: 6, tint: Theme.todayTint)
                    .frame(width: 40, height: 40)
            }
        }
    }

    private func todayCaption(_ outcome: DayOutcome) -> String {
        if outcome.status == .vacation { return "통계와 루틴 알림에서 제외돼요." }
        guard stats.hasStarted else { return "첫 루틴을 완료하면 표시돼요." }
        guard outcome.total > 0 else { return "오늘은 예정된 루틴이 없어요." }
        if outcome.done == outcome.total { return "\(outcome.total)개 모두 완료했어요." }
        return "\(outcome.total)개 중 \(outcome.done)개 완료"
    }

    private var weekTile: some View {
        StatTile(
            symbol: "chart.bar.fill", title: "최근 7일 평균", color: .blue,
            value: stats.weeklyAverage.map { "\($0)%" },
            caption: stats.weeklyAverage == nil ? "집계할 기록 없음" : "휴가는 제외하고 계산해요."
        ) {
            if stats.weeklyAverage != nil {
                WeekBars(outcomes: stats.week, today: store.today, threshold: stats.threshold)
            }
        }
    }

    private var streakTile: some View {
        StatTile(
            symbol: "flame.fill", title: "연속 달성일", color: .coral,
            value: stats.hasStarted ? "\(stats.currentStreak)" : nil, unit: "일",
            caption: !stats.hasStarted ? "\(stats.threshold)% 이상인 날을 세요."
                : stats.currentStreak > 0 ? "꾸준히 이어가고 있어요." : "오늘 \(stats.threshold)% 이상이면 시작돼요."
        )
    }

    private var longestTile: some View {
        StatTile(
            symbol: "crown.fill", title: "최장 연속 달성일", color: .yellow,
            value: stats.hasStarted ? "\(stats.longestStreak)" : nil, unit: "일",
            caption: !stats.hasStarted ? "가장 길었던 기록을 보여 줘요."
                : stats.longestStreak > 0 ? "지금까지의 최고 기록이에요." : "아직 달성한 날이 없어요."
        )
    }
}

/// 요일별 작은 막대. 기준 이상인 날은 진하게, 미만은 옅게, 값이 없는 날(휴식·시작 전)은 받침선만.
struct WeekBars: View {
    let outcomes: [DayOutcome]
    let today: Day
    let threshold: Int

    private let barHeight: CGFloat = 26
    private let barWidth: CGFloat = 10

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(outcomes) { outcome in
                let isToday = outcome.day == today
                VStack(spacing: 2) {
                    bar(for: outcome)
                        .frame(width: barWidth, height: barHeight, alignment: .bottom)
                    // 오늘은 굵은 글자로 구분한다.
                    Text(outcome.day.weekdaySymbol)
                        .font(.system(size: 9, weight: isToday ? .bold : .regular))
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
