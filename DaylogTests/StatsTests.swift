import Foundation
import SwiftData
import Testing
@testable import Daylog

private func outcomes(endingAt today: Day, percents: [Int?]) -> [DayOutcome] {
    // percents는 오래된 날 → 오늘 순서. nil은 휴식일.
    percents.enumerated().map { index, percent in
        let day = today.adding(days: index - (percents.count - 1))
        guard let percent else { return DayOutcome(day: day, status: .rest, done: 0, total: 0) }
        return DayOutcome(day: day, status: .recorded, done: percent, total: 100)
    }
}

/// 17-5. 최근 7일 평균
@MainActor
struct WeeklyAverageTests {
    @Test func averageOfSevenDays() {
        let week = outcomes(endingAt: saturday, percents: [100, 80, 0, 60, 100, 80, 40])
        #expect(StatsCalculator.averagePercent(week) == 66)
    }

    @Test func averageUsesRawRatiosNotRoundedPercents() {
        // 1/3, 1/3, 1/3 → 33.33…% → 33. 2/3, 2/3 → 66.67% → 67.
        let thirds = (0..<3).map { DayOutcome(day: monday.adding(days: $0), status: .recorded, done: 1, total: 3) }
        #expect(StatsCalculator.averagePercent(thirds) == 33)
        // 1/6과 1/2: 반올림 후 평균이면 (17+50)/2 = 33.5 → 34, 원시 비율이면 33.33 → 33.
        let mixed = [
            DayOutcome(day: monday, status: .recorded, done: 1, total: 6),
            DayOutcome(day: monday.adding(days: 1), status: .recorded, done: 1, total: 2),
        ]
        #expect(StatsCalculator.averagePercent(mixed) == 33)
    }

    @Test func noValidDaysHasNoAverage() {
        #expect(StatsCalculator.averagePercent([]) == nil)
        #expect(StatsCalculator.averagePercent(outcomes(endingAt: saturday, percents: [nil, nil])) == nil)
    }

    @Test func serviceAveragesSevenDaysWithUnrecordedAsZero() throws {
        let env = try TestEnv()
        let start = saturday.adding(days: -6)
        try env.addRoutines(5, today: start)

        // 100, 80, (미기록 0), 60, 100, 80, 40
        let doneCounts: [Int?] = [5, 4, nil, 3, 5, 4, 2]
        for (offset, done) in doneCounts.enumerated() {
            if let done { try env.log(start.adding(days: offset), done: done) }
        }

        let stats = try env.stats.dashboard(today: saturday)
        #expect(stats.week.map(\.percent) == [100, 80, 0, 60, 100, 80, 40])
        #expect(stats.week[2].status == .unrecorded)
        #expect(stats.weeklyAverage == 66)
    }

    @Test func restDaysAreExcluded() throws {
        let env = try TestEnv()
        let start = sunday.adding(days: -6) // 월요일
        try env.addRoutines(2, weekdays: [1, 2, 3, 4, 5, 6], today: start)
        for offset in 0..<6 {
            try env.log(start.adding(days: offset), done: 2)
        }

        let stats = try env.stats.dashboard(today: sunday)
        #expect(stats.week.last?.status == .rest)
        #expect(stats.week.filter { $0.ratio != nil }.count == 6)
        #expect(stats.weeklyAverage == 100)
        #expect(stats.today.percent == nil)
    }

    @Test func daysBeforeFirstRoutineAreExcluded() throws {
        let env = try TestEnv()
        let start = saturday.adding(days: -2)
        try env.addRoutines(2, today: start)
        try env.log(start, done: 2)
        try env.log(start.adding(days: 1), done: 1)
        try env.log(saturday, done: 2)

        let stats = try env.stats.dashboard(today: saturday)
        #expect(stats.week.prefix(4).allSatisfy { $0.status == .preStart })
        #expect(stats.weeklyAverage == 83) // (100 + 50 + 100) / 3
    }
}

