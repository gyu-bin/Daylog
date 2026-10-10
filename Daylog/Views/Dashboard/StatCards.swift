import SwiftUI

/// 상단 지표 4개. 항상 실제 오늘 기준이다.
struct StatCardsGrid: View {
    let columns: Int

    var body: some View {
        Grid(horizontalSpacing: Theme.spacing, verticalSpacing: Theme.spacing) {
            if columns >= 4 {
                GridRow {
                    TodayRateCard()
                    WeeklyAverageCard()
                    CurrentStreakCard()
                    LongestStreakCard()
                }
            } else {
                GridRow {
                    TodayRateCard()
                    WeeklyAverageCard()
                }
                GridRow {
                    CurrentStreakCard()
                    LongestStreakCard()
                }
            }
        }
    }
}

private struct StatCard<Content: View>: View {
    let symbol: String
    let title: String
    /// 이 지표를 나타내는 색. 아이콘에만 쓴다.
    let tint: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(symbol: symbol, title: title, tint: tint)
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .frame(height: 140)
        .accessibilityElement(children: .combine)
    }
}

private struct BigNumber: View {
    let text: String
    var unit: String = ""
    var size: CGFloat = 34
    var tint: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(text)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: size * 0.6, weight: .semibold))
            }
        }
        // 값이 아직 없을 때의 "—"는 강조하지 않는다.
        .foregroundStyle(text == "—" ? AnyShapeStyle(.tertiary) : AnyShapeStyle(tint))
        .lineLimit(1)
        .fixedSize()
    }
}

private struct TodayRateCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let outcome = store.stats.today
        StatCard(symbol: "leaf.fill", title: "오늘 달성률", tint: Theme.todayTint) {
            HStack(spacing: 14) {
                ZStack {
                    ProgressRing(ratio: outcome.ratio)
                    Text(outcome.percentLabel)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(outcome.percent == nil ? Color.secondary : Theme.accent)
                }
                .frame(width: 74, height: 74)

                VStack(alignment: .leading, spacing: 4) {
                    if outcome.total > 0 {
                        Text("\(outcome.done) / \(outcome.total) 완료")
                            .font(.headline)
                            .monospacedDigit()
                        Text(message(for: outcome))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(store.stats.hasStarted ? "루틴 없음" : "—")
                            .font(.headline)
                        Text(store.stats.hasStarted ? "오늘은 쉬어 가는 날이에요." : "첫 루틴을 기다리고 있어요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func message(for outcome: DayOutcome) -> String {
        if outcome.done == outcome.total { return "오늘도 수고했어요." }
        if outcome.done == 0 { return "하나씩 시작해 봐요." }
        return "\(outcome.total - outcome.done)개 남았어요."
    }
}

private struct WeeklyAverageCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        StatCard(symbol: "chart.bar.fill", title: "최근 7일 평균", tint: Theme.weekTint) {
            let average = store.stats.weeklyAverage.map { "\($0)%" } ?? "—"
            // 카드가 좁아지면 숫자를 줄이고, 그래도 좁으면 막대를 생략한다.
            ViewThatFits(in: .horizontal) {
                content(average: average, size: 34, showsBars: true)
                content(average: average, size: 26, showsBars: true)
                content(average: average, size: 30, showsBars: false)
            }
        }
    }

    private func content(average: String, size: CGFloat, showsBars: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            BigNumber(text: average, size: size)
            Spacer(minLength: 0)
            if showsBars, store.stats.hasStarted {
                WeekBars(outcomes: store.stats.week, today: store.today, threshold: store.threshold)
            }
        }
    }
}

/// 요일별 작은 막대. 휴식일·시작 전은 점선 자리표시로 구분한다.
private struct WeekBars: View {
    let outcomes: [DayOutcome]
    let today: Day
    let threshold: Int

    private let barHeight: CGFloat = 40

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(outcomes) { outcome in
                VStack(spacing: 4) {
                    bar(for: outcome)
                        .frame(width: 12, height: barHeight, alignment: .bottom)
                    Text(outcome.day == today ? "오늘" : outcome.day.weekdaySymbol)
                        .font(.system(size: 9, weight: outcome.day == today ? .semibold : .regular))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .frame(width: 12)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(outcomes.map { $0.spokenSummary(threshold: threshold) }.joined(separator: ". "))
    }

    @ViewBuilder
    private func bar(for outcome: DayOutcome) -> some View {
        if let ratio = outcome.ratio {
            // 기준 이상인 날은 진하게, 미만인 날은 옅게.
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Theme.weekTint.opacity(outcome.isAchieved(threshold: threshold) ? 1 : 0.4))
                .frame(height: max(3, barHeight * ratio))
        } else {
            // 휴식일·시작 전: 값이 없다는 뜻의 얇은 받침선.
            Capsule()
                .fill(Theme.track)
                .frame(height: 3)
        }
    }
}

private struct CurrentStreakCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        StatCard(symbol: "flame.fill", title: "연속 달성일", tint: Theme.streakTint) {
            VStack(alignment: .leading, spacing: 6) {
                BigNumber(text: store.stats.hasStarted ? "\(store.stats.currentStreak)" : "—",
                          unit: store.stats.hasStarted ? "일" : "")
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var caption: String {
        guard store.stats.hasStarted else { return "달성률 \(store.threshold)% 이상인 날을 세요." }
        return store.stats.currentStreak > 0
            ? "지금, 꾸준히 이어가고 있어요."
            : "오늘 \(store.threshold)% 이상이면 다시 시작돼요."
    }
}

private struct LongestStreakCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        StatCard(symbol: "crown.fill", title: "최장 연속 달성일", tint: Theme.longestTint) {
            VStack(alignment: .leading, spacing: 6) {
                BigNumber(text: store.stats.hasStarted ? "\(store.stats.longestStreak)" : "—",
                          unit: store.stats.hasStarted ? "일" : "")
                Text(store.stats.longestStreak > 0 ? "지금까지의 최고 기록이에요." : "아직 기록이 없어요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}
