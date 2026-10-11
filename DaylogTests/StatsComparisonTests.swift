import Foundation
import Testing
@testable import Daylog

@MainActor
struct StatsComparisonTests {
    @Test(arguments: [StatsPeriod.week, .month, .quarter])
    func comparesImmediatelyPrecedingEqualLengthPeriod(_ period: StatsPeriod) throws {
        let env = try TestEnv()
        let length = try #require(period.days)
        let today = day("2026-03-03") // 월·연도 경계를 날짜 계산으로 처리한다.
        let previousStart = today.adding(days: -(length * 2 - 1))
        let currentStart = today.adding(days: -(length - 1))
        try env.addRoutines(1, today: previousStart)
        // 이전 기간은 실제로 기록한 0%, 현재 기간은 전부 완료.
        for date in Day.range(from: previousStart, to: currentStart.adding(days: -1)) {
            try env.log(date, done: 0)
        }
        for date in Day.range(from: currentStart, to: today) { try env.log(date, done: 1) }

        let stats = try env.stats.period(period, today: today)
        let previous = try #require(stats.previousPeriod)
        #expect(previous.start == previousStart)
        #expect(previous.end == currentStart.adding(days: -1))
        #expect(previous.outcomes.count == length)
        #expect(stats.outcomes.count == length)
        #expect(Set(previous.outcomes.map(\.day)).isDisjoint(with: Set(stats.outcomes.map(\.day))))
        #expect(previous.averagePercent == 0)
        #expect(stats.averagePercent == 100)
        #expect(stats.averageChange == 100)
        #expect(previous.countedDays == length)
    }

    @Test func noPreviousEligibleDatesDoesNotInventZero() throws {
        let env = try TestEnv()
        try env.addRoutines(1, today: monday)
        try env.log(monday, done: 1)
        let stats = try env.stats.period(.week, today: monday)
        let previous = try #require(stats.previousPeriod)
        #expect(previous.averagePercent == nil)
        #expect(previous.countedDays == 0)
        #expect(stats.averagePercent == 100)
        #expect(stats.averageChange == nil)
        #expect(try env.stats.period(.all, today: monday).previousPeriod == nil)
    }

    @Test func vacationOnlyPeriodHasNoComparisonAndRemovalRestoresIt() throws {
        let env = try TestEnv()
        let start = monday.adding(days: -13)
        try env.addRoutines(1, today: start)
        for date in Day.range(from: start, to: monday) { try env.log(date, done: 1) }
        let vacationService = VacationService(context: env.context)
        let previousVacation = try vacationService.save(start: start, end: monday.adding(days: -7))
        let stats = try env.stats.period(.week, today: monday)
        #expect(stats.previousPeriod?.averagePercent == nil)
        #expect(stats.averageChange == nil)
        #expect(stats.averagePercent == 100)
        try vacationService.remove(previousVacation)
        #expect(try env.stats.period(.week, today: monday).averageChange == 0)

        _ = try vacationService.save(start: monday.adding(days: -6), end: monday)
        let nowVacation = try env.stats.period(.week, today: monday)
        #expect(nowVacation.averagePercent == nil)
        #expect(nowVacation.previousPeriod?.averagePercent == 100)
        #expect(nowVacation.averageChange == nil)
    }

    @Test func restPreStartAndFutureRemainExcludedAndUnrecordedKeepsDenominator() throws {
        let env = try TestEnv()
        try env.addRoutines(1, weekdays: [1], today: monday.adding(days: -7))
        // 이전 월요일은 미기록, 현재 월요일은 100%. 그 외는 휴식.
        try env.log(monday, done: 1)
        let stats = try env.stats.period(.week, today: monday)
        #expect(stats.countedDays == 1)
        #expect(stats.previousPeriod?.countedDays == 1)
        #expect(stats.previousPeriod?.unrecordedDays == 1)
        #expect(stats.previousPeriod?.averagePercent == 0)
        #expect(stats.averageChange == 100)
        let future = try env.stats.outcomes(from: monday.adding(days: 1), to: monday.adding(days: 7), today: monday)
        #expect(future.allSatisfy { $0.ratio == nil })
        #expect(StatsCalculator.averagePercent(future) == nil)
    }

    @Test func unrecordedPresentationDiffersFromRecordedZeroWithoutChangingMath() {
        let missing = DayOutcome(day: monday, status: .unrecorded, done: 0, total: 2)
        let zero = DayOutcome(day: monday.adding(days: 1), status: .recorded, done: 0, total: 2)
        let complete = DayOutcome(day: monday.adding(days: 2), status: .recorded, done: 2, total: 2)
        #expect(missing.percent == zero.percent)
        #expect(missing.percentLabel == "미기록")
        #expect(zero.percentLabel == "0%")
        #expect(StatsCalculator.averagePercent([missing, zero, complete]) == 33)
        #expect(missing.spokenSummary(threshold: 80).contains("미기록"))
    }

    @Test func selectedDayMatchesRecordedAndUnrecordedStates() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동")
        #expect(env.store.selectedOutcome.status == .unrecorded)
        #expect(env.store.selectedOutcome.percentLabel == "미기록")
        env.store.setDone(routineID: routine.id, true)
        env.store.setDone(routineID: routine.id, false)
        #expect(env.store.selectedOutcome.status == .recorded)
        #expect(env.store.selectedOutcome.percentLabel == "0%")
        #expect(env.store.saveVacation(start: monday, end: monday))
        #expect(env.store.selectedOutcome.status == .vacation)
        #expect(env.store.selectedOutcome.ratio == nil)
    }
}