/// 17-6. 연속 달성일
@MainActor
struct StreakTests {
    @Test func currentStreakSkipsUnfinishedToday() {
        // 3일 전 60, 그제 80, 어제 100, 오늘 40
        let days = outcomes(endingAt: saturday, percents: [60, 80, 100, 40])
        #expect(StatsCalculator.currentStreak(days, today: saturday, threshold: 80) == 2)
    }

    @Test func currentStreakCountsTodayWhenAchieved() {
        let days = outcomes(endingAt: saturday, percents: [60, 80, 100, 80])
        #expect(StatsCalculator.currentStreak(days, today: saturday, threshold: 80) == 3)
    }

    @Test func restDaysKeepTheStreak() {
        let days = outcomes(endingAt: saturday, percents: [100, nil, nil, 100, 100])
        #expect(StatsCalculator.currentStreak(days, today: saturday, threshold: 80) == 3)
        #expect(StatsCalculator.longestStreak(days, threshold: 80) == 3)
    }

    @Test func unrecordedDaysBreakTheStreak() {
        var days = outcomes(endingAt: saturday, percents: [100, 100, 100, 100])
        days[1] = DayOutcome(day: days[1].day, status: .unrecorded, done: 0, total: 5)
        #expect(StatsCalculator.currentStreak(days, today: saturday, threshold: 80) == 2)
        #expect(StatsCalculator.longestStreak(days, threshold: 80) == 2)
    }

    @Test func longestStreakSurvivesLaterBreak() {
        let days = outcomes(endingAt: saturday, percents: [100, 90, 80, 100, 0, 100, 50])
        #expect(StatsCalculator.longestStreak(days, threshold: 80) == 4)
        #expect(StatsCalculator.currentStreak(days, today: saturday, threshold: 80) == 1)
    }

    @Test func daysBeforeStartAreNotCounted() {
        var days = outcomes(endingAt: saturday, percents: [100, 100, 100])
        days[0] = DayOutcome(day: days[0].day, status: .preStart, done: 0, total: 0)
        #expect(StatsCalculator.currentStreak(days, today: saturday, threshold: 80) == 2)
        #expect(StatsCalculator.longestStreak(days, threshold: 80) == 2)
    }

    @Test func serviceComputesStreaksFromRecords() throws {
        let env = try TestEnv()
        let start = saturday.adding(days: -3)
        try env.addRoutines(5, today: start)
        try env.log(start, done: 3)                    // 60
        try env.log(start.adding(days: 1), done: 4)    // 80
        try env.log(start.adding(days: 2), done: 5)    // 100
        try env.log(saturday, done: 2)                 // 40

        let stats = try env.stats.dashboard(today: saturday)
        #expect(stats.currentStreak == 2)
        #expect(stats.longestStreak == 2)
    }

    @Test func serviceSkipsRestDaysAndBreaksOnUnrecordedDays() throws {
        let env = try TestEnv()
        // 평일 루틴: 월~금 달성, 토·일 휴식, 다음 월요일 달성
        try env.addRoutines(1, weekdays: Weekdays.workdays, today: monday)
        for offset in 0..<5 {
            try env.log(monday.adding(days: offset), done: 1)
        }
        let nextMonday = monday.adding(days: 7)
        try env.log(nextMonday, done: 1)
        #expect(try env.stats.dashboard(today: nextMonday).currentStreak == 6)

        // 화요일을 기록하지 않고 수요일이 되면 끊긴다.
        let nextWednesday = monday.adding(days: 9)
        try env.log(nextWednesday, done: 1)
        let stats = try env.stats.dashboard(today: nextWednesday)
        #expect(stats.currentStreak == 1)
        #expect(stats.longestStreak == 6)
    }

