import SwiftUI

/// 시작일·종료일을 고르는 상태. 날짜 연산은 `Day`(UTC 달력)로만 해서 시간대·서머타임의 영향을 받지 않는다.
///
/// 고르는 순서: 시작일을 고르면 종료일 차례가 되고, 종료일을 고르면 그대로 종료일 차례로 남아 바로 고쳐 쓸 수 있다.
/// 종료일 차례에 시작일보다 앞선 날을 누르면 그 날이 새 시작일이 된다(종료일이 시작일보다 빠른 상태는 생기지 않는다).
struct DayRangeSelection: Equatable {
    enum Edge: Equatable {
        case start, end
    }

    private(set) var start: Day
    private(set) var end: Day
    var editing: Edge = .start

    init(start: Day, end: Day) {
        self.start = min(start, end)
        self.end = max(start, end)
    }

    init(day: Day) {
        self.init(start: day, end: day)
    }

    /// 양 끝을 포함한 날 수.
    var dayCount: Int { start.days(until: end) + 1 }

    func contains(_ day: Day) -> Bool { start <= day && day <= end }

    mutating func pick(_ day: Day) {
        switch editing {
        case .start:
            start = day
            if end < day { end = day }
            editing = .end
        case .end:
            if day < start {
                start = day
            } else {
                end = day
            }
        }
    }
}

/// 한 달의 격자. 월요일 시작이고, 1일 앞의 빈칸 수를 함께 준다.
struct MonthGrid: Equatable {
    let month: Day
    let leadingBlanks: Int
    let days: [Day]

    init(containing day: Day) {
        month = day.firstOfMonth
        leadingBlanks = month.weekday - 1
        days = Day.range(from: month, to: month.adding(days: month.daysInMonth - 1))
    }

    /// 항상 6줄을 차지하게 해서 달을 넘길 때 높이가 출렁이지 않게 한다.
    static let rowCount = 6
    var trailingBlanks: Int { Self.rowCount * 7 - leadingBlanks - days.count }
}

/// 기간을 고르는 달력. 시작일과 종료일은 진한 색, 그 사이는 옅은 색으로 칠한다. 오늘은 테두리로 표시한다.
/// macOS에서는 방향키로 날짜를 옮기고 Return·Space로 고른다. VoiceOver에는 날짜마다 상태를 글자로 알린다.
struct DayRangeCalendar: View {
    @Binding var selection: DayRangeSelection
    let today: Day
    var tint: Color = Theme.accent
    /// 보여 줄 달. 처음에는 시작일이 든 달.
    @State private var month: Day
    /// 키보드로 옮겨 다니는 날짜.
    @State private var cursor: Day
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 가로 간격은 0: 범위 띠가 칸 사이에서 끊기지 않게 한다.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    init(selection: Binding<DayRangeSelection>, today: Day, tint: Color = Theme.accent) {
        _selection = selection
        self.today = today
        self.tint = tint
        _month = State(initialValue: selection.wrappedValue.start.firstOfMonth)
        _cursor = State(initialValue: selection.wrappedValue.start)
    }

