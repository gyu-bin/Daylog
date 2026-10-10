import Foundation
import Observation
import SwiftData
import Testing
@testable import Daylog

/// v1.3.2: 체크와 체크 해제. 화면이 읽는 값(`store.checkSections`)이 저장된 값과 항상 같아야 한다.
@MainActor
struct CheckToggleTests {
    private final class Flag: @unchecked Sendable {
        var fired = false
    }

    private func makeStore(_ env: TestEnv, today: Day) -> (AppStore, TestClock) {
        let clock = TestClock(today)
        let store = AppStore(container: env.container, clock: { clock.today })
        store.start()
        return (store, clock)
    }

    /// 그룹 하나에 항목을 `titles`대로 만든다.
    @discardableResult
    private func addGroup(_ title: String, items titles: [String], to store: AppStore) throws -> RoutineGroup {
        let group = try #require(store.addGroup(title: title))
        for title in titles { store.addRoutine(title: title, in: group) }
        return group
    }

    private func id(_ title: String, in store: AppStore) throws -> UUID {
        try #require(store.checkSections.flatMap(\.checks).first { $0.title == title }).id
    }

    /// 화면에 보이는 완료 여부(그룹 순서 → 항목 순서).
    private func shown(_ store: AppStore) -> [Bool] {
        store.checkSections.flatMap(\.checks).map(\.isDone)
    }

    /// 저장소에 저장된 완료 여부. 새 컨텍스트로 읽어 화면의 값과 독립적으로 확인한다.
    private func saved(_ env: TestEnv, on day: Day) throws -> [Bool] {
        let record = try #require(try DayRecordService(context: env.freshContext()).record(on: day))
        return record.checkList.map(\.isDone)
    }

    /// 화면이 하듯이 `checkSections`를 읽어 관찰을 걸어 둔다. 값이 바뀌면 `fired`가 켜진다.
    private func watch(_ store: AppStore) -> Flag {
        let flag = Flag()
        withObservationTracking { _ = store.checkSections } onChange: { flag.fired = true }
        return flag
    }

    // MARK: - 기본 동작 (TEST A, B, C, M)

    @Test func checkThenUncheck() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        try addGroup("아침 루틴", items: ["매일묵상", "필사하기"], to: store)
        let target = try id("매일묵상", in: store)
        #expect(shown(store) == [false, false])

        store.setDone(routineID: target, true)
        #expect(shown(store) == [true, false])
        #expect(store.selectedOutcome.percent == 50)
        #expect(try saved(env, on: monday) == [true, false])