    @Test func changingThresholdRecalculatesImmediately() throws {
        let env = try TestEnv()
        let start = saturday.adding(days: -2)
        try env.addRoutines(4, today: start)
        try env.log(start, done: 3)                  // 75
        try env.log(start.adding(days: 1), done: 3)  // 75
        try env.log(saturday, done: 4)               // 100

        #expect(try env.stats.dashboard(today: saturday).currentStreak == 1)
        #expect(try env.stats.dashboard(today: saturday).longestStreak == 1)

        try env.settings.setThreshold(70)
        let relaxed = try env.stats.dashboard(today: saturday)
        #expect(relaxed.threshold == 70)
        #expect(relaxed.currentStreak == 3)
        #expect(relaxed.longestStreak == 3)

        try env.settings.setThreshold(10)
        #expect(try env.settings.settings().achieveThreshold == 50) // 50~100으로 제한
        try env.settings.setThreshold(100)
        #expect(try env.stats.dashboard(today: saturday).currentStreak == 1)
    }
}

/// 17-7. 루틴별 달성률
@MainActor
struct RoutineRateTests {
    @Test func renameIsMergedUnderOneRoutine() throws {
        let env = try TestEnv()
        let routine = try env.routines.add(title: "운동", today: monday)
        try env.log(monday, done: 1)
        let tuesday = monday.adding(days: 1)
        try env.routines.update(routine, title: "운동 (러닝)", today: tuesday)
        try env.log(tuesday, done: 1)

        let rates = try env.stats.dashboard(today: tuesday).routineRates
        #expect(rates.count == 1)
        #expect(rates.first?.title == "운동 (러닝)")
        #expect(rates.first?.done == 2)
        #expect(rates.first?.scheduled == 2)
        #expect(rates.first?.percent == 100)
    }

    @Test func unrecordedScheduledDaysCountInDenominator() throws {
        let env = try TestEnv()
        try env.routines.add(title: "독서", today: monday)
        try env.log(monday, done: 1)
        // 화·수는 앱을 열지 않음
        let thursday = monday.adding(days: 3)
        try env.log(thursday, done: 1)

        let rate = try #require(try env.stats.dashboard(today: thursday).routineRates.first)
        #expect(rate.done == 2)
        #expect(rate.scheduled == 4)
        #expect(rate.percent == 50)
    }

    @Test func restDaysAreNotInDenominator() throws {
        let env = try TestEnv()
        try env.routines.add(title: "출근 준비", weekdays: Weekdays.workdays, today: monday)
        try env.routines.add(title: "물 2L", today: monday)
        for offset in 0..<7 {
            try env.log(monday.adding(days: offset), done: 2)
        }

        let rates = try env.stats.dashboard(today: sunday).routineRates
        let workday = try #require(rates.first { $0.title == "출근 준비" })
        let daily = try #require(rates.first { $0.title == "물 2L" })
        #expect(workday.scheduled == 5)
        #expect(workday.done == 5)
        #expect(daily.scheduled == 7)
    }

    @Test func sortedByRateAndMarksArchived() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(3, today: monday)
        try env.log(monday, done: 1)                     // 루틴 1만 완료
        let tuesday = monday.adding(days: 1)
        try env.log(tuesday, done: 2)                    // 루틴 1, 2 완료
        try env.routines.setArchived(routines[1], true, today: tuesday.adding(days: 1))

        let rates = try env.stats.dashboard(today: tuesday.adding(days: 1)).routineRates
        #expect(rates.map(\.title) == ["루틴 1", "루틴 2", "루틴 3"])
        #expect(rates.map(\.percent) == [67, 50, 0])
        #expect(rates.map(\.isArchived) == [false, true, false])
        #expect(rates.map(\.scheduled) == [3, 2, 3])
    }

    @Test func onlyLastThirtyDaysCount() throws {
        let env = try TestEnv()
        let start = saturday.adding(days: -40)
        try env.routines.add(title: "명상", today: start)
        try env.log(start, done: 1)

        let rate = try #require(try env.stats.dashboard(today: saturday).routineRates.first)
        #expect(rate.scheduled == 30)
        #expect(rate.done == 0)
    }
}
