import SwiftUI

/// 루틴별 최근 수행 기록: 완료 ✓ / 건너뛰기 / 기록 없음 ○ 를 한 줄로 보여 주고 개수를 요약한다.
/// 그 루틴이 예정된 날만 한 번으로 세고, 왼쪽이 오래된 기록, 오른쪽이 가장 최근이다.
struct RoutineHistoryCard: View {
    let histories: [RoutineHistory]
    /// 넓은 화면은 14회, 좁은 화면은 7회.
    let isWide: Bool

    private var count: Int { isWide ? RoutineHistory.wideCount : RoutineHistory.compactCount }

    var body: some View {
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(
                    symbol: "checklist.checked", title: "루틴별 최근 기록", subtitle: "(최근 \(count)회)",
                    tint: GroupColor.purple.color
                )

                if histories.isEmpty {
                    EmptyHint(symbol: "checklist", message: "아직 보여 줄 기록이 없어요.")
                } else {
                    if isWide {
                        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                            ForEach(histories) { history in
                                let marks = history.recent(count)
                                GridRow {
                                    title(history)
                                    RoutineMarkStrip(marks: marks, slots: count, colorKey: history.colorKey, size: 16)
                                    summary(marks)
                                        .gridColumnAlignment(.trailing)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(accessibilityLabel(history, marks))
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(histories) { history in
                                let marks = history.recent(count)
                                VStack(alignment: .leading, spacing: 5) {
                                    title(history)
                                    // 한 줄씩 따로 놓이므로 앞을 비우지 않고 왼쪽부터 채운다.
                                    RoutineMarkStrip(marks: marks, slots: marks.count, colorKey: history.colorKey, size: 20)
                                    summary(marks)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(accessibilityLabel(history, marks))
                            }
                        }
                    }
                    Divider()
                    legend
                }
            }
        }
    }

    private func title(_ history: RoutineHistory) -> some View {
        HStack(spacing: 6) {
            Circle().fill(GroupColor(key: history.colorKey).color).frame(width: 7, height: 7)
            Text(history.title)
                .font(.callout)
                .lineLimit(1)
                .help("\(history.title) · \(history.groupTitle)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summary(_ marks: [RoutineMark]) -> some View {
        Text(RoutineHistory.Summary(marks).text)
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize()
    }

    private func accessibilityLabel(_ history: RoutineHistory, _ marks: [RoutineMark]) -> String {
        "\(history.title), 최근 \(marks.count)회, \(RoutineHistory.Summary(marks).text.replacingOccurrences(of: " · ", with: ", "))"
    }

    /// 표시의 뜻. 색을 구분하지 못해도 모양과 글자로 알 수 있다.
    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { legendItems }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 14) { legendItem(.done); legendItem(.skipped); legendItem(.missed) }
                    HStack(spacing: 14) { legendItem(.pending); legendItem(.vacation) }
                }
            }
            Text("예정된 날만 한 번으로 세요. 건너뛰기는 달성률에서 미달성이고, 휴가는 통계에서 빠져요.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var legendItems: some View {
        legendItem(.done)
        legendItem(.skipped)
        legendItem(.missed)
        legendItem(.pending)
        legendItem(.vacation)
    }

    private func legendItem(_ state: RoutineMarkState) -> some View {
        HStack(spacing: 5) {
            RoutineMarkView(state: state, color: Theme.accent, size: 14)
            Text(state.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

/// 수행 기록 한 줄. 기록이 `slots`보다 적으면 앞을 비워서 가장 최근 것이 늘 오른쪽 끝에 온다.
struct RoutineMarkStrip: View {
    let marks: [RoutineMark]
    let slots: Int
    let colorKey: String
    var size: CGFloat = 16

    var body: some View {
        let color = GroupColor(key: colorKey).color
        HStack(spacing: size * 0.2) {
            ForEach(0..<max(slots - marks.count, 0), id: \.self) { _ in
                Color.clear.frame(width: size, height: size)
            }
            ForEach(marks) { mark in
                RoutineMarkView(state: mark.state, color: color, size: size)
                    .help("\(mark.day.shortTitle) (\(mark.day.weekdaySymbol)) · \(mark.state.label)")
            }
        }
        .accessibilityHidden(true)
    }
}

/// 수행 상태 하나의 표시.
struct RoutineMarkView: View {
    let state: RoutineMarkState
    /// 완료 표시에 쓰는 그룹 색.
    let color: Color
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            switch state {
            case .done:
                Circle().fill(color)
                glyph("checkmark", Theme.onAccent)
            case .skipped:
                Circle().fill(SkipStyle.wash)
                glyph(SkipStyle.symbol, SkipStyle.ink)
            case .missed:
                Circle().strokeBorder(Color.secondary.opacity(0.55), lineWidth: 1.3)
            case .pending:
                Circle().strokeBorder(color, style: StrokeStyle(lineWidth: 1.4, dash: [2.4, 2.2]))
            case .vacation:
                Circle().fill(Theme.vacationTint.opacity(0.18))
                glyph("beach.umbrella.fill", GroupColor.coral.ink)
            }
        }
        .frame(width: size, height: size)
    }

    private func glyph(_ name: String, _ style: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(style)
    }
}
