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
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.displayLine).font(.subheadline.weight(.semibold)).lineLimit(1)
                        ForEach(context.state.openItems.prefix(2)) { item in
                            RoutineLiveActivityRow(item: item, dateKey: context.state.dateKey, compact: true)
                        }
                    }
                }
            } compactLeading: {
                Image("pio_mini_\(context.state.outfit ?? "basic")").resizable().scaledToFit().frame(width: 20, height: 20)
            } compactTrailing: {
                Text("\(context.state.done)/\(context.state.total)").monospacedDigit().font(.caption.weight(.semibold))
            } minimal: {
                Text("\(context.state.remaining)").monospacedDigit().font(.caption.weight(.bold))
                    .foregroundStyle(GroupColor.mint.color)
            }
            .widgetURL(URL(string: "daylog://today"))
        }
    }
}

/// 잠금 화면 카드(2026-10-30 피오 중심): 큰 피오가 말풍선으로 오늘 상황을 말하고, 아래에는 남은 루틴만 놓는다.
/// 완료·건너뜀은 말풍선 아래 한 줄로 모은다. 잠금 화면 카드의 높이 한도(약 160pt) 안에 들어가게 잡았다.
struct RoutineLiveActivityCard: View {
    let state: RoutineActivityAttributes.ContentState
    private var isFinished: Bool { state.total > 0 && state.remaining == 0 }
    private var open: [RoutineActivityAttributes.Item] { state.openItems }
    private let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 2) {
                Image("pio_mini_\(state.outfit ?? "basic")")
                    .resizable().scaledToFit()
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    LiveActivityBubble(text: state.displayLine)
                    RoutineLiveActivitySummary(state: state, hiddenOpen: max(state.remaining - open.count, 0))
                        .padding(.leading, 8)
                }
                Spacer(minLength: 0)
            }
            if !isFinished && !open.isEmpty {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(open) { item in
                        RoutineLiveActivityTile(item: item, dateKey: state.dateKey)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
    }
}

/// 말풍선 아래의 작은 줄: 완료·건너뜀·칸에 다 못 놓은 남은 루틴 수.
struct RoutineLiveActivitySummary: View {
    let state: RoutineActivityAttributes.ContentState
    let hiddenOpen: Int

    var body: some View {
        HStack(spacing: 10) {
            if state.done > 0 {
                Label("완료 \(state.done)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(GroupColor.mint.color)
            }
            if let skipped = state.skipped, skipped > 0 {
                Label("\(SkipStyle.label) \(skipped)", systemImage: "\(SkipStyle.symbol).circle.fill")
                    .foregroundStyle(SkipStyle.color)
            }
            if hiddenOpen > 0 {
                Text("외 \(hiddenOpen)개").foregroundStyle(.secondary)
            }
            if state.done == 0, (state.skipped ?? 0) == 0, hiddenOpen == 0 {
                Text("오늘의 루틴 \(state.total)개").foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .labelStyle(CompactLabelStyle())
        .lineLimit(1)
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) { configuration.icon; configuration.title.foregroundStyle(Color.white.opacity(0.75)) }
    }
}

/// 피오의 말풍선. 왼쪽(피오 쪽)에 짧은 꼬리가 있다(앱의 말풍선과 같은 모양).
struct LiveActivityBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.black.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.leading, 18).padding(.trailing, 12).padding(.vertical, 7)
            .background(LiveActivityBubbleShape().fill(Color.white.opacity(0.94)))
            .accessibilityLabel("피오: \(text)")
    }
}

struct LiveActivityBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tail: CGFloat = 8
        let body = CGRect(x: rect.minX + tail, y: rect.minY, width: rect.width - tail, height: rect.height)
        var path = Path(roundedRect: body, cornerRadius: min(16, body.height / 2), style: .continuous)
        let mid = body.midY
        var tip = Path()
        tip.move(to: CGPoint(x: body.minX + 1, y: mid - 7))
        tip.addQuadCurve(to: CGPoint(x: rect.minX, y: mid + 3), control: CGPoint(x: body.minX - 2, y: mid))
        tip.addQuadCurve(to: CGPoint(x: body.minX + 1, y: mid + 6), control: CGPoint(x: body.minX - 1, y: mid + 5))
        tip.closeSubpath()
        path.addPath(tip)
        return path
    }
}

/// 남은 루틴 한 칸(최대 2×2). 누르면 바로 완료/취소.
struct RoutineLiveActivityTile: View {
    let item: RoutineActivityAttributes.Item
    let dateKey: String

    var body: some View {
        Button(intent: ToggleRoutineLiveIntent(routineID: item.routineID, dateKey: dateKey, isDone: !item.isDone)) {
            HStack(spacing: 7) {
                RoutineLiveActivityMark(item: item, inactive: Color.white.opacity(0.55))
                    .font(.system(size: 17, weight: .medium))
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(item.isDone || item.showsSkipped ? .secondary : .primary)
                    .strikethrough(item.isDone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(Color.white.opacity(item.isDone || item.showsSkipped ? 0.05 : 0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.isDone ? "완료" : item.showsSkipped ? SkipStyle.label : "미완료")
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
                RoutineLiveActivityMark(item: item, inactive: .secondary)
                Text(item.title).font(.subheadline.weight(.medium)).lineLimit(1)
                    .foregroundStyle(item.isDone || item.showsSkipped ? .secondary : .primary)
                Spacer(minLength: 6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.isDone ? "완료" : item.showsSkipped ? SkipStyle.label : "미완료")
    }
}

/// 카드의 체크 표시: 완료(민트 체크), 건너뜀(노란 −, 앱·홈 화면 위젯과 같은 색), 미완료(빈 동그라미).
/// 건너뛴 칸을 누르면 완료가 된다(앱의 체크 칸과 같다).
struct RoutineLiveActivityMark<Inactive: ShapeStyle>: View {
    let item: RoutineActivityAttributes.Item
    let inactive: Inactive

    var body: some View {
        if item.isDone {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(GroupColor.mint.color)
        } else if item.showsSkipped {
            Image(systemName: "\(SkipStyle.symbol).circle.fill").foregroundStyle(SkipStyle.color)
        } else {
            Image(systemName: "circle").foregroundStyle(inactive)
        }
    }
}
