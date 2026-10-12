import SwiftUI

/// 최근 7일을 요일별 고리로 보여 준다. 고리는 달성률만큼 차고, 기준을 넘긴 날은 체크 표시가 붙는다.
/// 날짜를 누르면 그날의 기록으로 간다. 오른쪽(좁으면 아래)에는 이번 주 평균.
struct WeekOverviewCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let stats = store.stats
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(symbol: "calendar.badge.clock", title: "최근 7일 기록") {
                    HeaderLink(title: "전체 보기") {
                        store.section = .statistics
                    }
                }

                if !stats.hasStarted {
                    EmptyHint(symbol: "calendar", message: "루틴을 기록하면 여기에 하루씩 쌓여요.")
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .center, spacing: 14) {
                            days(stats)
                            average(stats)
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            days(stats)
                            average(stats)
                        }
                    }
                }
            }
        }
    }

    private func days(_ stats: DashboardStats) -> some View {
        HStack(spacing: 4) {
            ForEach(stats.week) { outcome in
                let isToday = outcome.day == store.today
                Button {
                    store.open(outcome.day)
                } label: {
                    VStack(spacing: 5) {
                        Text(outcome.day.weekdaySymbol)
                            .font(.caption.weight(isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? .primary : .secondary)
                        Text(outcome.day.axisLabel)
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        DayMark(outcome: outcome, threshold: stats.threshold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background {
                        if store.section == .dashboard, outcome.day == store.selectedDay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.accentWash)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(outcome.spokenSummary(threshold: stats.threshold))
                .accessibilityHint("이 날짜의 기록으로 이동")
                .accessibilityAction { store.open(outcome.day) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 이번 주 평균과, 집계한 날 중 기준을 넘긴 날의 수.
    private func average(_ stats: DashboardStats) -> some View {
        let counted = stats.week.filter { $0.ratio != nil }
        let achieved = counted.filter { $0.isAchieved(threshold: stats.threshold) }.count
        return VStack(spacing: 3) {
            Text("이번 주 평균")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(stats.weeklyAverage.map { "\($0)%" } ?? "—")
                .font(.system(size: 24, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(GroupColor.mint.ink)
            Text(counted.isEmpty ? "집계할 날 없음" : "\(achieved) / \(counted.count) 달성")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 112)
        .background(Theme.accentWash, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "이번 주 평균 \(stats.weeklyAverage.map { "\($0)%" } ?? "집계할 기록 없음"), "
                + (counted.isEmpty ? "집계할 날 없음" : "집계한 \(counted.count)일 중 \(achieved)일 달성")
        )
    }
}

/// 하루의 상태 표시. 색만이 아니라 모양으로도 구분한다: 달성 = 꽉 찬 고리와 체크, 미달 = 비율만큼 찬 고리,
/// 미기록 = 빈 고리와 점, 휴식 = 짧은 줄, 휴가 = 해.
private struct DayMark: View {
    let outcome: DayOutcome
    let threshold: Int

    var body: some View {
        ZStack {
            switch outcome.status {
            case .recorded:
                ProgressRing(ratio: outcome.ratio ?? 0, lineWidth: 4, tint: outcome.tint(threshold: threshold))
                if outcome.isAchieved(threshold: threshold) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            case .unrecorded:
                ProgressRing(ratio: 0, lineWidth: 4)
                Circle().fill(Color.secondary.opacity(0.5)).frame(width: 5, height: 5)
            case .vacation:
                Image(systemName: "sun.max")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            case .rest, .preStart, .future:
                Text("–")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 26, height: 26)
        .accessibilityHidden(true)
    }
}
