import SwiftUI

/// 식사 기록 캘린더. 식사를 적은 날에 표시가 붙고, 날짜를 누르면 그 날짜의 기록을 연다.
struct MealCalendarCard: View {
    @Environment(AppStore.self) private var store
    let onOpen: (Day) -> Void
    /// 보고 있는 달의 1일. nil이면 이번 달.
    @State private var shownMonth: Day?
    @State private var mealDays: Set<Day> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var month: Day { shownMonth ?? store.today.firstOfMonth }
    private var canShowNext: Bool { month < store.today.firstOfMonth }

    var body: some View {
        let month = month
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(symbol: "calendar", title: "식사 캘린더", tint: Theme.mealTint) {
                    stepper(month)
                }

                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Weekdays.all, id: \.self) { weekday in
                        Text(Weekdays.symbol(weekday))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                    }
                    .accessibilityHidden(true)

                    // 1일이 시작하는 요일까지 빈칸.
                    ForEach(0..<(month.weekday - 1), id: \.self) { _ in
                        Color.clear.frame(height: 1)
                    }

                    ForEach(Day.range(from: month, to: month.adding(days: month.daysInMonth - 1)), id: \.self) { day in
                        dayCell(day)
                    }
                }

                HStack(spacing: 6) {
                    Circle().fill(Theme.mealTint).frame(width: 7, height: 7)
                    Text("식사를 적은 날 · 이 달 \(mealDays.count)일")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
        }
        .onAppear(perform: reload)
        .onChange(of: shownMonth) { reload() }
        .onChange(of: store.dataVersion) { reload() }
    }

    private func reload() {
        mealDays = store.mealDays(inMonth: month)
    }

    private func stepper(_ month: Day) -> some View {
        HStack(spacing: 2) {
            Button {
                shownMonth = month.addingMonths(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("이전 달")

            Text(month.monthTitle)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 84)

            Button {
                shownMonth = month.addingMonths(1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .disabled(!canShowNext)
            .accessibilityLabel("다음 달")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .fixedSize()
    }

    private func dayCell(_ day: Day) -> some View {
        let hasMeal = mealDays.contains(day)
        let isToday = day == store.today
        let isFuture = day > store.today
        return Button {
            onOpen(day)
        } label: {
            Text("\(day.day)")
                .font(.callout.weight(hasMeal || isToday ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(isFuture ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                .frame(width: 28, height: 28)
                .background(hasMeal ? Theme.mealTint.opacity(0.22) : .clear, in: Circle())
                .overlay(Circle().strokeBorder(isToday ? Theme.mealTint : .clear, lineWidth: 1.5))
                .overlay(alignment: .bottom) {
                    // 색만으로 구분하지 않도록 점을 함께 찍는다.
                    if hasMeal {
                        Circle().fill(Theme.mealTint).frame(width: 4, height: 4).offset(y: -2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel("\(day.shortTitle) \(day.weekdaySymbol)요일\(isToday ? ", 오늘" : "")")
        .accessibilityValue(isFuture ? "아직 오지 않은 날" : hasMeal ? "식사 기록 있음" : "식사 기록 없음")
        .accessibilityHint("누르면 이 날짜의 기록을 엽니다.")
    }
}
