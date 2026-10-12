import Foundation
import Testing
@testable import Daylog

/// 디자인 정리 작업에서 추가한 부품의 규칙: 기간 선택기와 월 격자.
struct DesignRefinementTests {
    private let oct11 = Day(year: 2026, month: 10, day: 11)
    private let oct14 = Day(year: 2026, month: 10, day: 14)
    private let oct17 = Day(year: 2026, month: 10, day: 17)

    @Test func pickingStartThenEndMakesARange() {
        var selection = DayRangeSelection(day: oct11)
        #expect(selection.editing == .start)
        #expect(selection.dayCount == 1)

        selection.pick(oct14)
        #expect(selection.start == oct14)
        #expect(selection.end == oct14, "시작일이 종료일보다 뒤면 종료일도 따라온다.")
        #expect(selection.editing == .end)

        selection.pick(oct17)
        #expect(selection.start == oct14)
        #expect(selection.end == oct17)
        #expect(selection.dayCount == 4)
        #expect(selection.contains(Day(year: 2026, month: 10, day: 15)))
        #expect(!selection.contains(Day(year: 2026, month: 10, day: 18)))
    }

    @Test func endBeforeStartBecomesTheNewStart() {
        var selection = DayRangeSelection(start: oct14, end: oct17)
        selection.editing = .end
        selection.pick(oct11)
        #expect(selection.start == oct11)
        #expect(selection.end == oct17, "종료일 차례에 앞선 날을 누르면 시작일이 당겨지고 종료일은 그대로다.")
        #expect(selection.start <= selection.end)
    }

    @Test func initialRangeIsNormalised() {
        let selection = DayRangeSelection(start: oct17, end: oct14)
        #expect(selection.start == oct14)
        #expect(selection.end == oct17)
    }

    @Test func monthGridStartsOnMondayAndKeepsSixRows() {
        let grid = MonthGrid(containing: oct11)
        #expect(grid.month == Day(year: 2026, month: 10, day: 1))
        #expect(grid.leadingBlanks == 3, "2026년 10월 1일은 목요일이라 월·화·수 세 칸이 빈다.")
        #expect(grid.days.count == 31)
        #expect(grid.leadingBlanks + grid.days.count + grid.trailingBlanks == MonthGrid.rowCount * 7)

        let february = MonthGrid(containing: Day(year: 2027, month: 2, day: 10))
        #expect(february.leadingBlanks == 0, "2027년 2월 1일은 월요일.")
        #expect(february.days.count == 28)
        #expect(february.trailingBlanks == 14)
    }

    @Test func periodLabelShowsWeekdaysAndDayCount() {
        let single = VacationPeriod(start: oct11, end: oct11)
        #expect(VacationPeriodLabel.rangeTitle(single) == "2026년 10월 11일 (일)")
        let range = VacationPeriod(start: oct14, end: oct17)
        #expect(VacationPeriodLabel.rangeTitle(range) == "10월 14일 (수) ~ 10월 17일 (토)")
    }
}
