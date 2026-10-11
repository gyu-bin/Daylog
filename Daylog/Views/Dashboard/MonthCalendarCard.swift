import SwiftUI

/// 월간 캘린더. 월요일 시작. 날짜를 누르면 그 날짜의 기록으로 이동한다.
struct MonthCalendarCard: View {
    @Environment(AppStore.self) private var store
    /// 날짜를 누르면 대시보드로 옮겨 그 날짜를 연다. 꺼 두면 지금 화면에서 날짜만 바꾼다.
    var opensDashboard = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        let month = store.calendarMonth
        Card {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(symbol: "calendar", title: "월간 캘린더") {
                    monthStepper(month)
                }

                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Weekdays.all, id: \.self) { weekday in
                        Text(Weekdays.symbol(weekday))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .accessibilityHidden(true)

                    // 1일이 시작하는 요일까지 빈칸.
                    ForEach(0..<(month.weekday - 1), id: \.self) { _ in
                        Color.clear.frame(height: 1)
                    }

                    ForEach(Day.range(from: month, to: month.adding(days: month.daysInMonth - 1)), id: \.self) { day in
                        DayCell(
                            day: day,
                            outcome: store.monthOutcomes[day],
                            isToday: day == store.today,
                            isSelected: day == store.selectedDay,
                            threshold: store.threshold
                        ) {
                            if opensDashboard {
                                store.open(day)
                            } else {
                                store.select(day)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
                legend
            }
        }
    }

    private func monthStepper(_ month: Day) -> some View {
        HStack(spacing: 2) {
            Button {
                store.showPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("이전 달")

            Text(month.monthTitle)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 84)

            Button {
                store.showNextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .disabled(!store.canShowNextMonth)
            .accessibilityLabel("다음 달")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
        .fixedSize()
    }

    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { legendItems }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) { legendItems }
                    .fixedSize()
                    .scaleEffect(0.9, anchor: .leading)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var legendItems: some View {
        HStack(spacing: 4) {
            StatusMarker(kind: .achieved)
            Text("\(store.threshold)% 이상")
        }
        HStack(spacing: 4) {
            StatusMarker(kind: .below)
            Text("기준 미만")
        }
        HStack(spacing: 4) {
            StatusMarker(kind: .unrecorded)
            Text("미기록")
        }
        HStack(spacing: 4) {
            StatusMarker(kind: .rest)
            Text("휴식")
        }
    }
}

/// 색과 모양을 함께 써서 색만으로 상태를 구분하지 않게 한다.
private struct StatusMarker: View {
    enum Kind {
        case achieved, below, unrecorded, rest
    }

    let kind: Kind
    var size: CGFloat = 7

    var body: some View {
        Group {
            switch kind {
            case .achieved:
                Circle().fill(Theme.accent)
            case .below:
                Circle().fill(Theme.accentSoft)
            case .unrecorded:
                Circle().strokeBorder(Color.secondary, lineWidth: 1)
            case .rest:
                Capsule().fill(Color.secondary.opacity(0.5)).frame(height: 2)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct DayCell: View {
    let day: Day
    let outcome: DayOutcome?
    let isToday: Bool
    let isSelected: Bool
    let threshold: Int
    let action: () -> Void

    private var isFuture: Bool { outcome?.status == .future }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text("\(day.day)")
                    .font(.callout.weight(isToday ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? AnyShapeStyle(Theme.onAccent) : AnyShapeStyle(isFuture ? .tertiary : .primary))
                    .frame(width: 26, height: 26)
                    .background {
                        if isToday { Circle().fill(Theme.accent) }
                    }
                statusLine
                    .frame(height: 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.accentWash)
                }
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.accent.opacity(0.6), lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        // 자식을 합쳐 하나의 요소로 만들면 단추의 누르기 동작이 빠진다. VoiceOver로도 날짜를 고를 수 있게 다시 붙인다.
        .accessibilityAction {
            if !isFuture { action() }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if let outcome {
            switch outcome.status {
            case .recorded:
                let achieved = outcome.isAchieved(threshold: threshold)
                HStack(spacing: 2) {
                    StatusMarker(kind: achieved ? .achieved : .below, size: 5)
                    Text(outcome.percentLabel)
                        .fontWeight(achieved ? .semibold : .regular)
                        .foregroundStyle(achieved ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
                }
                .font(.system(size: 9.5))
                .monospacedDigit()
                .fixedSize()
            case .unrecorded:
                HStack(spacing: 2) {
                    StatusMarker(kind: .unrecorded, size: 5)
                    Text("0%")
                }
                .font(.system(size: 9.5))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .fixedSize()
            case .rest:
                StatusMarker(kind: .rest, size: 8)
            case .preStart, .future:
                Color.clear
            }
        } else {
            Color.clear
        }
    }

    private var spokenLabel: String {
        var parts = [outcome?.spokenSummary(threshold: threshold) ?? "\(day.shortTitle) \(day.weekdaySymbol)요일"]
        if isToday { parts.append("오늘") }
        return parts.joined(separator: ", ")
    }
}
