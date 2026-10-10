import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 17-2. 루틴 스냅샷
@MainActor
struct RoutineSnapshotTests {
    @Test func sundayOnlyGetsDailyRoutine() throws {
        let env = try TestEnv()
        try env.addRoutines(5, weekdays: [1, 2, 3, 4, 5, 6], today: monday)
        try env.routines.add(title: "매일 하는 일", today: monday)

        #expect(try env.records.fetchOrCreate(day: saturday, today: sunday).checkList.count == 6)
        let sundayRecord = try env.records.fetchOrCreate(day: sunday, today: sunday)
        #expect(sundayRecord.checkList.map(\.title) == ["매일 하는 일"])
    }

    @Test func addingRoutineChangesTodayOnly() throws {
        let env = try TestEnv()
        try env.addRoutines(2, today: monday)
        let yesterday = try env.log(monday, done: 2)
        let tuesday = monday.adding(days: 1)
        let today = try env.records.fetchOrCreate(day: tuesday, today: tuesday)
        #expect(today.checkList.count == 2)

        try env.routines.add(title: "새 루틴", today: tuesday)

        #expect(today.checkList.count == 3)
        #expect(yesterday.checkList.count == 2)
    }

    @Test func addingRoutineNotScheduledTodayIsNotAdded() throws {
        let env = try TestEnv()
        let today = try env.records.fetchOrCreate(day: saturday, today: saturday)
        try env.routines.add(title: "평일 루틴", weekdays: Weekdays.workdays, today: saturday)
        #expect(today.checkList.isEmpty)
    }

    @Test func archivingKeepsDoneAndRemovesUndoneToday() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: monday)
        let today = try env.records.fetchOrCreate(day: monday, today: monday)
        let doneCheck = try #require(today.checkList.first { $0.routineID == routines[0].id })
        try env.records.setDone(doneCheck, true)

        try env.routines.setArchived(routines[0], true, today: monday)
        try env.routines.setArchived(routines[1], true, today: monday)

        #expect(today.checkList.map(\.routineID) == [routines[0].id])
        #expect(today.checkList.first?.isDone == true)
        // 미완료 항목은 지우지 않고 숨긴다(다른 기기가 그 사이 완료했을 수 있다).
        #expect(today.physicalChecks.count == 2)
        #expect(today.physicalChecks.first { $0.routineID == routines[1].id }?.isHidden == true)
    }

    @Test func hiddenCheckReappearsWhenDoneElsewhere() throws {
        let env = try TestEnv()
        let routine = try env.routines.add(title: "운동", today: monday)
        let today = try env.records.fetchOrCreate(day: monday, today: monday)
        try env.routines.setArchived(routine, true, today: monday)
        #expect(today.checkList.isEmpty)

        // 보관이 반영되기 전에 다른 기기에서 이미 완료한 경우: 완료 기록은 남아야 한다.
        let hidden = try #require(today.physicalChecks.first)
        hidden.isDone = true
        #expect(today.checkList.map(\.title) == ["운동"])
        #expect(try env.stats.dashboard(today: monday).today.done == 1)
    }

    @Test func archivingNeverTouchesPastChecks() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: monday)
        let past = try env.log(monday, done: 0)
        let tuesday = monday.adding(days: 1)

        try env.routines.setArchived(routines[0], true, today: tuesday)

        #expect(past.checkList.count == 2)
    }

    @Test func renamingChangesTodayButNotYesterday() throws {
        let env = try TestEnv()
        let routine = try env.routines.add(title: "운동", timeLabel: "07:00", today: monday)
        let yesterday = try env.log(monday, done: 1)
        let tuesday = monday.adding(days: 1)
        let today = try env.records.fetchOrCreate(day: tuesday, today: tuesday)
        try env.records.setDone(try #require(today.checkList.first), true)

        try env.routines.update(routine, title: "운동 (러닝)", timeLabel: "07:30", today: tuesday)

        #expect(today.checkList.first?.title == "운동 (러닝)")
        #expect(today.checkList.first?.timeLabel == "07:30")
        #expect(today.checkList.first?.isDone == true) // 이름·시간 변경으로 완료 상태가 초기화되지 않는다
        #expect(yesterday.checkList.first?.title == "운동")
        #expect(yesterday.checkList.first?.timeLabel == "07:00")
    }

    @Test func restoringDoesNotDuplicateChecks() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: monday)
        let today = try env.records.fetchOrCreate(day: monday, today: monday)
        try env.records.setDone(try #require(today.checkList.first { $0.routineID == routines[0].id }), true)

        // 완료한 항목은 보관 후에도 남아 있으므로 복원 때 다시 추가하면 안 된다.
        try env.routines.setArchived(routines[0], true, today: monday)
        try env.routines.setArchived(routines[0], false, today: monday)
        // 미완료 항목은 제거됐다가 복원 때 한 번만 돌아온다.
        try env.routines.setArchived(routines[1], true, today: monday)
        try env.routines.setArchived(routines[1], false, today: monday)
        try env.routines.setArchived(routines[1], false, today: monday)

        #expect(today.checkList.count == 2)
        #expect(Set(today.checkList.map(\.routineID)).count == 2)
        #expect(today.checkList.first { $0.routineID == routines[0].id }?.isDone == true)
    }

    @Test func weekdayChangeRemovesUndoneButKeepsDoneToday() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: monday)
        let today = try env.records.fetchOrCreate(day: monday, today: monday)
        try env.records.setDone(try #require(today.checkList.first { $0.routineID == routines[0].id }), true)

        try env.routines.update(routines[0], weekdays: Weekdays.weekend, today: monday)
        try env.routines.update(routines[1], weekdays: Weekdays.weekend, today: monday)

        #expect(today.checkList.map(\.routineID) == [routines[0].id])
    }

    @Test func reorderingChangesTodayOrderOnly() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(3, today: monday)
        let yesterday = try env.log(monday, done: 0)
        let tuesday = monday.adding(days: 1)
        let today = try env.records.fetchOrCreate(day: tuesday, today: tuesday)

        try env.routines.reorder([routines[2], routines[0], routines[1]], today: tuesday)

        func titles(_ record: DayRecord) -> [String] {
            record.checkList.sorted { $0.order < $1.order }.map(\.title)
        }
        #expect(titles(today) == ["루틴 3", "루틴 1", "루틴 2"])
        #expect(titles(yesterday) == ["루틴 1", "루틴 2", "루틴 3"])
        #expect(try env.routines.routines().map(\.title) == ["루틴 3", "루틴 1", "루틴 2"])
    }

    @Test func invalidInputIsRejected() throws {
        let env = try TestEnv()
        #expect(throws: DaylogError.emptyTitle) {
            try env.routines.add(title: "   ", today: monday)
        }
        #expect(throws: DaylogError.noWeekdays) {
            try env.routines.add(title: "운동", weekdays: [], today: monday)
        }
        #expect(try env.routines.routines().isEmpty)

        let long = try env.routines.add(title: String(repeating: "가", count: 200), today: monday)
        #expect(long.title.count == RoutineService.maxTitleLength)

        // 같은 이름은 허용하되 서로 다른 루틴이다.
        let first = try env.routines.add(title: "독서", today: monday)
        let second = try env.routines.add(title: "독서", today: monday)
        #expect(first.id != second.id)
    }
}
