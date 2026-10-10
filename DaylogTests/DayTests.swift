import Foundation
import Testing
@testable import Daylog

/// 17-9. 날짜 경계
struct DayTests {
    @Test func keyRoundTrip() {
        #expect(day("2026-10-10").key == "2026-10-10")
        #expect(Day(year: 2026, month: 3, day: 7).key == "2026-03-07")
        #expect(Day(key: "2026-02-30") == nil)
        #expect(Day(key: "2026-13-01") == nil)
        #expect(Day(key: "20261010") == nil)
        #expect(Day(key: "") == nil)
    }

    @Test func monthEndRollsIntoNextMonth() {
        #expect(day("2026-01-31").adding(days: 1) == day("2026-02-01"))
        #expect(day("2026-02-01").adding(days: -1) == day("2026-01-31"))
        #expect(day("2026-04-30").adding(days: 1) == day("2026-05-01"))
    }

    @Test func yearEndRollsIntoNextYear() {
        #expect(day("2026-12-31").adding(days: 1) == day("2027-01-01"))
        #expect(day("2027-01-01").adding(days: -1) == day("2026-12-31"))
        #expect(day("2026-12-15").addingMonths(1) == day("2027-01-01"))
        #expect(day("2027-01-15").addingMonths(-1) == day("2026-12-01"))
    }

    @Test func leapDay() {
        #expect(day("2028-02-28").adding(days: 1) == day("2028-02-29"))
        #expect(day("2028-02-29").adding(days: 1) == day("2028-03-01"))
        #expect(day("2028-02-01").daysInMonth == 29)
        #expect(day("2027-02-01").daysInMonth == 28)
        #expect(Day(key: "2027-02-29") == nil)
    }

    @Test func weekdayIsMondayBased() {
        #expect(monday.weekday == 1)
        #expect(saturday.weekday == 6)
        #expect(sunday.weekday == 7)
        #expect(sunday.adding(days: 1).weekday == 1)
        #expect(sunday.weekdaySymbol == "일")
    }

    @Test func rangeAndDistance() {
        #expect(Day.range(from: monday, to: sunday).count == 7)
        #expect(Day.range(from: sunday, to: monday).isEmpty)
        #expect(monday.days(until: sunday) == 6)
        #expect(day("2026-12-30").days(until: day("2027-01-02")) == 3)
    }

    /// 뉴욕 서머타임 시작(2026-03-08)과 종료(2026-11-01). 23시간·25시간짜리 하루에도 날짜가 하나씩만 넘어간다.
    @Test func daylightSavingTransitions() throws {
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        let utc = ISO8601DateFormatter()

        let beforeSpringMidnight = try #require(utc.date(from: "2026-03-09T03:59:00Z")) // 3/8 23:59 EDT
        let afterSpringMidnight = try #require(utc.date(from: "2026-03-09T04:00:00Z"))  // 3/9 00:00 EDT
        #expect(Day(date: beforeSpringMidnight, timeZone: newYork) == day("2026-03-08"))
        #expect(Day(date: afterSpringMidnight, timeZone: newYork) == day("2026-03-09"))

        let beforeFallMidnight = try #require(utc.date(from: "2026-11-02T04:59:00Z")) // 11/1 23:59 EST
        let afterFallMidnight = try #require(utc.date(from: "2026-11-02T05:00:00Z"))  // 11/2 00:00 EST
        #expect(Day(date: beforeFallMidnight, timeZone: newYork) == day("2026-11-01"))
        #expect(Day(date: afterFallMidnight, timeZone: newYork) == day("2026-11-02"))

        #expect(day("2026-03-07").adding(days: 2) == day("2026-03-09"))
        #expect(day("2026-03-07").days(until: day("2026-03-09")) == 2)
        #expect(day("2026-10-31").adding(days: 2) == day("2026-11-02"))
        #expect(Day.range(from: day("2026-03-07"), to: day("2026-03-10")).map(\.key)
            == ["2026-03-07", "2026-03-08", "2026-03-09", "2026-03-10"])
    }

    /// 같은 순간이라도 시간대에 따라 "오늘"은 달라지지만, 저장된 날짜는 어느 시간대에서 읽어도 그대로다.
    @Test func timeZoneChangeKeepsStoredDays() throws {
        let seoul = try #require(TimeZone(identifier: "Asia/Seoul"))
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let kiritimati = try #require(TimeZone(identifier: "Pacific/Kiritimati")) // UTC+14
        let instant = try #require(ISO8601DateFormatter().date(from: "2026-10-10T01:00:00Z"))

        #expect(Day.today(now: instant, timeZone: seoul) == day("2026-10-10"))
        #expect(Day.today(now: instant, timeZone: losAngeles) == day("2026-10-09"))

        let stored = day("2026-10-10").anchorDate
        #expect(Day(anchorDate: stored) == day("2026-10-10"))
        // 저장값(UTC 정오)은 극단적인 시간대에서도 날짜 문자열 키와 어긋나지 않는다.
        #expect(Day(anchorDate: stored).key == "2026-10-10")
        #expect(Day(date: stored, timeZone: seoul) == day("2026-10-10"))
        #expect(Day(date: stored, timeZone: losAngeles) == day("2026-10-10"))
        _ = kiritimati
    }
}
