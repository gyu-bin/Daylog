import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// 잠금 화면·다이내믹 아일랜드의 "오늘의 루틴" 카드(라이브 액티비티).
struct RoutineLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoutineActivityAttributes.self) { context in
            RoutineLiveActivityCard(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(GroupColor.mint.ink)
                .widgetURL(URL(string: "daylog://today"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image("pio_mini_\(context.state.outfit ?? "basic")").resizable().scaledToFit().frame(width: 24, height: 24)
                        Text("오늘의 루틴").font(.caption.weight(.semibold))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.done)/\(context.state.total)").font(.headline).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ForEach(context.state.items.prefix(2)) { item in
                            RoutineLiveActivityRow(item: item, dateKey: context.state.dateKey, compact: true)
                        }
                    }
                }
            } compactLeading: {
                Image("pio_mini_\(context.state.outfit ?? "basic")").resizable().scaledToFit().frame(width: 20, height: 20)
            } compactTrailing: {
                Text("\(context.state.done)/\(context.state.total)").monospacedDigit().font(.caption.weight(.semibold))
            } minimal: {
                Text("\(context.state.total - context.state.done)").monospacedDigit().font(.caption.weight(.bold))
                    .foregroundStyle(GroupColor.mint.color)
            }
            .widgetURL(URL(string: "daylog://today"))
        }
    }
}

struct RoutineLiveActivityCard: View {
    let state: RoutineActivityAttributes.ContentState
    private var ratio: Double { state.total == 0 ? 0 : Double(state.done) / Double(state.total) }
    private var allDone: Bool { state.total > 0 && state.done >= state.total }
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image("pio_mini_\(state.outfit ?? "basic")")
                    .resizable().scaledToFit()
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("오늘의 루틴").font(.system(size: 15, weight: .bold))
                    Text(allDone ? "오늘 다 해냈어요!" : "\(state.total - state.done)개 남았어요")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text("\(state.done)/\(state.total)")
                    .font(.system(size: 13, weight: .bold)).monospacedDigit()
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(GroupColor.mint.color.opacity(0.22), in: Capsule())
                    .foregroundStyle(GroupColor.mint.color)
            }
            WidgetBar(ratio: ratio, tint: GroupColor.mint.color, height: 5)
            if allDone {
                Label("모든 루틴을 끝냈어요", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GroupColor.mint.color)
                    .frame(maxWidth: .infinity, minHeight: 36)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(state.items) { item in
                        RoutineLiveActivityTile(item: item, dateKey: state.dateKey)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}

/// 2×2 칸의 한 칸. 누르면 바로 완료/취소.
struct RoutineLiveActivityTile: View {
    let item: RoutineActivityAttributes.Item
    let dateKey: String

    var body: some View {
        Button(intent: ToggleRoutineLiveIntent(routineID: item.routineID, dateKey: dateKey, isDone: !item.isDone)) {
            HStack(spacing: 7) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(item.isDone ? GroupColor.mint.color : Color.white.opacity(0.55))
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .strikethrough(item.isDone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(Color.white.opacity(item.isDone ? 0.05 : 0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.isDone ? "완료" : "미완료")
        .accessibilityHint(item.isDone ? "누르면 완료를 취소합니다." : "누르면 완료로 표시합니다.")
    }
}

/// 다이내믹 아일랜드를 펼쳤을 때의 한 줄.
struct RoutineLiveActivityRow: View {
    let item: RoutineActivityAttributes.Item
    let dateKey: String
    let compact: Bool

    var body: some View {
        Button(intent: ToggleRoutineLiveIntent(routineID: item.routineID, dateKey: dateKey, isDone: !item.isDone)) {
            HStack(spacing: 8) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? GroupColor.mint.color : .secondary)
                Text(item.title).font(.subheadline.weight(.medium)).lineLimit(1)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                Spacer(minLength: 6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.isDone ? "완료" : "미완료")
    }
}
