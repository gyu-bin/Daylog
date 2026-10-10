import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 17-3. 루틴 변경 이력
@MainActor
struct RoutineRevisionTests {
    private func scheduledCount(_ env: TestEnv, on day: Day) throws -> Int {
        try ScheduleResolver(context: env.context).scheduled(on: day).count
    }

    @Test func wideningWeekdaysDoesNotChangeEarlierUnrecordedDays() throws {
        let env = try TestEnv()
        let routine = try env.routines.add(title: "주간 회고", weekdays: [1], today: monday)
        let tuesday = monday.adding(days: 1)
        let wednesday = monday.adding(days: 2)
        #expect(try scheduledCount(env, on: tuesday) == 0)

        try env.routines.update(routine, weekdays: Weekdays.all, today: wednesday)

        #expect(try scheduledCount(env, on: monday) == 1)
        #expect(try scheduledCount(env, on: tuesday) == 0) // 변경 이전의 미기록 화요일은 그대로
        #expect(try scheduledCount(env, on: wednesday) == 1)
        #expect(try scheduledCount(env, on: wednesday.adding(days: 1)) == 1)

        // 통계와 과거 날짜를 처음 열 때의 스냅샷도 같은 판정을 쓴다.
        let outcomes = try env.stats.outcomes(from: monday, to: wednesday, today: wednesday)
        #expect(outcomes.map(\.status) == [.unrecorded, .rest, .unrecorded])
        #expect(try env.records.fetchOrCreate(day: tuesday, today: wednesday).checkList.isEmpty)
    }

    @Test func archiveAndRestoreKeepPastSchedule() throws {
        let env = try TestEnv()
        let routine = try env.routines.add(title: "스트레칭", today: monday)
        let wednesday = monday.adding(days: 2)
        let friday = monday.adding(days: 4)

        try env.routines.setArchived(routine, true, today: wednesday)
        try env.routines.setArchived(routine, false, today: friday)

        let expected = [1, 1, 0, 0, 1, 1] // 월 화 | 수 목 보관 | 금 토 복원
        for (offset, count) in expected.enumerated() {
            #expect(try scheduledCount(env, on: monday.adding(days: offset)) == count)
        }
    }

    @Test func multipleEditsOnOneDayResolveToFinalState() throws {
        let env = try TestEnv()
        let routine = try env.routines.add(title: "독서", today: monday)
        let wednesday = monday.adding(days: 2)

        try env.routines.update(routine, title: "독서 10쪽", today: wednesday)
        try env.routines.update(routine, weekdays: Weekdays.weekend, today: wednesday)
        try env.routines.setArchived(routine, true, today: wednesday)
        try env.routines.setArchived(routine, false, today: wednesday)
        try env.routines.update(routine, title: "독서 20쪽", weekdays: [3, 6], today: wednesday)

        let resolver = try ScheduleResolver(context: env.context)
        #expect(resolver.state(of: routine.id, on: monday.adding(days: 1))?.title == "독서")
        #expect(resolver.state(of: routine.id, on: wednesday)?.title == "독서 20쪽")
        #expect(resolver.scheduled(on: wednesday).count == 1)
        #expect(resolver.scheduled(on: wednesday.adding(days: 1)).isEmpty)
        #expect(resolver.scheduled(on: saturday).count == 1)

        // 날짜당 이력은 한 건: 생성일 + 수정일
        #expect(try env.context.fetchCount(FetchDescriptor<RoutineRevision>()) == 2)
    }

    @Test func noRevisionBeforeCreation() throws {
        let env = try TestEnv()
        let routine = try env.routines.add(title: "명상", today: saturday)
        let resolver = try ScheduleResolver(context: env.context)
        #expect(resolver.state(of: routine.id, on: saturday.adding(days: -1)) == nil)
        #expect(resolver.scheduled(on: saturday.adding(days: -1)).isEmpty)
        #expect(resolver.scheduled(on: saturday).count == 1)
    }

    @Test func unchangedEditDoesNotAddRevision() throws {
        let env = try TestEnv()
        let routine = try env.routines.add(title: "산책", today: monday)
        try env.routines.update(routine, title: "산책", today: monday.adding(days: 3))
        #expect(try env.context.fetchCount(FetchDescriptor<RoutineRevision>()) == 1)
    }

    /// 시간대 이동 등으로 "오늘"이 하루 뒤로 물러난 뒤 수정하면, 앞선 날짜에 적어 둔 이력이 되살아나지 않는다.
    @Test func editAfterClockMovesBackSupersedesLaterRevisions() throws {
        let env = try TestEnv()
        let routine = try env.routines.add(title: "일기", today: monday)
        let wednesday = monday.adding(days: 2)
        let tuesday = monday.adding(days: 1)

        try env.routines.update(routine, weekdays: [1], today: wednesday)
        try env.routines.update(routine, weekdays: Weekdays.workdays, today: tuesday)

        #expect(try scheduledCount(env, on: tuesday) == 1)
        #expect(try scheduledCount(env, on: wednesday) == 1)
    }

    @Test func revisionsSurviveRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaylogTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Daylog.store")
        let wednesday = monday.adding(days: 2)
        var routineID: UUID?

        do {
            let container = try DaylogStore.makeContainer(.file(url))
            let service = RoutineService(context: container.mainContext)
            let routine = try service.add(title: "주간 회고", weekdays: [1], today: monday)
            try service.update(routine, title: "회고", weekdays: Weekdays.all, today: wednesday)
            routineID = routine.id
        }

        let reopened = try DaylogStore.makeContainer(.file(url))
        let resolver = try ScheduleResolver(context: reopened.mainContext)
        let id = try #require(routineID)
        #expect(resolver.state(of: id, on: monday)?.title == "주간 회고")
        #expect(resolver.scheduled(on: monday.adding(days: 1)).isEmpty)
        #expect(resolver.state(of: id, on: wednesday)?.title == "회고")
        #expect(resolver.scheduled(on: wednesday.adding(days: 1)).count == 1)
    }
}
