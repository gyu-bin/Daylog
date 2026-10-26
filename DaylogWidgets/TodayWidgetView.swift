import SwiftUI
import WidgetKit

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        switch entry.content {
        case .needsApp:
            WidgetNotice(symbol: "arrow.up.forward.app", title: "RoutiMori를 열어 주세요", detail: "오늘의 루틴을 불러와요.")
        case .noRoutines:
            WidgetNotice(symbol: "checklist", title: "아직 루틴이 없어요", detail: "RoutiMori에서 루틴을 추가해 보세요.")
        case .day(let day):
            if day.isVacationRest {
                WidgetNotice(symbol: "sun.horizon.fill", title: "오늘은 휴가", detail: "루틴 통계에서 제외돼요. 기존 기록은 보관돼요.")
            } else {
            switch family {
            case .systemSmall: SmallTodayView(day: day, nowMinutes: entry.nowMinutes)
            case .systemMedium: MediumTodayView(day: day)
            case .systemExtraLarge: ExtraLargeTodayView(day: day, date: entry.date)
            default: LargeTodayView(day: day, date: entry.date)
            }
            }
        }
    }
}

/// 위젯 머리의 상표.
struct WidgetBrand: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "leaf.fill")
                .font(.caption2)
                .foregroundStyle(GroupColor.mint.color)
            Text("RoutiMori")
                .font(.caption.weight(.semibold))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("RoutiMori")
    }
}

/// 데이터가 없을 때의 안내.
struct WidgetNotice: View {
    @Environment(\.widgetFamily) private var family
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetBrand()
            Spacer(minLength: 0)
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.callout.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // 큰 위젯에서는 안내가 맨 아래에 몰려 위가 텅 비어 보인다. 가운데 높이에 둔다.
            if family == .systemLarge {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// 얇은 진행 막대.
struct WidgetBar: View {
    let ratio: Double
    var tint: Color = GroupColor.mint.color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                if ratio > 0 {
                    Capsule().fill(tint).frame(width: max(height, proxy.size.width * min(ratio, 1)))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - 작게

/// 달성률, 완료/전체, 다음 루틴과 그 시간.
struct SmallTodayView: View {
    let day: WidgetDay
    let nowMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            WidgetBrand()
            if day.hasPending { Text("저장 대기 · 앱에서 확인").font(.caption2).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
            if let percent = day.percent {
                Text("오늘 \(percent)%")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(GroupColor.mint.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("\(day.done)/\(day.total) 완료")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                WidgetBar(ratio: day.ratio ?? 0)
                    .padding(.vertical, 3)
                next
            } else if let ratio = day.keptRatio {
                // 휴가 중에 이어 가는 루틴. 달성률(통계)은 쉬므로 퍼센트 대신 개수로 보여 준다.
                Text("휴가 중")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(GroupColor.coral.ink)
                    .lineLimit(1)
                Text("유지 루틴 \(day.done)/\(day.total)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                WidgetBar(ratio: ratio, tint: GroupColor.coral.color)
                    .padding(.vertical, 3)
                next
            } else {
                Text("오늘은 쉬는 날")
                    .font(.callout.weight(.semibold))
                Text("예정된 루틴이 없어요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var next: some View {
        if day.done == day.total {
            Label("오늘 루틴 완료", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GroupColor.mint.ink)
                .lineLimit(1)
        } else if day.remaining == 0 {
            // 남은 것을 모두 건너뛰었다. 달성률은 그대로이고, 더 챙길 것이 없다는 것만 알린다.
            Label("남은 루틴 없음", systemImage: SkipStyle.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else if let item = day.nextToShow(nowMinutes: nowMinutes) {
            // 다음 루틴을 누르면 앱을 열지 않고 바로 완료된다(2026-10-26).
            Button(intent: ToggleRoutineIntent(routineID: item.routineID, dateKey: day.dateKey, isDone: !item.requestedIsDone)) {
                HStack(spacing: 6) {
                    Image(systemName: item.requestedIsDone ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                        .foregroundStyle(GroupColor.mint.color)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.pendingIsDone != nil ? "저장 대기" : TimeLabel.minutes(item.timeLabel) == nil ? "눌러서 완료" : "다음 루틴 · 눌러서 완료")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        // 이름이 길면 줄이고, 시간은 항상 다 보이게 한다.
                        HStack(spacing: 4) {
                            Text(item.title)
                                .lineLimit(1)
                            if let minutes = TimeLabel.minutes(item.timeLabel) {
                                Text(TimeLabel.label(minutes: minutes))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                            }
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("다음 루틴 \(item.title)")
            .accessibilityHint("누르면 완료로 표시합니다.")
        }
    }
}

// MARK: - 중간

/// 체크할 수 있는 루틴 목록(남은 것부터, 최대 4개). 누르면 바로 완료/취소된다(2026-10-26).
struct MediumTodayView: View {
    let day: WidgetDay
    private static let maxItems = 4

    private var items: [(item: WidgetItem, colorKey: String)] {
        let all = day.groups.flatMap { group in group.items.map { (item: $0, colorKey: group.colorKey) } }
        let open = all.filter { !$0.item.isSettled }
        let settled = all.filter { $0.item.isSettled }
        return Array((open + settled).prefix(Self.maxItems))
    }

    var body: some View {
        let hidden = day.total - items.count
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                WidgetBrand()
                Spacer(minLength: 8)
                if let percent = day.percent {
                    Text("오늘 \(percent)% · \(day.done)/\(day.total)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(GroupColor.mint.ink)
                } else if day.keptRatio != nil {
                    Text("휴가 중 · \(day.done)/\(day.total)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(GroupColor.coral.ink)
                }
            }
            WidgetBar(ratio: day.ratio ?? day.keptRatio ?? 0, tint: day.keptRatio != nil ? GroupColor.coral.color : GroupColor.mint.color, height: 5)
                .padding(.bottom, 2)
            if items.isEmpty {
                Spacer(minLength: 0)
                Text("오늘은 예정된 루틴이 없어요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(items, id: \.item.id) { entry in
                    WidgetCheckRow(item: entry.item, dateKey: day.dateKey, tint: GroupColor(key: entry.colorKey).color, font: .subheadline)
                }
                if hidden > 0 {
                    Text("외 \(hidden)개")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - 특대(iPad)

/// iPad 특대 위젯: 왼쪽에 오늘 요약, 오른쪽에 체크 목록.
struct ExtraLargeTodayView: View {
    let day: WidgetDay
    let date: Date

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                WidgetBrand()
                Text(date, format: .dateTime.month().day().weekday(.wide))
                    .font(.caption).foregroundStyle(.secondary)
                if let percent = day.percent {
                    Text("\(percent)%")
                        .font(.system(size: 44, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(GroupColor.mint.ink)
                    Text("\(day.done)/\(day.total) 완료")
                        .font(.callout).monospacedDigit().foregroundStyle(.secondary)
                    WidgetBar(ratio: day.ratio ?? 0, height: 8)
                }
                ForEach(day.groups.filter { !$0.items.isEmpty }.prefix(5)) { group in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(group.title).font(.caption.weight(.medium)).lineLimit(1)
                            Spacer(minLength: 6)
                            Text("\(group.done)/\(group.items.count)").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                        WidgetBar(ratio: group.ratio, tint: GroupColor(key: group.colorKey).color, height: 6)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(width: 210)
            LargeTodayView(day: day, date: date, maxRows: 14)
        }
    }
}
