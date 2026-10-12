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

    @Test func rangeCanCrossMonthAndYearBoundaries() {
        var selection = DayRangeSelection(day: Day(year: 2026, month: 12, day: 30))
        selection.pick(Day(year: 2026, month: 12, day: 30))
        selection.pick(Day(year: 2027, month: 1, day: 2))
        #expect(selection.dayCount == 4)
        #expect(selection.contains(Day(year: 2026, month: 12, day: 31)))
        #expect(selection.contains(Day(year: 2027, month: 1, day: 1)))
        #expect(Day.range(from: selection.start, to: selection.end).map(\.key)
                == ["2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02"])
    }

    @Test func leapYearFebruaryHasTwentyNineDays() {
        let grid = MonthGrid(containing: Day(year: 2028, month: 2, day: 15))
        #expect(grid.days.count == 29)
        #expect(grid.days.last == Day(year: 2028, month: 2, day: 29))
        #expect(grid.leadingBlanks == 1, "2028년 2월 1일은 화요일.")
        #expect(Day(key: "2027-02-29") == nil, "평년의 2월 29일은 없는 날짜다.")
        #expect(Day(year: 2028, month: 2, day: 29).adding(days: 1) == Day(year: 2028, month: 3, day: 1))
    }

    @Test func monthNavigationLandsOnTheFirstDay() {
        let december = Day(year: 2026, month: 12, day: 31)
        #expect(december.addingMonths(1) == Day(year: 2027, month: 1, day: 1))
        #expect(Day(year: 2027, month: 1, day: 1).addingMonths(-1) == Day(year: 2026, month: 12, day: 1))
        #expect(Day(year: 2026, month: 1, day: 31).addingMonths(1) == Day(year: 2026, month: 2, day: 1))
    }

    @Test func voiceOverLabelsStateTheRole() {
        let today = oct11
        #expect(DayRangeCalendar.spokenLabel(oct11, today: today, isStart: true, isEnd: true, inRange: true)
                == "10월 11일 일요일, 오늘, 하루 휴가")
        #expect(DayRangeCalendar.spokenLabel(oct14, today: today, isStart: true, isEnd: false, inRange: true)
                == "10월 14일 수요일, 시작일")
        #expect(DayRangeCalendar.spokenLabel(oct17, today: today, isStart: false, isEnd: true, inRange: true)
                == "10월 17일 토요일, 종료일")
        #expect(DayRangeCalendar.spokenLabel(Day(year: 2026, month: 10, day: 15), today: today, isStart: false, isEnd: false, inRange: true)
                == "10월 15일 목요일, 기간 안")
        #expect(DayRangeCalendar.spokenLabel(Day(year: 2026, month: 10, day: 20), today: today, isStart: false, isEnd: false, inRange: false)
                == "10월 20일 화요일")
    }

    @Test func phoneSheetFitsShortContentAndScrollsLongContent() {
        #expect(SheetDetents.fitsContent(contentHeight: 500, screenHeight: 874))
        #expect(!SheetDetents.fitsContent(contentHeight: 700, screenHeight: 874), "iPhone 17 Pro 높이에서 700pt 내용은 전체 높이로 스크롤한다.")
        #expect(!SheetDetents.fitsContent(contentHeight: 0, screenHeight: 874), "아직 재지 않았으면 전체 높이.")
        #expect(SheetDetents.fitsContent(contentHeight: 700, screenHeight: 1194), "iPad에서는 같은 내용이 맞는다.")
    }
}
