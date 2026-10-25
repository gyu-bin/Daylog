import SwiftUI

/// 그룹별 달성률(달성률 내림차순). 각 날짜는 그날 속해 있던 그룹으로 집계한다.
/// 그룹을 누르면 옆의 항목 표가 그 그룹의 항목으로 좁혀진다.
struct GroupRatesCard: View {
    let rates: [GroupRate]
    let periodLabel: String
    @Binding var selection: UUID?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(symbol: "square.stack.3d.up.fill", title: "그룹별 달성률", subtitle: "(\(periodLabel))", tint: Theme.weekTint)

                if rates.isEmpty {
                    EmptyHint(symbol: "square.stack", message: "이 기간에 예정된 루틴이 없었어요.")
                } else {
                    VStack(spacing: 4) {
                        ForEach(rates) { rate in
                            row(rate)
                        }
                    }
                    Text("그룹을 누르면 그 그룹의 항목만 볼 수 있어요.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func row(_ rate: GroupRate) -> some View {
        let color = GroupColor(key: rate.colorKey)
        let isSelected = selection == rate.groupID
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        return Button {
            selection = isSelected ? nil : rate.groupID
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    GroupBadge(title: rate.title, color: color, size: 20)
                    Text(rate.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(rate.isArchived || rate.isRemoved ? .secondary : .primary)
                        // 큰 글자에서는 그룹 이름을 자르지 않고 줄을 넘긴다.
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                    RateStateBadge(isArchived: rate.isArchived, isRemoved: rate.isRemoved)
                    Spacer(minLength: 6)
                    Text("\(rate.percent)%")
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                        .fixedSize()
                }
                ProgressBar(ratio: rate.ratio, height: 7, tint: color.color)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? color.wash : .clear, in: shape)
            .overlay(shape.strokeBorder(isSelected ? color.color.opacity(0.7) : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 버튼에 직접 이름을 붙인다(요소를 새로 만들면 누르기 동작이 사라진다).
        .accessibilityLabel("\(rate.title) 그룹\(rate.isRemoved ? ", 삭제됨" : rate.isArchived ? ", 보관됨" : "")")
        .accessibilityValue("달성률 \(rate.percent)%, 예정 \(rate.scheduled)개 중 \(rate.done)개 완료")
        .accessibilityHint(isSelected ? "누르면 전체 항목을 다시 봅니다." : "누르면 이 그룹의 항목만 봅니다.")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// 항목별 달성률 표: 항목, 그룹, 완료한 날, 예정된 날, 달성률.
struct ItemRatesCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let rates: [RoutineRate]
    let periodLabel: String
    /// 이 그룹의 항목만 보고 있다. nil이면 전체.
    let group: GroupRate?
    let clearGroup: () -> Void

    var body: some View {
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(
                    symbol: "list.bullet.rectangle.fill",
                    title: group.map { "\($0.title) 항목 달성률" } ?? "항목별 달성률",
                    subtitle: "(\(periodLabel))",
                    tint: group.map { GroupColor(key: $0.colorKey).color } ?? Theme.accent
                ) {
                    if group != nil {
                        Button("전체 항목 보기", action: clearGroup)
                            .controlSize(.small)
                    }
                }

                if rates.isEmpty {
                    EmptyHint(
                        symbol: "list.bullet",
                        message: group == nil ? "이 기간에 예정된 루틴이 없었어요." : "이 그룹에 지금 속한 항목이 없어요."
                    )
                } else if dynamicTypeSize.isAccessibilitySize {
                    stackedRows
                } else {
                    table
                }
            }
        }
    }

    /// 큰 글자 크기: 표의 네 칸이 한 줄에 들어가지 않는다. 이름을 한 줄 전체에 쓰고 숫자는 아랫줄에 둔다.
    private var stackedRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(rates) { rate in
                let color = GroupColor(key: rate.colorKey).color
                let groupTitle = rate.groupTitle.isEmpty ? RoutineGroup.defaultTitle : rate.groupTitle
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle().fill(color).frame(width: 7, height: 7)
                        Text(rate.title)
                            .foregroundStyle(rate.isArchived || rate.isRemoved ? .secondary : .primary)
                            .lineLimit(3)
                        RateStateBadge(isArchived: rate.isArchived, isRemoved: rate.isRemoved)
                    }
                    // 한 줄에 들어가면 나란히, 아니면 달성률을 아랫줄로 내린다
                    // (나란히 고정하면 "완료 1일 · 예정 1일"이 몇 글자 폭의 열로 눌렸다).
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            rateCounts(rate).fixedSize()
                            Spacer(minLength: 4)
                            ratePercent(rate)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            rateCounts(rate)
                            ratePercent(rate)
                        }
                    }
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(rate.title)\(rate.isRemoved ? ", 삭제됨" : rate.isArchived ? ", 보관됨" : ""), \(groupTitle) 그룹")
                .accessibilityValue("달성률 \(rate.percent)%, 예정 \(rate.scheduled)일 중 \(rate.done)일 완료")
            }
        }
    }

    private func rateCounts(_ rate: RoutineRate) -> some View {
        Text("완료 \(rate.done)일 · 예정 \(rate.scheduled)일")
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }

    private func ratePercent(_ rate: RoutineRate) -> some View {
        Text("\(rate.percent)%")
            .fontWeight(.semibold)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
    }

    private var table: some View {
        // 좁은 화면(iPhone)에서는 그룹 이름 칸을 빼고 색 점만 남긴다. 다섯 칸을 다 넣으면 항목 이름이 잘리고 "100%"가 두 줄로 꺾인다.
        let isCompact = horizontalSizeClass == .compact
        return Grid(alignment: .leading, horizontalSpacing: isCompact ? 8 : 12, verticalSpacing: 9) {
            GridRow {
                Text("항목")
                if !isCompact { Text("그룹") }
                Text("완료").gridColumnAlignment(.trailing)
                Text("예정").gridColumnAlignment(.trailing)
                Text("달성률").gridColumnAlignment(.trailing)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)

            Divider().gridCellUnsizedAxes(.horizontal)

            ForEach(rates) { rate in
                let color = GroupColor(key: rate.colorKey).color
                let groupTitle = rate.groupTitle.isEmpty ? RoutineGroup.defaultTitle : rate.groupTitle
                GridRow {
                    HStack(spacing: 6) {
                        if isCompact {
                            Circle().fill(color).frame(width: 7, height: 7)
                        }
                        Text(rate.title)
                            .foregroundStyle(rate.isArchived || rate.isRemoved ? .secondary : .primary)
                            .lineLimit(isCompact ? 2 : 1)
                            .help(rate.title)
                        RateStateBadge(isArchived: rate.isArchived, isRemoved: rate.isRemoved)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !isCompact {
                        HStack(spacing: 5) {
                            Circle().fill(color).frame(width: 7, height: 7)
                            Text(groupTitle)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: 120, alignment: .leading)
                    }

                    Text("\(rate.done)일").monospacedDigit().fixedSize()
                    Text("\(rate.scheduled)일").monospacedDigit().foregroundStyle(.secondary).fixedSize()
                    HStack(spacing: 8) {
                        ProgressBar(ratio: rate.ratio, height: 7, tint: color)
                            .frame(width: isCompact ? 36 : 56)
                        // 글자 크기를 키워도 "100%"가 줄바꿈되지 않게 너비를 고정하지 않는다.
                        Text("\(rate.percent)%")
                            .font(.callout.weight(.semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .fixedSize()
                            .frame(minWidth: 40, alignment: .trailing)
                    }
                }
                .font(.callout)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(rate.title)\(rate.isRemoved ? ", 삭제됨" : rate.isArchived ? ", 보관됨" : ""), \(groupTitle) 그룹")
                .accessibilityValue("달성률 \(rate.percent)%, 예정 \(rate.scheduled)일 중 \(rate.done)일 완료")
            }
        }
    }
}

/// 보관했거나 삭제한 그룹·항목 표시. 지난 기록이 기간 안에 있으면 통계에는 계속 나온다.
private struct RateStateBadge: View {
    let isArchived: Bool
    let isRemoved: Bool

    var body: some View {
        if isRemoved {
            StatusBadge(text: "삭제됨")
        } else if isArchived {
            StatusBadge(text: "보관됨")
        }
    }
}
