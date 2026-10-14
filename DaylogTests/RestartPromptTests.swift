import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 다시 시작하기: 언제 띄우고, 언제 띄우지 않고, 닫은 뒤에는 어떻게 되는가.
@MainActor
struct RestartPromptTests {
    // 2026-10-05(월) … 10-11(일). 금요일은 10-09.
    private let friday = day("2026-10-09")

    private func done(_ key: String) -> DayOutcome { DayOutcome(day: day(key), status: .recorded, done: 1, total: 2) }
    private func missed(_ key: String) -> DayOutcome { DayOutcome(day: day(key), status: .unrecorded, done: 0, total: 2) }
    private func skipped(_ key: String) -> DayOutcome {
        DayOutcome(day: day(key), status: .recorded, done: 0, total: 2, skipped: 1)
    }
    private func off(_ key: String, _ status: DayStatus) -> DayOutcome { DayOutcome(day: day(key), status: status, done: 0, total: 0) }

    private func evaluate(_ outcomes: [DayOutcome], today: Day? = nil, dismissed: Day? = nil) -> RestartPrompt? {
        RestartPromptPolicy.evaluate(outcomes: outcomes, today: today ?? friday, dismissedDay: dismissed)
    }

    // MARK: - 표시 조건

    @Test func showsAfterThreeScheduledDaysWithNothingDone() {
        let three = [done("2026-10-05"), missed("2026-10-06"), missed("2026-10-07"), missed("2026-10-08"), missed("2026-10-09")]
        #expect(evaluate(three) == RestartPrompt(missedDays: 3, lastActiveDay: monday))
        // 이틀로는 띄우지 않는다.
        let two = [done("2026-10-06"), missed("2026-10-07"), missed("2026-10-08"), missed("2026-10-09")]
        #expect(evaluate(two) == nil)
    }

    @Test func vacationAndRestDaysAreNotCountedAsMissed() {
        // 휴가와 예정된 루틴이 없던 날은 세지 않고 건너간다.
        let withBreaks = [
            done("2026-10-03"), missed("2026-10-04"), off("2026-10-05", .vacation), off("2026-10-06", .rest),
            missed("2026-10-07"), missed("2026-10-08"), missed("2026-10-09"),
        ]
        #expect(evaluate(withBreaks)?.missedDays == 3)
        // 그 날들을 빼면 이틀뿐이면 띄우지 않는다.
        let short = [
            done("2026-10-04"), off("2026-10-05", .vacation), off("2026-10-06", .vacation),
            missed("2026-10-07"), missed("2026-10-08"), missed("2026-10-09"),
        ]
        #expect(evaluate(short) == nil)
        // 휴가 중에는 띄우지 않는다.
        let onVacation = [done("2026-10-04"), missed("2026-10-05"), missed("2026-10-06"), missed("2026-10-07"),
                          missed("2026-10-08"), off("2026-10-09", .vacation)]
        #expect(evaluate(onVacation) == nil)
    }

    @Test func skippedDaysAreNotAbsence() {
        // 건너뛰기로 표시한 날은 쉬기로 정한 날이다. 그날에서 세는 것이 끊긴다.
        let skippedMidway = [
            done("2026-10-04"), missed("2026-10-05"), skipped("2026-10-06"), missed("2026-10-07"), missed("2026-10-08"),
            missed("2026-10-09"),
        ]
        #expect(evaluate(skippedMidway) == nil)
        #expect(RestartPromptPolicy.isActive(skipped("2026-10-06")))
        // 오늘 건너뛰기로 정했으면 띄우지 않는다.
        let skippedToday = [done("2026-10-05"), missed("2026-10-06"), missed("2026-10-07"), missed("2026-10-08"), skipped("2026-10-09")]
        #expect(evaluate(skippedToday) == nil)
    }

    @Test func hiddenOnceTodayHasACompletedRoutine() {
        let before = [done("2026-10-05"), missed("2026-10-06"), missed("2026-10-07"), missed("2026-10-08"), missed("2026-10-09")]
        #expect(evaluate(before) != nil)
        let after = Array(before.dropLast()) + [done("2026-10-09")]
        #expect(evaluate(after) == nil)
    }

    @Test func daysBeforeTheFirstRoutineAreIgnored() {
        // 루틴을 만든 지 이틀: 그 전은 세지 않는다.
        let fresh = [off("2026-10-05", .preStart), off("2026-10-06", .preStart), missed("2026-10-07"), missed("2026-10-08"), missed("2026-10-09")]
        #expect(evaluate(fresh) == nil)
    }

    // MARK: - 닫기

