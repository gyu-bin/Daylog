import AppIntents
import SwiftUI
import WidgetKit

/// 잠금 화면 위젯(2026-10-26): 동그라미(달성률), 직사각형(다음 루틴을 눌러 완료), 한 줄(진행 요약).
struct AccessoryTodayView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        switch entry.content {
        case .day(let day) where !day.isVacationRest:
            switch family {
            case .accessoryCircular: circular(day)
            case .accessoryInline: inline(day)
            default: rectangular(day)
            }
        case .day:
            label("오늘은 휴가", symbol: "sun.horizon.fill")
        case .noRoutines:
            label("루틴을 추가해 보세요", symbol: "checklist")
        case .needsApp:
            label("RoutiMori를 열어 주세요", symbol: "arrow.up.forward.app")
        }
    }

    @ViewBuilder private func label(_ text: String, symbol: String) -> some View {
        if family == .accessoryCircular {
            Image(systemName: symbol).font(.title3).widgetAccentable()
        } else {
            Label(text, systemImage: symbol)
        }
    }

    private func circular(_ day: WidgetDay) -> some View {
        ZStack {
        AccessoryWidgetBackground()
        Gauge(value: day.ratio ?? day.keptRatio ?? 0) {
            Image(systemName: "leaf.fill")
        } currentValueLabel: {
            Text("\(day.done)/\(day.total)").monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
        .accessibilityLabel("오늘 \(day.total)개 중 \(day.done)개 완료")
        }
    }

    private func inline(_ day: WidgetDay) -> some View {
        let next = day.nextToShow(nowMinutes: entry.nowMinutes)
        let skipped = day.skipped > 0 ? " · \(SkipStyle.label) \(day.skipped)" : ""
        return Text(next.map { "\(day.done)/\(day.total) · 다음 \($0.title)" } ?? "오늘 \(day.done)/\(day.total) 완료\(skipped)")
    }

    /// 직사각형(2026-10-30 피오 중심): 왼쪽 진행 링 안에 피오, 오른쪽에 피오가 알려 주는 다음 루틴(눌러서 완료).
    /// 잠금 화면 위젯은 시스템이 한 가지 색으로 칠하므로 피오도 단색 톤으로 보인다.
    private func rectangular(_ day: WidgetDay) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            HStack(spacing: 8) {
                ZStack {
                    Gauge(value: day.ratio ?? day.keptRatio ?? 0) {
                        Text("")
                    } currentValueLabel: {
                        Text("")
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .widgetAccentable()
                    Image("pio_mini_\(RoutineLiveActivityOutfit.current ?? "basic")")
                        .resizable().scaledToFit()
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)
                }
                .frame(width: 46, height: 46)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("오늘 \(day.total)개 중 \(day.done)개 완료")
                VStack(alignment: .leading, spacing: 1) {
                    if day.remaining > 0, let item = day.nextToShow(nowMinutes: entry.nowMinutes) {
                        Text(TimeLabel.minutes(item.timeLabel).map { "피오: \(TimeLabel.label(minutes: $0))에" } ?? "피오: 다음은")
                            .font(.system(size: 12, weight: .medium)).monospacedDigit().foregroundStyle(.secondary)
                        // 누르면 앱을 열지 않고 바로 완료(잠금이 풀려 있을 때).
                        Button(intent: ToggleRoutineIntent(routineID: item.routineID, dateKey: day.dateKey, isDone: !item.requestedIsDone)) {
                            HStack(spacing: 4) {
                                Image(systemName: item.requestedIsDone ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 15, weight: .semibold))
                                    .widgetAccentable()
                                Text(item.title).font(.system(size: 17, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("누르면 완료로 표시합니다.")
                    } else {
                        // 남은 것이 없다(건너뛴 것만 남은 날도). 건너뛴 수는 따로 적는다(달성률은 그대로).
                        Text(day.skipped > 0 ? "피오 · \(SkipStyle.label) \(day.skipped)" : "피오")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Text(day.total == 0 ? "오늘은 쉬는 날" : day.done >= day.total ? "오늘 다 해냈어요!" : "오늘 끝! 잘했어요")
                            .font(.system(size: 16, weight: .bold)).lineLimit(1).minimumScaleFactor(0.8)
                            .widgetAccentable()
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
        }
    }
}
