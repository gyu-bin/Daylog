import SwiftUI

/// 타임라인의 하루: 왼쪽에 날짜와 이음선, 오른쪽에 그날 적은 식사 카드. 카드를 누르면 그 날짜를 연다.
struct MealTimelineRow: View {
    let day: MealDay
    let query: String
    /// 마지막 줄이면 이음선을 아래로 잇지 않는다.
    let isLast: Bool
    let open: () -> Void

    @State private var isHovered = false

    private var meals: [(kind: MealKind, text: String)] {
        [(.breakfast, day.breakfast), (.lunch, day.lunch), (.dinner, day.dinner), (.snack, day.snack)]
            .filter { !MealDay.isBlank($0.1) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            dateColumn
            card
                .padding(.bottom, 10)
        }
    }

    private var dateColumn: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(day.day.axisLabel)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text("\(day.day.weekdaySymbol)요일")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44, alignment: .trailing)
            .padding(.top, 9)

            VStack(spacing: 0) {
                Circle()
                    .fill(Theme.mealTint)
                    .frame(width: 9, height: 9)
                    .padding(.top, 14)
                if !isLast {
                    Rectangle()
                        .fill(Theme.separator)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }
            .frame(width: 9)
        }
        .accessibilityHidden(true)
    }

    private var card: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(meals, id: \.kind) { meal in
                    line(symbol: meal.kind.symbol, label: meal.kind.title, text: meal.text, tint: meal.kind.tint)
                }
                if !MealDay.isBlank(day.memo) {
                    line(symbol: "note.text", label: "메모", text: day.memo, tint: .secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? Theme.track : Theme.inset, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if isHovered {
                    Label("수정", systemImage: "pencil")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("대시보드에서 이 날짜의 식사를 보고 고칩니다.")
        .accessibilityLabel(spokenSummary)
        .accessibilityHint("누르면 이 날짜의 기록을 열어 수정합니다.")
    }

    private var spokenSummary: String {
        var parts = ["\(day.day.shortTitle) \(day.day.weekdaySymbol)요일"]
        parts += meals.map { "\($0.kind.title) \($0.text)" }
        if !MealDay.isBlank(day.memo) { parts.append("메모 \(day.memo)") }
        return parts.joined(separator: ", ")
    }

    private func line(symbol: String, label: String, text: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label {
                Text(label).font(.caption.weight(.semibold))
            } icon: {
                Image(systemName: symbol).font(.caption).foregroundStyle(tint)
            }
            .frame(width: 54, alignment: .leading)

            Text(highlighted(text))
                .font(.callout)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 검색어와 일치하는 부분을 굵게, 옅은 바탕색과 함께 표시한다.
    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return attributed }
        var searchRange = attributed.startIndex..<attributed.endIndex
        while let found = attributed[searchRange].range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributed[found].font = .callout.bold()
            attributed[found].backgroundColor = GroupColor.yellow.color.opacity(0.4)
            searchRange = found.upperBound..<attributed.endIndex
        }
        return attributed
    }
}
