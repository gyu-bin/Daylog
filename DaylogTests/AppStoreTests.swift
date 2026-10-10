import Foundation
import SwiftData
import Testing
@testable import Daylog

@MainActor
private func makeStore(_ env: TestEnv, today: Day) -> (AppStore, TestClock) {
    let clock = TestClock(today)
    let store = AppStore(container: env.container, clock: { clock.today })
    store.start()
    return (store, clock)
}

/// 17-8. 빈 상태
@MainActor
struct EmptyStateTests {
    @Test func firstLaunchHasNoRoutinesAndNoFakeNumbers() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: saturday)

        #expect(store.routines.isEmpty)
        #expect(!store.hasRoutines)
        #expect(store.checks.isEmpty)
        #expect(!store.stats.hasStarted)
        #expect(store.stats.today.percent == nil)
        #expect(store.stats.weeklyAverage == nil)
        #expect(store.stats.currentStreak == 0)
        #expect(store.stats.longestStreak == 0)
        #expect(store.stats.routineRates.isEmpty)
        #expect(store.stats.trend.allSatisfy { $0.status == .preStart })
        #expect(try env.context.fetchCount(FetchDescriptor<RoutineItem>()) == 0)
        #expect(try env.context.fetchCount(FetchDescriptor<RoutineRevision>()) == 0)
    }

    @Test func recordWithoutRoutinesIsStillEmptyState() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: saturday)
        store.setText("바나나", at: \.snack)
        store.flush()

        #expect(try env.context.fetchCount(FetchDescriptor<DayRecord>()) == 1)
        #expect(store.record?.isRecorded == true)
        #expect(!store.hasRoutines)
        #expect(!store.stats.hasStarted)
        #expect(store.stats.today.status == .preStart)
    }

    @Test func firstRoutineSetsStatsStartAndAppearsToday() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: saturday)

        #expect(store.addRoutine(title: "아침 운동 30분"))

        #expect(try env.settings.existingSettings()?.firstRoutineDay == saturday)
        #expect(store.stats.firstDay == saturday)
        #expect(store.checks.map(\.title) == ["아침 운동 30분"])
        #expect(store.stats.today == DayOutcome(day: saturday, status: .unrecorded, done: 0, total: 1))

        let id = try #require(store.checks.first?.routineID)
        store.setDone(routineID: id, true)
        #expect(store.stats.today.percent == 100)
        #expect(store.stats.currentStreak == 1)
        #expect(store.monthOutcomes[saturday]?.percent == 100)

        // 두 번째 루틴이 시작일을 바꾸지 않는다.
        store.addRoutine(title: "독서")
        #expect(try env.settings.existingSettings()?.firstRoutineDay == saturday)
        #expect(try env.context.fetchCount(FetchDescriptor<AppSettings>()) == 1)
    }

    @Test func blankTitleCreatesNothing() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: saturday)
        #expect(!store.addRoutine(title: ""))
        #expect(!store.addRoutine(title: "   \n"))
        #expect(store.routines.isEmpty)
        #expect(store.errorMessage == nil)
    }

    @Test func suggestionChipsCreateRoutinesAndDisappear() throws {
        let env = try TestEnv()
        let (store, clock) = makeStore(env, today: saturday)
        #expect(store.suggestions == RoutineSuggestions.all)

        store.addRoutine(title: "독서")
        #expect(store.routines.map(\.title) == ["독서"])
        #expect(!store.suggestions.contains("독서"))
        #expect(store.suggestions.count == RoutineSuggestions.all.count - 1)

        store.addRoutine(title: "운동")
        #expect(store.suggestions.filter { $0 == "운동" || $0 == "독서" }.isEmpty)

        // 다음 날부터는 추천을 보여 주지 않는다.
        clock.today = sunday
        store.refreshToday()
        #expect(store.suggestions.isEmpty)
    }
}

