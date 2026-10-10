import Foundation
import SwiftData
import Testing
@testable import Daylog

/// v1.3.1: 삭제(소프트 삭제)와 항목 편집 시트
@MainActor
struct SoftDeleteTests {
    private let tuesday = monday.adding(days: 1)

    private func makeStore(_ env: TestEnv, today: Day) -> (AppStore, TestClock) {
        let clock = TestClock(today)
        let store = AppStore(container: env.container, clock: { clock.today })
        store.start()
        return (store, clock)
    }

    /// 항목 삭제: 목록과 보관함에서 사라지고, 과거 기록·이력·통계는 그대로다.
    @Test func deletedRoutineDisappearsButHistoryStays() throws {
        let env = try TestEnv()
        let (store, clock) = makeStore(env, today: monday)
        let group = try #require(store.addGroup(title: "아침"))
        store.addRoutine(title: "물", in: group)
        store.addRoutine(title: "스트레칭", in: group)
        store.setDone(routineID: try #require(store.checks.first { $0.title == "스트레칭" }?.routineID), true)
        clock.today = tuesday
        store.refreshToday()
        let before = store.stats
        let stretch = try #require(store.routines.first { $0.title == "스트레칭" })

        store.deleteRoutine(stretch)

        #expect(store.routines.map(\.title) == ["물"])
        #expect(store.activeRoutines.map(\.title) == ["물"])
        #expect(store.archivedRoutines.isEmpty)
        #expect(store.checks.map(\.title) == ["물"]) // 오늘 미완료였으므로 오늘 목록에서도 빠진다
        // 레코드는 지우지 않는다.
        #expect(try env.context.fetchCount(FetchDescriptor<RoutineItem>()) == 2)
        #expect(stretch.deletedAt != nil)
        // 어제 기록과 어제까지의 통계는 그대로.
        store.select(monday)
        #expect(store.checks.map(\.title) == ["물", "스트레칭"])
        #expect(store.checks.map(\.isDone) == [false, true])
        #expect(store.stats.week.dropLast() == before.week.dropLast())
        #expect(store.stats.longestStreak == before.longestStreak)
        // 삭제한 항목도 지난 기록이 있는 동안은 항목별 통계에 남는다(표시만 "삭제됨").
        let rate = try #require(store.stats.routineRates.first { $0.title == "스트레칭" })
        #expect(rate.isRemoved)
        #expect(rate.done == 1)
        #expect(rate.scheduled == 1) // 삭제한 날부터는 예정에서 빠진다
        // 내일도 다시 나타나지 않는다.
        clock.today = tuesday.adding(days: 1)
        store.refreshToday()
        store.goToToday()
        #expect(store.checks.map(\.title) == ["물"])
    }

    /// 오늘 이미 완료한 항목을 삭제하면 오늘 기록에는 남는다(보관과 같은 규칙).
    @Test func deletingADoneRoutineKeepsTodaysCheck() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        let group = try #require(store.addGroup(title: "아침"))
        store.addRoutine(title: "물", in: group)
        store.setDone(routineID: try #require(store.checks.first?.routineID), true)

        store.deleteRoutine(try #require(store.routines.first))

        #expect(store.routines.isEmpty)
        #expect(store.checks.map(\.title) == ["물"])
        #expect(store.stats.today == DayOutcome(day: monday, status: .recorded, done: 1, total: 1))
    }

    /// 그룹 삭제: 소속 항목(보관된 것 포함)도 함께 삭제된다.
    @Test func deletingAGroupDeletesItsRoutines() throws {
        let env = try TestEnv()
        let (store, clock) = makeStore(env, today: monday)
        let morning = try #require(store.addGroup(title: "아침"))
        let evening = try #require(store.addGroup(title: "저녁"))
        ["물", "스트레칭", "필사"].forEach { store.addRoutine(title: $0, in: morning) }
        store.addRoutine(title: "일기", in: evening)
        store.setArchived(try #require(store.routines.first { $0.title == "필사" }), true)
        store.setDone(routineID: try #require(store.checks.first { $0.title == "물" }?.routineID), true)
        clock.today = tuesday
        store.refreshToday()

        #expect(try RoutineService(context: env.context).deleteGroup(morning, today: tuesday) == 3)
        store.handleExternalChanges()

        #expect(store.groups.map(\.title) == ["저녁"])
        #expect(store.archivedGroups.isEmpty)
        #expect(store.routines.map(\.title) == ["일기"])
        #expect(store.archivedRoutines.isEmpty)
        #expect(store.checkSections.map(\.group.title) == ["저녁"])
        #expect(try env.context.fetchCount(FetchDescriptor<RoutineGroup>()) == 2)
        #expect(try env.context.fetchCount(FetchDescriptor<RoutineItem>()) == 4)
        store.select(monday)
        #expect(store.checkSections.map(\.group.title) == ["아침", "저녁"])
        #expect(store.checks.count == 3)
        let groupRate = try #require(store.stats.groupRates.first { $0.title == "아침" })
        #expect(groupRate.isRemoved)
        #expect(groupRate.done == 1)
    }

    /// CloudKit 병합: 같은 ID의 사본이 삭제 전 상태로 들어와도 되살아나지 않는다.
    @Test func deletionWinsOverAStaleCopyFromAnotherDevice() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        let group = try #require(store.addGroup(title: "아침"))
        store.addRoutine(title: "물", in: group)
        let routine = try #require(store.routines.first)
        store.deleteRoutine(routine)
        store.deleteGroup(group)

        // 다른 기기가 아직 삭제를 모른 채 더 나중에 고친 사본.
        let staleItem = RoutineItem(id: routine.id, title: "물 2L", order: 0, createdAt: later, groupID: group.id)
        let staleGroup = RoutineGroup(id: group.id, title: "아침 루틴", colorKey: "blue", order: 0, createdAt: later)
        env.context.insert(staleItem)
        env.context.insert(staleGroup)
        try env.context.save()
        store.handleExternalChanges()
        store.handleExternalChanges()

        #expect(store.routines.isEmpty)
        #expect(store.groups.isEmpty)
        #expect(store.checks.isEmpty)
        #expect(try RoutineService(context: env.context).routines(includingRemoved: true).count == 1)
        #expect(try RoutineService(context: env.context).groups(includingRemoved: true).first?.isRemoved == true)
    }

    /// 다른 기기에서 삭제한 것이 들어오면 오늘 목록에서도 빠진다.
    @Test func deletionFromAnotherDeviceHidesTodaysCheck() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        let group = try #require(store.addGroup(title: "아침"))
        store.addRoutine(title: "물", in: group)
        store.addRoutine(title: "스트레칭", in: group)

        // 동기화로 삭제 시각만 들어온 상태.
        try #require(store.routines.first { $0.title == "물" }).deletedAt = .now
        try env.context.save()
        store.handleExternalChanges()

        #expect(store.checks.map(\.title) == ["스트레칭"])
        #expect(store.routines.map(\.title) == ["스트레칭"])
        #expect(store.stats.today.total == 1)
    }

    // MARK: - 편집 시트

    @Test func savingADraftAppliesEverythingAtOnce() throws {
        let env = try TestEnv()
        let (store, clock) = makeStore(env, today: monday)
        let morning = try #require(store.addGroup(title: "아침"))
        let workout = try #require(store.addGroup(title: "운동"))
        store.addRoutine(title: "헬스", in: morning)
        clock.today = tuesday
        store.refreshToday()
        let routine = try #require(store.routines.first)

        var draft = RoutineDraft(routine)
        draft.title = "  근력운동 "
        draft.weekdays = [1, 3, 5]
        draft.timeLabel = "19:00"
        draft.note = "하체"
        draft.groupID = workout.id
        #expect(store.apply(draft, to: routine))

        #expect(routine.title == "근력운동")
        #expect(routine.weekdays == [1, 3, 5])
        #expect(routine.timeLabel == "19:00")
        #expect(routine.note == "하체")
        #expect(routine.groupID == workout.id)
        #expect(Weekdays.summary(routine.weekdays) == "월·수·금")
        // 화요일은 이제 대상이 아니다: 오늘 목록에서 빠지고, 어제 기록은 그대로다.
        #expect(store.checks.isEmpty)
        store.select(monday)
        #expect(store.checks.map(\.title) == ["헬스"])
        #expect(store.checkSections.first?.group.title == "아침")
    }

    @Test func cancellingOrInvalidDraftChangesNothing() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        let group = try #require(store.addGroup(title: "아침"))
        store.addRoutine(title: "물", in: group)
        let routine = try #require(store.routines.first)
        let revisions = try env.context.fetchCount(FetchDescriptor<RoutineRevision>())

        // 취소: 초안만 바꾸고 저장하지 않는다.
        var cancelled = RoutineDraft(routine)
        cancelled.title = "다른 이름"
        cancelled.weekdays = [7]
        #expect(routine.title == "물")
        #expect(routine.weekdays == Weekdays.all)

        // 올바르지 않은 초안은 저장되지 않는다.
        var noDays = RoutineDraft(routine)
        noDays.weekdays = []
        #expect(noDays.validationMessage == "요일을 하나 이상 선택해 주세요.")
        #expect(!store.apply(noDays, to: routine))
        var noTitle = RoutineDraft(routine)
        noTitle.title = "   "
        #expect(noTitle.validationMessage == "이름을 입력해 주세요.")
        #expect(!store.apply(noTitle, to: routine))

        #expect(routine.title == "물")
        #expect(routine.weekdays == Weekdays.all)
        #expect(store.errorMessage == nil)
        #expect(try env.context.fetchCount(FetchDescriptor<RoutineRevision>()) == revisions)
        #expect(RoutineDraft(routine).validationMessage == nil)
    }

    @Test func weekdaySummaries() {
        #expect(Weekdays.summary(Weekdays.all) == "매일")
        #expect(Weekdays.summary([1, 2, 3, 4, 5]) == "평일")
        #expect(Weekdays.summary([7, 6]) == "주말")
        #expect(Weekdays.summary([5, 1, 3]) == "월·수·금")
        #expect(Weekdays.summary([2, 4, 6]) == "화·목·토")
        #expect(Weekdays.summary([7]) == "일")
    }
}
