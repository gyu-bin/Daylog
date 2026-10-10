import SwiftUI

/// 날짜별 기록 표. 행을 누르면 그 날짜로 이동한다. 대시보드(7일)와 통계(30일)가 같이 쓴다.
struct RecentDaysCard: View {
    @Environment(AppStore.self) private var store
    let title: String
    /// 최신 날짜가 위.
    let outcomes: [DayOutcome]
    var showsAllLink = true

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(symbol: "calendar.badge.clock", title: title) {
                    if showsAllLink {
                        HeaderLink(title: "전체 보기") {
                            store.section = .statistics
                        }
                    }
                }

                if !store.stats.hasStarted {
                    EmptyHint(symbol: "tablecells", message: "루틴을 기록하면 여기에 하루씩 쌓여요.")
                } else {
                    VStack(spacing: 0) {
                        DayRowLayout {
                            Text("날짜")
                            Text("요일")
                            Text("완료/전체")
                            Text("달성률")
                            Text("진행 바")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                        .background(Theme.track.opacity(0.6))
                        .accessibilityHidden(true)

                        ForEach(outcomes) { outcome in
                            Divider()
                            DayRow(outcome: outcome, threshold: store.threshold, isSelected: isSelected(outcome)) {
                                store.open(outcome.day)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.separator, lineWidth: 1))
                }
            }
        }
    }

    private func isSelected(_ outcome: DayOutcome) -> Bool {
        store.section == .dashboard && outcome.day == store.selectedDay
    }
}

/// 날짜 | 요일 | 완료/전체 | 달성률 | 진행 바. 루틴 개수가 달라도 열 너비가 고정된다.
private struct DayRowLayout<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ColumnsLayout {
            content()
        }
        .padding(.horizontal, 10)
    }
}

private struct ColumnsLayout: Layout {
    /// 날짜, 요일, 완료/전체, 달성률은 고정 너비. 진행 바가 남는 폭을 가진다.
    private static let fixed: [CGFloat] = [74, 30, 62, 46]
    private static let spacing: CGFloat = 6
    private static let minimumBar: CGFloat = 36

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        let minimum = Self.fixed.reduce(0, +) + Self.spacing * 4 + Self.minimumBar
        return CGSize(width: max(proposal.width ?? minimum, minimum), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let remaining = bounds.width - Self.fixed.reduce(0, +) - Self.spacing * 4
        let widths = Self.fixed + [max(remaining, Self.minimumBar)]
        var x = bounds.minX
        for (index, subview) in subviews.enumerated() where index < widths.count {
            let width = widths[index]
            // 날짜와 진행 바는 왼쪽 정렬, 나머지는 가운데 정렬.
            let alignLeading = index == 0 || index == widths.count - 1
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            let offset = alignLeading ? 0 : (width - min(size.width, width)) / 2
            subview.place(
                at: CGPoint(x: x + offset, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(width: width, height: nil)
            )
            x += width + Self.spacing
        }
    }
}

private struct DayRow: View {
    let outcome: DayOutcome
    let threshold: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            DayRowLayout {
                Text(outcome.day.shortTitle)
                Text(outcome.day.weekdaySymbol)
                Text(outcome.countLabel)
                    .foregroundStyle(outcome.status == .recorded ? .primary : .secondary)
                Text(outcome.percentLabel)
                ProgressBar(ratio: outcome.ratio ?? 0, height: 10, tint: outcome.tint(threshold: threshold))
            }
            .font(.callout)
            .monospacedDigit()
            .lineLimit(1)
            .padding(.vertical, 7)
            .background(isSelected ? Theme.accentWash : (isHovered ? Theme.track.opacity(0.5) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(outcome.spokenSummary(threshold: threshold))
        .accessibilityHint("이 날짜의 기록으로 이동")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
