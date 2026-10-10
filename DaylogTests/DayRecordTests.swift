import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 17-1. 날짜별 기록
@MainActor
struct DayRecordTests {
    @Test func sameDateCreatesOnlyOneRecord() throws {
        let env = try TestEnv()
        try env.addRoutines(2, today: monday)

        let first = try env.records.fetchOrCreate(day: monday, today: monday)
        let second = try env.records.fetchOrCreate(day: monday, today: monday)

        #expect(first === second)
        #expect(try env.context.fetchCount(FetchDescriptor<DayRecord>()) == 1)
        #expect(try env.context.fetchCount(FetchDescriptor<DayCheck>()) == 2)
    }

    @Test func repeatedOpeningKeepsExistingData() throws {
        let env = try TestEnv()
        try env.addRoutines(2, today: monday)
        let record = try env.log(monday, done: 1)
        env.records.setText("그릭요거트", at: \.breakfast, of: record)
        try env.context.save()

        // 다른 컨텍스트(재실행)에서 같은 날짜를 다시 열어도 덮어쓰지 않는다.
        let relaunched = env.freshContext()
        let reopened = try DayRecordService(context: relaunched).fetchOrCreate(day: monday, today: monday)

        #expect(reopened.breakfast == "그릭요거트")
        #expect(reopened.checkList.filter(\.isDone).count == 1)
        #expect(try relaunched.fetchCount(FetchDescriptor<DayRecord>()) == 1)
        #expect(try relaunched.fetchCount(FetchDescriptor<DayCheck>()) == 2)
    }

    @Test func futureDateIsRejected() throws {
        let env = try TestEnv()
        #expect(throws: DaylogError.futureDate("2026-10-06")) {
            try env.records.fetchOrCreate(day: monday.adding(days: 1), today: monday)
        }
        #expect(try env.context.fetchCount(FetchDescriptor<DayRecord>()) == 0)
    }

    @Test func daysBeforeFirstRoutineAreExcludedFromStats() throws {
        let env = try TestEnv()
        try env.addRoutines(1, today: saturday)

        // 시작 전 날짜를 열어 기록이 생겨도 통계에는 들어가지 않는다.
        let before = try env.records.fetchOrCreate(day: monday, today: saturday)
        #expect(before.checkList.isEmpty)

        let outcomes = try env.stats.outcomes(from: monday, to: saturday, today: saturday)
        #expect(outcomes.dropLast().allSatisfy { $0.status == .preStart })
        #expect(outcomes.last?.status == .unrecorded)

        let stats = try env.stats.dashboard(today: saturday)
        #expect(stats.weeklyAverage == 0) // 오늘 하루만 유효
        #expect(stats.week.filter { $0.ratio != nil }.count == 1)
    }

    @Test func openingPastDayDoesNotMarkItRecorded() throws {
        let env = try TestEnv()
        try env.addRoutines(3, today: monday)
        let wednesday = monday.adding(days: 2)

        let before = try env.stats.outcomes(from: monday, to: wednesday, today: wednesday)
        let tuesday = try env.records.fetchOrCreate(day: monday.adding(days: 1), today: wednesday)
        let after = try env.stats.outcomes(from: monday, to: wednesday, today: wednesday)

        #expect(tuesday.checkList.count == 3)
        #expect(tuesday.checkList.allSatisfy { !$0.isDone })
        #expect(!tuesday.isRecorded)
        #expect(before == after)
        #expect(after[1] == DayOutcome(day: monday.adding(days: 1), status: .unrecorded, done: 0, total: 3))
    }

    @Test func pastDayCanBeFilledInLater() throws {
        let env = try TestEnv()
        try env.addRoutines(2, today: monday)
        let wednesday = monday.adding(days: 2)

        let tuesday = try env.records.fetchOrCreate(day: monday.adding(days: 1), today: wednesday)
        try env.records.setDone(try #require(tuesday.checkList.first), true)

        let outcome = try env.stats.outcomes(from: monday.adding(days: 1), to: monday.adding(days: 1), today: wednesday)
        #expect(outcome == [DayOutcome(day: monday.adding(days: 1), status: .recorded, done: 1, total: 2)])
    }

    @Test func dayWithoutRoutinesHasNoRate() throws {
        let env = try TestEnv()
        try env.addRoutines(1, weekdays: Weekdays.workdays, today: monday)

        let record = try env.records.fetchOrCreate(day: saturday, today: saturday)
        #expect(record.checkList.isEmpty)

        let outcome = try env.stats.outcomes(from: saturday, to: saturday, today: saturday)
        #expect(outcome.first?.status == .rest)
        #expect(outcome.first?.percent == nil)
    }
}