        store.setDone(routineID: target, false)
        #expect(shown(store) == [false, false])
        #expect(store.selectedOutcome.percent == 0)
        #expect(store.stats.today.done == 0)
        #expect(try saved(env, on: monday) == [false, false])
    }

    @Test func togglingTwiceReturnsToTheStart() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        try addGroup("아침 루틴", items: ["매일묵상"], to: store)
        let target = try id("매일묵상", in: store)

        store.toggleDone(routineID: target)
        store.toggleDone(routineID: target)
        #expect(shown(store) == [false])
        #expect(try saved(env, on: monday) == [false])
    }

    @Test func repeatedTogglesKeepScreenAndStoreInStep() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        try addGroup("아침 루틴", items: ["매일묵상", "필사하기"], to: store)
        let target = try id("필사하기", in: store)

        for round in 1...9 {
            store.toggleDone(routineID: target)
            let expected = round % 2 == 1
            #expect(shown(store) == [false, expected])
            #expect(try saved(env, on: monday) == [false, expected])
            #expect(store.stats.today.done == (expected ? 1 : 0))
            // 사이사이에 외부 변경 처리가 끼어들어도 같다.
            if round % 3 == 0 { store.handleExternalChanges() }
            #expect(shown(store) == [false, expected])
        }
    }

    // MARK: - 화면 갱신 (실제 오류의 원인)

    /// 외부 변경 처리(앱 활성화, iCloud 변경 알림)가 지나간 뒤에도 체크를 바꾸면 화면이 알림을 받는다.
    /// v1.3.1에서는 화면이 임시 모델 객체를 직접 관찰해서, 이 처리 뒤에는 알림이 끊겼다.
    @Test func screenIsNotifiedAfterExternalChanges() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        try addGroup("아침 루틴", items: ["매일묵상", "필사하기"], to: store)
        let target = try id("매일묵상", in: store)
        store.setDone(routineID: target, true)

        var flag = watch(store)
        store.handleExternalChanges()
        // 화면은 알림을 받으면 다시 그리면서 관찰을 새로 건다.
        if flag.fired { flag = watch(store) }
        #expect(shown(store) == [true, false])

        store.setDone(routineID: target, false)
        #expect(flag.fired)
        #expect(shown(store) == [false, false])

        // 저장이 한 번 지나간 뒤 다시 바꿔도 마찬가지다.
        flag = watch(store)
        store.setDone(routineID: target, true)
        #expect(flag.fired)
        #expect(shown(store) == [true, false])
    }

    /// 화면이 예전 값을 들고 "이미 그 값"으로 다시 써 보내도, 화면의 값은 저장된 값으로 맞춰진다.
    @Test func writingTheSameValueStillResyncsTheScreen() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        try addGroup("아침 루틴", items: ["매일묵상"], to: store)
        let target = try id("매일묵상", in: store)

        // 화면을 거치지 않고 저장소의 값이 바뀐 상황(다른 기기의 변경이 들어온 직후 등).
        let check = try #require(store.checks.first)
        try env.records.setDone(check, true)
        store.setDone(routineID: target, true)
        #expect(shown(store) == [true])
    }

    // MARK: - 달성률 (TEST D, H, I)

    @Test func fourOfFiveThenOneUnchecked() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        try addGroup("아침 루틴", items: ["가", "나", "다", "라", "마"], to: store)
        for title in ["가", "나", "다", "라"] { store.setDone(routineID: try id(title, in: store), true) }
        #expect(store.selectedOutcome.percent == 80)
        #expect(store.stats.today.percent == 80)

        store.setDone(routineID: try id("라", in: store), false)
        #expect(store.selectedOutcome.percent == 60)
        #expect(store.stats.today.percent == 60)
        #expect(store.stats.weeklyAverage == 60)
    }

    @Test func groupAndOverallProgressFollowAnUncheck() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        let morning = try addGroup("아침 루틴", items: ["매일묵상", "필사하기"], to: store)
        let workout = try addGroup("운동", items: ["러닝", "근력"], to: store)
        for title in ["매일묵상", "필사하기", "러닝"] { store.setDone(routineID: try id(title, in: store), true) }

        func section(_ group: RoutineGroup) throws -> CheckSection {
            try #require(store.checkSections.first { $0.id == group.id })
        }
        #expect(try section(morning).done == 2)
        #expect(try section(workout).done == 1)
        #expect(store.stats.today.percent == 75)
        #expect(store.stats.groupRates.first { $0.groupID == morning.id }?.percent == 100)

        store.setDone(routineID: try id("필사하기", in: store), false)
        #expect(try section(morning).done == 1)
        #expect(try section(morning).percent == 50)
        #expect(try section(workout).done == 1)
        #expect(store.stats.today.percent == 50)
        #expect(store.stats.groupRates.first { $0.groupID == morning.id }?.percent == 50)
        #expect(store.stats.groupRates.first { $0.groupID == workout.id }?.percent == 50)
        #expect(store.stats.routineRates.first { $0.title == "필사하기" }?.percent == 0)
        #expect(store.monthOutcomes[monday]?.percent == 50)
        #expect(store.stats.trend.last?.percent == 50)
        #expect(store.periodStats(.week).outcomes.last?.percent == 50)
        #expect(store.periodStats(.month).heatmap.last?.done == 2)
    }

    /// 기준 이상이던 날을 해제해 기준 아래로 내리면 연속 달성일도 바로 줄어든다.
    @Test func streaksFollowAnUncheck() throws {
        let env = try TestEnv()
        let (store, _) = makeStore(env, today: monday)
        try addGroup("아침 루틴", items: ["가", "나"], to: store)
        for title in ["가", "나"] { store.setDone(routineID: try id(title, in: store), true) }
        #expect(store.stats.currentStreak == 1)
        #expect(store.stats.longestStreak == 1)

        store.setDone(routineID: try id("나", in: store), false)
        #expect(store.stats.currentStreak == 0)
        #expect(store.stats.longestStreak == 0)
    }

    // MARK: - 재실행과 과거 날짜 (TEST E, F, G)

    @Test func checkedAndUncheckedStatesSurviveRelaunch() throws {
        let env = try TestEnv()
        do {
            let (store, _) = makeStore(env, today: monday)
            try addGroup("아침 루틴", items: ["매일묵상", "필사하기"], to: store)
            store.setDone(routineID: try id("매일묵상", in: store), true)
            store.setDone(routineID: try id("필사하기", in: store), true)
            store.setDone(routineID: try id("필사하기", in: store), false)
        }
        // 같은 저장소로 앱을 다시 실행한다.
        let (relaunched, _) = makeStore(env, today: monday)
        #expect(shown(relaunched) == [true, false])
        #expect(relaunched.stats.today.done == 1)

        relaunched.setDone(routineID: try id("매일묵상", in: relaunched), false)
        let (again, _) = makeStore(env, today: monday)
        #expect(shown(again) == [false, false])
        #expect(again.stats.today.done == 0)
    }

    @Test func uncheckingAPastDayChangesOnlyThatDay() throws {
        let env = try TestEnv()
        let (store, clock) = makeStore(env, today: monday)
        try addGroup("아침 루틴", items: ["매일묵상", "필사하기"], to: store)
        store.setDone(routineID: try id("매일묵상", in: store), true)
        store.setDone(routineID: try id("필사하기", in: store), true)

        let tuesday = monday.adding(days: 1)
        clock.today = tuesday
        store.refreshToday()
        store.setDone(routineID: try id("매일묵상", in: store), true)
        #expect(store.stats.currentStreak == 1)

        store.select(monday)
        #expect(shown(store) == [true, true])
        store.setDone(routineID: try id("필사하기", in: store), false)
        #expect(shown(store) == [true, false])
        #expect(try saved(env, on: monday) == [true, false])
        #expect(try saved(env, on: tuesday) == [true, false])
        #expect(store.monthOutcomes[monday]?.percent == 50)
        #expect(store.stats.today.percent == 50)

        store.goToToday()
        #expect(shown(store) == [true, false])
    }
}
