import AppIntents
import SwiftUI
import WidgetKit

/// 오늘의 체크 목록. 항목을 누르면 완료/취소가 바뀐다(색이 아니라 체크 표시로 구분한다).
struct LargeTodayView: View {
    let day: WidgetDay
    let date: Date
    private static let maxRows = 9

    var body: some View {
        let fitted = WidgetRows.fit(day, limit: Self.maxRows)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                WidgetBrand()
                Text("· 오늘")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(date, format: .dateTime.month().day().weekday(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if day.hasPending {
                Text("저장 대기 · Daylog를 열어 확인해 주세요")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if let percent = day.percent {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(percent)%")
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(GroupColor.mint.ink)
                    Text("\(day.done)/\(day.total) 완료")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("오늘의 달성률 \(percent)%, \(day.total)개 중 \(day.done)개 완료")
                WidgetBar(ratio: day.ratio ?? 0)
                    .padding(.bottom, 2)
            } else {
                Spacer(minLength: 0)
                Text("오늘은 예정된 루틴이 없어요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(fitted.rows) { row in
                switch row {
                case .group(let group):
                    HStack {
                        Text(group.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GroupColor(key: group.colorKey).ink)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text("\(group.done)/\(group.items.count)")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                case .item(let item, let colorKey):
                    itemRow(item, tint: GroupColor(key: colorKey).color)
                }
            }
            if fitted.hiddenItems > 0 {
                Text("외 \(fitted.hiddenItems)개 · 눌러서 Daylog에서 보기")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func itemRow(_ item: WidgetItem, tint: Color) -> some View {
        Button(intent: ToggleRoutineIntent(routineID: item.routineID, dateKey: day.dateKey, isDone: !item.requestedIsDone)) {
            HStack(spacing: 8) {
                Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                    .font(.body)
                    .foregroundStyle(item.isDone ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
                Text(item.title)
                    .font(.callout)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                if let pending = item.pendingIsDone {
                    Text(pending ? "완료 대기" : "취소 대기")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if let minutes = TimeLabel.minutes(item.timeLabel) {
                    Text(TimeLabel.label(minutes: minutes))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.pendingIsDone.map { $0 ? "완료 저장 대기" : "취소 저장 대기" } ?? (item.isDone ? "완료" : "미완료"))
        .accessibilityHint(item.requestedIsDone ? "누르면 완료를 취소합니다." : "누르면 완료로 표시합니다.")
    }
}
