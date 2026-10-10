import SwiftUI

/// 루틴 통계: 기간을 고르면 요약·추이·그룹·항목이 모두 그 기간으로 바뀐다.
/// 연속 달성일은 기간과 상관없이 전체 이력 기준이다.
struct RoutineStatisticsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isWide: Bool

    @State private var stats = PeriodStats.empty(.month)
    /// 항목 표를 이 그룹의 항목으로 좁힌다. nil이면 전체.
    @State private var selectedGroupID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            if store.stats.hasStarted {
                periodBar
                tiles
                TrendChartCard(
                    outcomes: stats.outcomes, subtitle: "(\(stats.period.label))",
                    chartHeight: 200, isInteractive: true
                )
                ActivityHeatmapCard(outcomes: stats.heatmap, threshold: stats.threshold)
                rates
            } else {
                Card(fillsHeight: false) {
                    EmptyHint(
                        symbol: "chart.bar.xaxis",
                        message: "아직 통계가 없어요.\n루틴을 만들고 하나라도 완료하면 여기에 기록이 쌓여요.",
                        tint: Theme.accent,
                        actionTitle: "오늘의 루틴으로 이동"
                    ) {
                        store.open(store.today)
                    }
                    .padding(.vertical, 24)
                }
            }
        }
        .onAppear(perform: reload)
        .onChange(of: store.statsPeriod) {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { reload() }
        }
        .onChange(of: store.dataVersion) { reload() }
    }

    private func reload() {
        stats = store.periodStats(store.statsPeriod)
        // 고른 그룹이 이 기간에 없으면 선택을 푼다.
        if let selectedGroupID, !stats.groupRates.contains(where: { $0.groupID == selectedGroupID }) {
            self.selectedGroupID = nil
        }
    }

    // MARK: - 기간

    private var periodBar: some View {
        @Bindable var store = store
        return HStack(spacing: 12) {
            Picker("기간", selection: $store.statsPeriod) {
                ForEach(StatsPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel("통계 기간")

            if let first = stats.outcomes.first, let last = stats.outcomes.last {
                Text("\(first.day.shortTitle) ~ \(last.day.shortTitle) · \(stats.outcomes.count)일")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 요약

    private var tiles: some View {
        Grid(horizontalSpacing: Theme.spacing, verticalSpacing: Theme.spacing) {
            if isWide {
                GridRow {
                    averageTile
                    achievedTile
                    streakTile
                    longestTile
                }
            } else {
                GridRow {
                    averageTile
                    achievedTile
                }
                GridRow {
                    streakTile
                    longestTile
                }
            }
        }
    }

    private var averageTile: some View {
        StatTile(
            symbol: "chart.bar.fill", title: "기간 평균 달성률", color: .blue,
            value: stats.averagePercent.map { "\($0)%" },
            caption: stats.averagePercent == nil ? "이 기간에 집계할 날이 없어요." : "\(stats.period.label) · 미기록일은 0%"
        )
    }

    private var achievedTile: some View {
        StatTile(
            symbol: "checkmark.seal.fill", title: "달성한 날", color: .mint,
            value: stats.countedDays > 0 ? "\(stats.achievedDays)" : nil, unit: "일",
            caption: stats.countedDays > 0
                ? "유효한 \(stats.countedDays)일 중 · 기준 \(stats.threshold)% 이상"
                : "이 기간에 집계할 날이 없어요."
        )
    }

    private var streakTile: some View {
        let streak = store.stats.currentStreak
        return StatTile(
            symbol: "flame.fill", title: "현재 연속 달성", color: .coral,
            value: streak > 0 ? "\(streak)" : nil, unit: "일",
            caption: streak > 0 ? "오늘 기준 · 기간과 무관" : "기준을 달성한 날부터 다시 세요."
        )
    }

    private var longestTile: some View {
        let longest = store.stats.longestStreak
        return StatTile(
            symbol: "trophy.fill", title: "최장 연속 달성", color: .yellow,
            value: longest > 0 ? "\(longest)" : nil, unit: "일",
            caption: longest > 0 ? "전체 이력 기준" : "첫 루틴을 완료하면 표시돼요."
        )
    }

    // MARK: - 그룹과 항목

    @ViewBuilder
    private var rates: some View {
        let selected = stats.groupRates.first { $0.groupID == selectedGroupID }
        // 항목은 지금 속한 그룹으로 좁힌다(그룹 달성률은 그날 속해 있던 그룹으로 집계한다).
        let items = selected.map { group in stats.routineRates.filter { $0.groupID == group.groupID } } ?? stats.routineRates
        let groupCard = GroupRatesCard(rates: stats.groupRates, periodLabel: stats.period.label, selection: $selectedGroupID)
        let itemCard = ItemRatesCard(rates: items, periodLabel: stats.period.label, group: selected) {
            selectedGroupID = nil
        }
        if isWide {
            HStack(alignment: .top, spacing: Theme.spacing) {
                groupCard.frame(width: 320)
                itemCard
            }
        } else {
            groupCard
            itemCard
        }
    }
}