/// 17-9. 오늘 날짜가 바뀔 때
@MainActor
struct DayChangeTests {
    @Test func midnightMovesToNewTodayAndRefreshesStats() throws {
        let env = try TestEnv()
        let (store, clock) = makeStore(env, today: saturday)
        store.addRoutine(title: "운동")
        store.setDone(routineID: try #require(store.checks.first?.routineID), true)
        store.setText("내일은 일찍", at: \.tomorrowTask)

        clock.today = sunday
        store.refreshToday()

        #expect(store.today == sunday)
        #expect(store.selectedDay == sunday)
        #expect(store.record?.dateKey == sunday.key)
        #expect(store.checks.count == 1)
        #expect(store.checks.first?.isDone == false)
        #expect(store.stats.today == DayOutcome(day: sunday, status: .unrecorded, done: 0, total: 1))
        #expect(store.stats.currentStreak == 1) // 어제 달성, 오늘은 아직
        #expect(store.calendarMonth == sunday.firstOfMonth)

        // 어제 기록과 입력하던 텍스트는 저장되어 있다.
        let yesterday = try #require(try DayRecordService(context: env.freshContext()).record(on: saturday))
        #expect(yesterday.tomorrowTask == "내일은 일찍")
        #expect(yesterday.checkList.first?.isDone == true)
        #expect(try env.context.fetchCount(FetchDescriptor<DayRecord>()) == 2)
    }

    @Test func viewingPastDayKeepsSelectionButStatsFollowToday() throws {
        let env = try TestEnv()
        let (store, clock) = makeStore(env, today: saturday)
        store.addRoutine(title: "운동")
        store.select(saturday.adding(days: -1))

        clock.today = sunday
        store.refreshToday()

        #expect(store.selectedDay == saturday.adding(days: -1))
        #expect(store.today == sunday)
        #expect(store.stats.today.day == sunday)
        #expect(store.stats.week.last?.day == sunday)
    }

    @Test func typingAtMidnightKeepsTheDayBeingEdited() throws {
        let env = try TestEnv()
        let (store, clock) = makeStore(env, today: saturday)
        store.addRoutine(title: "운동")
        store.setEditing(true, source: "meal")
        store.setText("계란 2개", at: \.dinner)

        clock.today = sunday
        store.refreshToday()

        #expect(store.selectedDay == saturday)
        #expect(store.text(\.dinner) == "계란 2개")
        #expect(store.stats.today.day == sunday)
        #expect(!store.isViewingToday)

        store.setEditing(false, source: "meal")
        store.goToToday()
        #expect(store.selectedDay == sunday)
        #expect(store.text(\.dinner) == "")
        #expect(try DayRecordService(context: env.freshContext()).record(on: saturday)?.dinner == "계란 2개")
    }

    @Test func clockMovingBackwardNeverLeavesSelectionInTheFuture() throws {
        let env = try TestEnv()
        let (store, clock) = makeStore(env, today: sunday)
        store.addRoutine(title: "운동")

        clock.today = saturday // 서쪽 시간대로 이동
        store.refreshToday()

        #expect(store.selectedDay == saturday)
        #expect(!store.canGoToNextDay)
        // 이미 만들어진 기록은 다른 날짜로 옮겨지거나 중복되지 않는다.
        #expect(try DayRecordService(context: env.context).record(on: sunday) != nil)
        #expect(try env.context.fetchCount(FetchDescriptor<DayRecord>()) == 2)
    }

    @Test func futureDatesCannotBeSelected() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: saturday)
        store.goToNextDay()
        store.select(sunday)
        #expect(store.selectedDay == saturday)
        #expect(store.errorMessage == nil)
        #expect(try env.context.fetchCount(FetchDescriptor<DayRecord>()) == 1)

        store.goToPreviousDay()
        #expect(store.selectedDay == saturday.adding(days: -1))
        #expect(store.canGoToNextDay)
        store.goToNextDay()
        #expect(store.selectedDay == saturday)
    }

    @Test func calendarCannotMovePastCurrentMonth() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: saturday)
        #expect(!store.canShowNextMonth)
        store.showNextMonth()
        #expect(store.calendarMonth == day("2026-10-01"))

        store.showPreviousMonth()
        #expect(store.calendarMonth == day("2026-09-01"))
        #expect(store.monthOutcomes.count == 30)
        store.showNextMonth()
        #expect(store.monthOutcomes.count == 31)
        #expect(store.monthOutcomes[sunday]?.status == .future)
    }
}

@MainActor
struct RoutineEditingFromStoreTests {
    @Test func editingRoutinesWhileViewingPastDayLeavesThatDayAlone() throws {
        let env = try TestEnv()
        let friday = saturday.adding(days: -1)
        let (store, clock) = makeStore(env, today: friday)
        store.addRoutine(title: "운동")
        store.setDone(routineID: try #require(store.checks.first?.routineID), true)
        clock.today = saturday
        store.refreshToday()

        store.select(friday)
        let routine = try #require(store.routines.first)
        #expect(store.updateRoutine(routine, title: "운동 (러닝)"))
        store.addRoutine(title: "독서")

        #expect(store.checks.map(\.title) == ["운동"])
        #expect(store.checks.first?.isDone == true)
        store.goToToday()
        #expect(store.checks.map(\.title) == ["운동 (러닝)", "독서"])
        #expect(store.stats.today.total == 2)
    }

    @Test func movingRoutinesReordersTodayChecks() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: saturday)
        ["가", "나", "다"].forEach { store.addRoutine(title: $0) }

        store.moveActiveRoutine(try #require(store.routines.last), by: -1)
        #expect(store.checks.map(\.title) == ["가", "다", "나"])

        // 끌어다 놓기: 맨 위 "가"를 맨 아래 "나" 자리로 내린다.
        var ids = store.activeRoutines.map(\.id)
        store.moveActiveRoutine(id: ids[0], to: ids[2])
        #expect(store.activeRoutines.map(\.title) == ["다", "나", "가"])
        #expect(store.checks.map(\.title) == ["다", "나", "가"])

        // 아래에서 위로: "가"를 "다" 자리로 올린다.
        ids = store.activeRoutines.map(\.id)
        store.moveActiveRoutine(id: ids[2], to: ids[0])
        #expect(store.activeRoutines.map(\.title) == ["가", "다", "나"])
        #expect(store.checks.map(\.title) == ["가", "다", "나"])

        // 제자리에 놓거나 범위를 벗어난 이동은 무시한다.
        store.moveActiveRoutine(id: ids[2], to: ids[2])
        store.moveActiveRoutine(try #require(store.activeRoutines.first), by: -1)
        store.moveActiveRoutine(try #require(store.activeRoutines.last), by: 1)
        #expect(store.activeRoutines.map(\.title) == ["가", "다", "나"])
    }

    @Test func invalidEditReportsErrorAndKeepsRoutine() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: saturday)
        store.addRoutine(title: "운동")
        let routine = try #require(store.routines.first)

        #expect(!store.updateRoutine(routine, weekdays: []))
        #expect(store.errorMessage != nil)
        #expect(routine.weekdays == Weekdays.all)
        #expect(routine.title == "운동")
    }
}
