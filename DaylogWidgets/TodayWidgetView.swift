import SwiftUI
import WidgetKit

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        switch entry.content {
        case .needsApp:
            WidgetNotice(symbol: "arrow.up.forward.app", title: "Daylog를 열어 주세요", detail: "오늘의 루틴을 불러와요.")
        case .noRoutines:
            WidgetNotice(symbol: "checklist", title: "아직 루틴이 없어요", detail: "Daylog에서 루틴을 추가해 보세요.")
        case .day(let day):
            if day.isVacation == true {
                WidgetNotice(symbol: "sun.horizon.fill", title: "오늘은 휴가", detail: "루틴 통계에서 제외돼요. 기존 기록은 보관돼요.")
            } else {
            switch family {
            case .systemSmall: SmallTodayView(day: day, nowMinutes: entry.nowMinutes)
            case .systemMedium: MediumTodayView(day: day)
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
            Text("Daylog")
                .font(.caption.weight(.semibold))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daylog")
    }
}

/// 데이터가 없을 때의 안내.
struct WidgetNotice: View {
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
        } else if let item = day.nextToShow(nowMinutes: nowMinutes) {
            VStack(alignment: .leading, spacing: 0) {
                Text(TimeLabel.minutes(item.timeLabel) == nil ? "남은 루틴" : "다음 루틴")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
    }
}

// MARK: - 중간

/// 그룹별 진행 상황. 자리가 모자라면 아직 남은 그룹부터 보여 준다.
struct MediumTodayView: View {
    let day: WidgetDay
    private static let maxGroups = 3

    private var groups: [WidgetGroup] {
        let filled = day.groups.filter { !$0.items.isEmpty }
        let pending = filled.filter { $0.done < $0.items.count }
        let finished = filled.filter { $0.done == $0.items.count }
        return Array((pending + finished).prefix(Self.maxGroups))
    }

    var body: some View {
        let hidden = day.groups.filter { !$0.items.isEmpty }.count - groups.count
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                WidgetBrand()
                Spacer(minLength: 8)
                if let percent = day.percent {
                    Text("오늘 \(percent)% · \(day.done)/\(day.total)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(GroupColor.mint.ink)
                }
            }
            if day.hasPending { Text("저장 대기 · 앱에서 확인").font(.caption2).foregroundStyle(.secondary) }
            if groups.isEmpty {
                Spacer(minLength: 0)
                Text("오늘은 예정된 루틴이 없어요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(groups) { group in
                    let color = GroupColor(key: group.colorKey)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(group.title)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text("\(group.done)/\(group.items.count)")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        WidgetBar(ratio: group.ratio, tint: color.color, height: 7)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(group.title), \(group.items.count)개 중 \(group.done)개 완료")
                }
                if hidden > 0 {
                    Text("외 \(hidden)개 그룹")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