    var body: some View {
        let grid = MonthGrid(containing: month)
        VStack(spacing: 8) {
            header
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Weekdays.all, id: \.self) { weekday in
                    Text(Weekdays.symbol(weekday))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(weekday >= 6 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }
                .accessibilityHidden(true)

                ForEach(0..<grid.leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: Self.cellHeight)
                }
                ForEach(grid.days, id: \.self) { day in
                    cell(day)
                }
                ForEach(0..<grid.trailingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: Self.cellHeight)
                }
            }
        }
        #if os(macOS)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { move(by: -1) }
        .onKeyPress(.rightArrow) { move(by: 1) }
        .onKeyPress(.upArrow) { move(by: -7) }
        .onKeyPress(.downArrow) { move(by: 7) }
        .onKeyPress(.return) { pick(cursor); return .handled }
        .onKeyPress(.space) { pick(cursor); return .handled }
        #endif
        .onChange(of: selection.editing) { _, edge in
            // 종료일 차례로 넘어가면 종료일이 든 달을 보여 준다.
            let target = edge == .start ? selection.start : selection.end
            show(target)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(month.monthTitle) 달력, \(selection.editing == .start ? "시작일" : "종료일") 고르기")
    }

    static let cellHeight: CGFloat = 32

    private var header: some View {
        HStack(spacing: 4) {
            Text(month.monthTitle)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if month != today.firstOfMonth {
                Button("오늘") { show(today) }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 6)
                    .accessibilityLabel("이번 달로 이동")
            }
            stepButton("chevron.left", label: "이전 달") { month = month.addingMonths(-1) }
            stepButton("chevron.right", label: "다음 달") { month = month.addingMonths(1) }
        }
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 26, height: 24)
                .background(Theme.track, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func cell(_ day: Day) -> some View {
        let isStart = day == selection.start
        let isEnd = day == selection.end
        let isEdge = isStart || isEnd
        let inRange = selection.contains(day)
        let isCursor = isFocused && day == cursor
        return Button {
            pick(day)
        } label: {
            Text("\(day.day)")
                .font(.callout.weight(isEdge || day == today ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(isEdge ? Theme.onAccent : day.weekday >= 6 && !inRange ? Color.secondary : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: Self.cellHeight)
                .background {
                    // 범위는 이어진 띠로, 양 끝은 둥근 사각형으로 그린다.
                    if inRange, selection.start != selection.end {
                        RangeBand(isStart: isStart, isEnd: isEnd).fill(tint.opacity(0.16))
                    }
                    if isEdge {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint)
                    }
                }
                .overlay {
                    if day == today, !isEdge {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(tint, lineWidth: 1.5)
                    }
                    if isCursor {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.6), lineWidth: 2)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: inRange)
        .accessibilityLabel(spokenLabel(day, isStart: isStart, isEnd: isEnd, inRange: inRange))
        .accessibilityAddTraits(isEdge ? [.isButton, .isSelected] : .isButton)
    }

    private func spokenLabel(_ day: Day, isStart: Bool, isEnd: Bool, inRange: Bool) -> String {
        var parts = ["\(day.shortTitle) \(day.weekdaySymbol)요일"]
        if day == today { parts.append("오늘") }
        if isStart, isEnd { parts.append("하루 휴가") }
        else if isStart { parts.append("시작일") }
        else if isEnd { parts.append("종료일") }
        else if inRange { parts.append("기간 안") }
        return parts.joined(separator: ", ")
    }

    private func pick(_ day: Day) {
        cursor = day
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
            selection.pick(day)
        }
    }

    private func show(_ day: Day) {
        cursor = day
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
            month = day.firstOfMonth
        }
    }

    #if os(macOS)
    private func move(by days: Int) -> KeyPress.Result {
        cursor = cursor.adding(days: days)
        if cursor.firstOfMonth != month {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { month = cursor.firstOfMonth }
        }
        return .handled
    }
    #endif
}

/// 범위 띠: 양 끝 칸은 바깥쪽 모서리를 둥글게, 가운데 칸은 네모로 이어 붙인다.
private struct RangeBand: Shape {
    let isStart: Bool
    let isEnd: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 8
        var corners: UIRectCornerSet = []
        if isStart { corners.formUnion([.topLeft, .bottomLeft]) }
        if isEnd { corners.formUnion([.topRight, .bottomRight]) }
        return Path(roundedRect: rect, cornerRadii: RectangleCornerRadii(
            topLeading: corners.contains(.topLeft) ? radius : 0,
            bottomLeading: corners.contains(.bottomLeft) ? radius : 0,
            bottomTrailing: corners.contains(.bottomRight) ? radius : 0,
            topTrailing: corners.contains(.topRight) ? radius : 0
        ))
    }
}

private struct UIRectCornerSet: OptionSet {
    let rawValue: Int
    static let topLeft = UIRectCornerSet(rawValue: 1)
    static let bottomLeft = UIRectCornerSet(rawValue: 2)
    static let topRight = UIRectCornerSet(rawValue: 4)
    static let bottomRight = UIRectCornerSet(rawValue: 8)
}
