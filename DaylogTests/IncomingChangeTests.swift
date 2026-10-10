import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 8·9·10. 다른 기기의 변경이 들어왔을 때
@MainActor
struct IncomingChangeTests {
    private func makeStore(_ env: TestEnv, today: Day = saturday) -> AppStore {
        let store = AppStore(container: env.container, clock: { today })
        store.start()
        return store
    }

    /// 입력하던 화면의 기록이 대표가 아니게 돼도 내용은 대표로 옮겨져 그대로 보인다.
    @Test func screenFollowsTheRepresentativeRecord() throws {
        let env = try TestEnv()
        let store = makeStore(env)
        store.addRoutine(title: "운동")
        store.setDone(routineID: try #require(store.checks.first?.routineID), true)
        store.setText("입력하던 점심", at: \.lunch)
        let mine = try #require(store.record)

        let remote = insertRemoteRecord(env, day: saturday, createdAt: earlier, routines: store.routines)
        remote.breakfast = "다른 Mac에서 쓴 아침"
        store.handleExternalChanges()

        #expect(store.record === remote)
        #expect(store.record !== mine)
        #expect(store.text(\.lunch) == "입력하던 점심")
        #expect(store.text(\.breakfast) == "다른 Mac에서 쓴 아침")
        #expect(store.checks.map(\.isDone) == [true])
        #expect(store.stats.today == DayOutcome(day: saturday, status: .recorded, done: 1, total: 1))
        #expect(store.errorMessage == nil)

        // 이어서 입력하면 대표 기록에 저장된다.
        store.setText("입력하던 점심, 추가", at: \.lunch)
        store.flush()
        #expect(remote.lunch == "입력하던 점심, 추가")
    }

    /// 다른 기기에서 만든 루틴이 들어오면 오늘 목록에도 나타난다(체크는 한 번만).
    @Test func routineFromAnotherDeviceAppearsToday() throws {
        let env = try TestEnv()
        let store = makeStore(env)
        store.addRoutine(title: "운동")

        let incoming = RoutineItem(title: "독서", order: 1)
        env.context.insert(incoming)
        env.context.insert(RoutineRevision(routine: incoming, effectiveFrom: saturday))
        store.handleExternalChanges()
        store.handleExternalChanges()

        #expect(store.activeRoutines.map(\.title) == ["운동", "독서"])
        #expect(store.checks.map(\.title) == ["운동", "독서"])
        #expect(store.record?.physicalChecks.count == 2)
        #expect(store.stats.today.total == 2)
    }

    /// TEST F·G: 다른 기기에서 이름을 바꾸거나 보관하면 오늘은 따라가고 과거는 그대로다.
    @Test func renameAndArchiveFromAnotherDeviceKeepPastRecords() throws {
        let env = try TestEnv()
        let friday = saturday.adding(days: -1)
        let routines = try env.addRoutines(2, today: friday)
        try env.log(friday, done: 2)
        let store = makeStore(env)
        store.setDone(routineID: routines[1].id, true)

        // 다른 기기의 RoutineService가 한 일이 동기화로 들어온 상태: 루틴 정의와 이력만 바뀌어 있다.
        routines[0].title = "루틴 1 (새 이름)"
        routines[0].updatedAt = .now
        routines[1].isArchived = true
        routines[1].updatedAt = .now
        store.handleExternalChanges()

        #expect(store.checks.map(\.title) == ["루틴 1 (새 이름)", "루틴 2"]) // 완료한 항목은 보관돼도 남는다
        #expect(store.activeRoutines.map(\.title) == ["루틴 1 (새 이름)"])
        store.select(friday)
        #expect(store.checks.map(\.title) == ["루틴 1", "루틴 2"])
        #expect(store.checks.allSatisfy { $0.isDone })
    }

    /// TEST H: 다른 기기에서 바꾼 기준값이 통계에 적용된다.
    @Test func thresholdFromAnotherDeviceIsApplied() throws {
        let env = try TestEnv()
        try env.addRoutines(4, today: saturday.adding(days: -1))
        try env.log(saturday.adding(days: -1), done: 3) // 75%
        let store = makeStore(env)
        #expect(store.stats.currentStreak == 0)

        let settings = try #require(try env.settings.existingSettings())
        settings.achieveThreshold = 70
        settings.updatedAt = .now
        store.handleExternalChanges()

        #expect(store.threshold == 70)
        #expect(store.stats.currentStreak == 1)
    }

    /// 두 기기가 각자 설정을 만든 경우: 기준값은 나중에 바꾼 값, 통계 시작일은 이른 쪽.
    @Test func duplicateSettingsAreMergedWithoutDeleting() throws {
        let env = try TestEnv()
        try env.addRoutines(1, today: saturday)
        try env.settings.setThreshold(90, now: Date(timeIntervalSince1970: 100))

        let remote = AppSettings(achieveThreshold: 60, firstRoutineDate: monday.anchorDate)
        remote.updatedAt = Date(timeIntervalSince1970: 200)
        env.context.insert(remote)
        _ = try reconcile(env)

        let representative = try #require(try env.settings.existingSettings())
        #expect(representative.achieveThreshold == 60)
        #expect(representative.firstRoutineDay == monday)
        #expect(try env.context.fetchCount(FetchDescriptor<AppSettings>()) == 2)
        #expect(try env.stats.dashboard(today: saturday).threshold == 60)
        #expect(try reconcile(env).changed == false)

        // 이쪽에서 다시 바꾸면 그 값이 최신이 된다.
        try env.settings.setThreshold(85)
        _ = try reconcile(env)
        #expect(try env.stats.dashboard(today: saturday).threshold == 85)
    }

    /// TEST K: 같은 날 두 기기가 같은 루틴을 고쳐 이력이 둘이면, 나중에 고친 쪽이 그날의 상태다.
    @Test func duplicateRevisionsResolveToTheLatestEdit() throws {
        let env = try TestEnv()
        let routine = try env.routines.add(title: "회고", weekdays: [1], today: monday, now: earlier)
        let wednesday = monday.adding(days: 2)
        try env.routines.update(routine, weekdays: [1, 2, 3], today: wednesday, now: Date(timeIntervalSince1970: 3_000))

        // 다른 기기가 같은 날 더 늦게 고친 이력이 들어왔다.
        let other = RoutineRevision(routine: routine, effectiveFrom: wednesday, now: Date(timeIntervalSince1970: 4_000))
        other.weekdayMask = Weekdays.mask(Weekdays.all)
        env.context.insert(other)
        try env.context.save()

        let resolver = try ScheduleResolver(context: env.context)
        #expect(resolver.scheduled(on: monday.adding(days: 1)).isEmpty)      // 변경 전 화요일은 그대로
        #expect(resolver.scheduled(on: wednesday.adding(days: 1)).count == 1) // 목요일: 나중 이력(매일) 기준
        #expect(try env.context.fetchCount(FetchDescriptor<RoutineRevision>()) == 3)

        // 이후 이쪽에서 다시 고치면 가장 최근 이력을 고쳐 쓴다(새로 쌓거나 지우지 않는다).
        try env.routines.update(routine, weekdays: [1], today: wednesday, now: Date(timeIntervalSince1970: 5_000))
        #expect(try ScheduleResolver(context: env.context).scheduled(on: wednesday.adding(days: 1)).isEmpty)
        #expect(try env.context.fetchCount(FetchDescriptor<RoutineRevision>()) == 3)
    }

    /// 시간대가 앞선 기기가 "내일" 날짜로 남긴 이력을 지우지 않는다.
    @Test func revisionFromADeviceAheadInTimeIsNotDeleted() throws {
        let env = try TestEnv()
        let routine = try env.routines.add(title: "일기", today: saturday)
        try env.routines.update(routine, weekdays: Weekdays.workdays, today: sunday) // 다른 기기는 이미 일요일
        try env.routines.update(routine, title: "일기 쓰기", today: saturday)        // 이 기기는 아직 토요일

        let revisions = try env.context.fetch(FetchDescriptor<RoutineRevision>(sortBy: [SortDescriptor(\.effectiveFromKey)]))
        #expect(revisions.map(\.effectiveFromKey) == [saturday.key, sunday.key])
        #expect(revisions.last?.title == "일기 쓰기")
        #expect(revisions.last?.weekdayMask == Weekdays.mask(Weekdays.workdays))
    }
}
