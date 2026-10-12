import SwiftUI

/// 활동 히트맵: 열은 주, 행은 요일(한 주의 시작 요일부터). 최근 날짜가 오른쪽이다. 칸을 누르면 그 날짜의 기록을 연다.
struct ActivityHeatmapCard: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    let outcomes: [DayOutcome]
    let threshold: Int

    @State private var hovered: DayOutcome?

    private let cell: CGFloat = 13
    private let gap: CGFloat = 3
    private let monthRowHeight: CGFloat = 14

    var body: some View {
        let weeks = HeatmapLayout.weeks(outcomes, weekStart: preferences.weekStart)
        let months = HeatmapLayout.monthLabels(weeks)
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(symbol: "square.grid.3x3.fill", title: "활동 히트맵", subtitle: "(최근 \(weeks.count)주)")

                HStack(alignment: .top, spacing: 6) {
                    weekdayLabels
                    // 다 들어가면 왼쪽에 붙여 그리고, 넘치면 가로로 스크롤한다.
                    ViewThatFits(in: .horizontal) {
                        grid(weeks: weeks, months: months)
                        ScrollView(.horizontal) {
                            grid(weeks: weeks, months: months)
                                .padding(.bottom, 4)
                        }
                        // 최근 날짜가 먼저 보이도록 오른쪽 끝에서 시작한다.
                        .defaultScrollAnchor(.trailing)
                    }
                    Spacer(minLength: 0)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        legend
                        Spacer(minLength: 8)
                        hoverDetail
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        legend
                        hoverDetail
                    }
                }
            }
        }
    }

    private func grid(weeks: [[DayOutcome?]], months: [String?]) -> some View {
        HStack(alignment: .top, spacing: gap) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                VStack(spacing: gap) {
                    monthLabel(months[index])
                    ForEach(Array(week.enumerated()), id: \.offset) { _, outcome in
                        cellView(outcome)
                    }
                }
            }
        }
        // 마지막 열의 달 이름이 잘리지 않게 한다.
        .padding(.trailing, 14)
    }

    private var hoverDetail: some View {
        Text(hovered.map { $0.spokenSummary(threshold: threshold) } ?? "칸을 누르면 그 날짜의 기록을 열어요.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
            .accessibilityHidden(true)
    }

    private var weekdayLabels: some View {
        VStack(alignment: .trailing, spacing: gap) {
            Color.clear.frame(width: 1, height: monthRowHeight)
            ForEach(Array(preferences.weekStart.orderedWeekdays.enumerated()), id: \.element) { index, weekday in
                // 칸이 작아 한 줄 걸러 요일을 적는다.
                Text(index % 2 == 0 ? Weekdays.symbol(weekday) : "")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(height: cell)
            }
        }
        .accessibilityHidden(true)
    }

    private func monthLabel(_ label: String?) -> some View {
        Color.clear
            .frame(width: cell, height: monthRowHeight)
            .overlay(alignment: .leading) {
                if let label {
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func cellView(_ outcome: DayOutcome?) -> some View {
        let level = outcome.map { HeatLevel($0, threshold: threshold) } ?? .none
        if let outcome, level != .none {
            HeatCell(level: level, size: cell, isToday: outcome.day == store.today, isHovered: hovered == outcome)
                .onHover { isInside in
                    if isInside {
                        hovered = outcome
                    } else if hovered == outcome {
                        hovered = nil
                    }
                }
                .onTapGesture { store.open(outcome.day) }
                .help(outcome.spokenSummary(threshold: threshold))
                .accessibilityElement()
                .accessibilityLabel(outcome.spokenSummary(threshold: threshold))
                .accessibilityHint("누르면 이 날짜의 기록을 엽니다.")
                .accessibilityAddTraits(.isButton)
                // 탭 제스처는 VoiceOver의 "누르기"로는 실행되지 않아 같은 동작을 따로 연결한다.
                .accessibilityAction { store.open(outcome.day) }
        } else if outcome?.status == .preStart {
            // 기록을 시작하기 전의 날. 격자 모양만 흐리게 보여 주고 누를 수 없다.
            RoundedRectangle(cornerRadius: cell * 0.24, style: .continuous)
                .fill(Theme.track.opacity(0.4))
                .frame(width: cell, height: cell)
                .accessibilityHidden(true)
        } else {
            Color.clear
                .frame(width: cell, height: cell)
                .accessibilityHidden(true)
        }
    }

    private var legend: some View {
        HStack(spacing: 10) {
            ForEach([HeatLevel.vacation, .rest, .unrecorded, .low, .mid, .achieved], id: \.label) { level in
                HStack(spacing: 4) {
                    HeatCell(level: level, size: 10, isToday: false, isHovered: false)
                    Text(level.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("범례: 빼기 표시는 휴가, 테두리만 있는 칸은 휴식, 옅은 칸은 미기록, 색이 진할수록 달성률이 높아요.")
    }
}

/// 히트맵 한 칸. 휴식일은 테두리만, 나머지는 달성률이 높을수록 진하게 채운다.
private struct HeatCell: View {
    let level: HeatLevel
    let size: CGFloat
    let isToday: Bool
    let isHovered: Bool

    private var fill: Color {
        switch level {
        case .vacation: return Theme.vacationTint.opacity(0.3)
        case .none, .rest: return .clear
        case .unrecorded: return Theme.track
        case .low: return Theme.accent.opacity(0.32)
        case .mid: return Theme.accent.opacity(0.62)
        case .achieved: return Theme.accent
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
        shape
            .fill(fill)
            .overlay {
                if level == .vacation {
                    Image(systemName: "minus").font(.system(size: size * 0.65, weight: .bold)).foregroundStyle(.blue)
                }
                if level == .rest {
                    shape.strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
                }
            }
            .overlay {
                if isToday || isHovered {
                    shape.strokeBorder(Color.primary.opacity(isHovered ? 0.75 : 0.5), lineWidth: 1.5)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
    }
}
