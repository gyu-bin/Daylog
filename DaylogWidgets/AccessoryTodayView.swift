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
        return Text(next.map { "\(day.done)/\(day.total) · 다음 \($0.title)" } ?? "오늘 \(day.done)/\(day.total) 완료")
    }

    /// 직사각형: 반투명 바탕 카드 위에 왼쪽 진행 링, 오른쪽 다음 루틴(눌러서 완료). 칸을 꽉 채운다.
    private func rectangular(_ day: WidgetDay) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            HStack(spacing: 8) {
                Gauge(value: day.ratio ?? day.keptRatio ?? 0) {
                    Text("")
                } currentValueLabel: {
                    Text("\(day.done)/\(day.total)").font(.system(size: 13, weight: .bold)).monospacedDigit()
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .widgetAccentable()
                .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 1) {
                    if day.done == day.total {
                        Text("오늘 루틴").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Text("모두 완료!").font(.system(size: 17, weight: .bold)).widgetAccentable()
                    } else if let item = day.nextToShow(nowMinutes: entry.nowMinutes) {
                        Text(TimeLabel.minutes(item.timeLabel).map { "다음 · \(TimeLabel.label(minutes: $0))" } ?? "다음 루틴")
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
                        Text("오늘 루틴").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Text("남은 루틴 없음").font(.system(size: 17, weight: .bold))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
        }
    }
}