    @Test func dismissalLastsUntilTheUserPractisesAgain() {
        let gap = [done("2026-10-05"), missed("2026-10-06"), missed("2026-10-07"), missed("2026-10-08"), missed("2026-10-09")]
        // 금요일에 닫았다: 같은 기간에는 다시 띄우지 않는다(다음 날이 되어도).
        #expect(evaluate(gap, dismissed: friday) == nil)
        #expect(evaluate(gap + [missed("2026-10-10")], today: saturday, dismissed: friday) == nil)
        // 닫은 뒤에 다시 실천했다가 또 사흘을 쉬면 새 기간이라 다시 띄운다.
        let again = [done("2026-10-10"), missed("2026-10-11"), missed("2026-10-12"), missed("2026-10-13"), missed("2026-10-14")]
        #expect(evaluate(again, today: day("2026-10-14"), dismissed: friday)?.lastActiveDay == saturday)
        // 닫은 날에 실천한 뒤의 새 기간도 다시 띄운다.
        let sameDay = [done("2026-10-09"), missed("2026-10-10"), missed("2026-10-11"), missed("2026-10-12"), missed("2026-10-13")]
        #expect(evaluate(sameDay, today: day("2026-10-13"), dismissed: friday) != nil)
        // 마지막으로 실천한 날이 조회 기간 밖이면(오래 쉼) 닫은 상태가 그대로다.
        let long = [missed("2026-10-06"), missed("2026-10-07"), missed("2026-10-08"), missed("2026-10-09")]
        #expect(evaluate(long)?.lastActiveDay == nil)
        #expect(evaluate(long, dismissed: monday) == nil)
    }

    @Test func dismissalIsStoredOnThisDeviceAndSurvivesRelaunch() {
        let defaults = testDefaults()
        let preferences = DevicePreferences(defaults: defaults)
        #expect(preferences.restartDismissedDay == nil)
        preferences.setRestartDismissedDay(friday)
        #expect(DevicePreferences(defaults: defaults).restartDismissedDay == friday)
        preferences.setRestartDismissedDay(nil)
        #expect(DevicePreferences(defaults: defaults).restartDismissedDay == nil)
    }

    // MARK: - 실제 기록에서

    private func makeStore(_ env: TestEnv, today: Day) -> AppStore {
        let clock = TestClock(today)
        let store = AppStore(container: env.container, clock: { clock.today })
        store.start()
        return store
    }

    @Test func newUsersNeverSeeIt() throws {
        let env = try TestEnv()
        // 루틴을 만들고 한 번도 완료하지 않은 채 나흘이 지났다.
        _ = try env.addRoutines(2, today: monday)
        let store = makeStore(env, today: friday)
        #expect(store.restartPrompt(dismissedDay: nil) == nil)
        // 루틴이 아예 없는 사람도 마찬가지다.
        let empty = makeStore(try TestEnv(), today: friday)
        #expect(empty.restartPrompt(dismissedDay: nil) == nil)
    }

    @Test func returningUserSeesItUntilTheyCompleteOrSkipToday() throws {
        let env = try TestEnv()
        _ = try env.addRoutines(2, today: monday)
        try env.log(monday, done: 1)
        let store = makeStore(env, today: friday)
        // 화·수·목 사흘을 하지 않았다.
        #expect(store.restartPrompt(dismissedDay: nil) == RestartPrompt(missedDays: 3, lastActiveDay: monday))
        #expect(store.restartPrompt(dismissedDay: friday) == nil)

        let first = try #require(store.checkSections.flatMap(\.checks).first).id
        // 건너뛰기로 정해도 사라지고, 되돌리면 다시 나온다.
        store.setSkipped(routineID: first, true)
        #expect(store.restartPrompt(dismissedDay: nil) == nil)
        store.setSkipped(routineID: first, false)
        #expect(store.restartPrompt(dismissedDay: nil) != nil)
        // 하나를 완료하면 사라진다.
        store.setDone(routineID: first, true)
        #expect(store.restartPrompt(dismissedDay: nil) == nil)
    }

    @Test func explicitlySkippedDaysBreakTheGap() throws {
        let env = try TestEnv()
        _ = try env.addRoutines(1, today: monday)
        try env.log(monday, done: 1)
        // 수요일에 건너뛰기로 표시했다.
        let wednesday = day("2026-10-07")
        let midweek = makeStore(env, today: wednesday)
        let id = try #require(midweek.checkSections.flatMap(\.checks).first).id
        midweek.setSkipped(routineID: id, true)
        midweek.flush()
        // 금요일: 화(안 함)·수(건너뜀)·목(안 함). 건너뛴 날에서 끊겨 하루만 남는다.
        let store = makeStore(env, today: friday)
        #expect(store.restartPrompt(dismissedDay: nil) == nil)
    }

    @Test func longAbsenceStillCountsAsAReturningUser() throws {
        let env = try TestEnv()
        _ = try env.addRoutines(1, today: monday)
        try env.log(monday, done: 1)
        // 마지막으로 완료한 날이 통계의 최근 30일 밖이다.
        let later = monday.adding(days: 45)
        let store = makeStore(env, today: later)
        #expect(!store.stats.trend.contains { $0.done > 0 })
        let prompt = try #require(store.restartPrompt(dismissedDay: nil))
        #expect(prompt.missedDays >= RestartPromptPolicy.minimumMissedDays && prompt.lastActiveDay == nil)
    }

    @Test func focusingTheRoutineCardOnlyRaisesASignal() throws {
        let store = makeStore(try TestEnv(), today: friday)
        let before = store.routineCardFocusToken
        store.focusRoutineCard()
        #expect(store.routineCardFocusToken == before + 1)
    }
}
