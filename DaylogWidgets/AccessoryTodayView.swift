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
        Gauge(value: day.ratio ?? day.keptRatio ?? 0) {
            Image(systemName: "leaf.fill")
        } currentValueLabel: {
            Text("\(day.done)/\(day.total)").monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
        .accessibilityLabel("오늘 \(day.total)개 중 \(day.done)개 완료")
    }

    private func inline(_ day: WidgetDay) -> some View {
        let next = day.nextToShow(nowMinutes: entry.nowMinutes)
        return Text(next.map { "\(day.done)/\(day.total) · 다음 \($0.title)" } ?? "오늘 \(day.done)/\(day.total) 완료")
    }

    @ViewBuilder private func rectangular(_ day: WidgetDay) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "leaf.fill").font(.caption2).widgetAccentable()
                Text("오늘 \(day.done)/\(day.total)").font(.caption.weight(.semibold)).monospacedDigit()
            }
            if day.done == day.total {
                Text("오늘 루틴 완료!").font(.headline).widgetAccentable()
            } else if let item = day.nextToShow(nowMinutes: entry.nowMinutes) {
                // 누르면 앱을 열지 않고 바로 완료(잠금이 풀려 있을 때).
                Button(intent: ToggleRoutineIntent(routineID: item.routineID, dateKey: day.dateKey, isDone: !item.requestedIsDone)) {
                    HStack(spacing: 5) {
                        Image(systemName: item.requestedIsDone ? "checkmark.circle.fill" : "circle")
                            .widgetAccentable()
                        Text(item.title).font(.headline).lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("누르면 완료로 표시합니다.")
                if let minutes = TimeLabel.minutes(item.timeLabel) {
                    Text(TimeLabel.label(minutes: minutes)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
            } else {
                Text("남은 루틴 없음").font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
