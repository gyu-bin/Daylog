import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 이번 주의 성장: 실천한 날 세기, 주간 목표, 카드 배치.
@MainActor
struct WeeklyGrowthTests {
    // 2026-10-05(월) ~ 10-11(일) 주. 수요일은 10-07.
    private let wednesday = day("2026-10-07")

    private func outcome(_ key: String, _ status: DayStatus, done: Int = 0, total: Int = 0) -> DayOutcome {
        DayOutcome(day: day(key), status: status, done: done, total: total)
    }

    private func growth(
        _ outcomes: [DayOutcome], upcoming: [String] = [], today: Day? = nil, weekStart: WeekStart = .monday,
        goal: Int? = nil, recommended: Int = 5, hasRoutines: Bool = true
    ) -> WeeklyGrowth {
        WeeklyGrowthCalculator.make(
            outcomes: outcomes, upcomingEligibleDays: upcoming.map(day), today: today ?? wednesday, weekStart: weekStart,
            chosenGoal: goal, recommendedGoal: recommended, hasRoutines: hasRoutines
        )
    }

    // MARK: - 실천한 날 세기

    @Test func aDayCountsOnceHoweverManyRoutinesWereDone() {
        let result = growth([
            outcome("2026-10-05", .recorded, done: 3, total: 3),
            outcome("2026-10-06", .recorded, done: 1, total: 4),
            outcome("2026-10-07", .unrecorded, done: 0, total: 4),
        ])
        #expect(result.practicedDays == 2)
        #expect(!result.practicedToday && result.isTodayEligible)
    }

    @Test func skippedVacationRestAndFutureDaysDoNotCount() {
        let result = growth([
            // 건너뛰기만 한 날: 완료가 없으므로 실천이 아니다.
            outcome("2026-10-05", .recorded, done: 0, total: 2),
            // 휴가와 예정된 루틴이 없던 날은 대상이 아니다.
            outcome("2026-10-06", .vacation),
            outcome("2026-10-07", .rest),
            // 미래는 세지 않는다(값이 들어 있어도).
            outcome("2026-10-08", .recorded, done: 2, total: 2),
            outcome("2026-10-09", .future),
        ])
        #expect(result.practicedDays == 0)
        #expect(!result.isTodayEligible)
        #expect(WeeklyGrowthCalculator.isPracticed(outcome("2026-10-05", .unrecorded, done: 1, total: 2)))
        #expect(!WeeklyGrowthCalculator.isPracticed(outcome("2026-10-05", .preStart)))
    }

    @Test func weekStartDecidesWhichDaysBelongToThisWeek() {
        let outcomes = [
            outcome("2026-10-03", .recorded, done: 1, total: 1), // 토
            outcome("2026-10-04", .recorded, done: 1, total: 1), // 일
            outcome("2026-10-05", .recorded, done: 1, total: 1), // 월
            outcome("2026-10-07", .recorded, done: 1, total: 1), // 수(오늘)
        ]
        // 월요일 시작: 월·수.
        #expect(growth(outcomes, weekStart: .monday).practicedDays == 2)
        // 일요일 시작: 일·월·수.
        #expect(growth(outcomes, weekStart: .sunday).practicedDays == 3)
        // 일요일 시작이면 일요일이 새 주의 첫날이다.
        #expect(growth(outcomes, today: sunday, weekStart: .sunday).practicedDays == 0)
    }

    // MARK: - 목표와 문구

    @Test func goalComesFromTheUserOrTheRecommendation() {
        #expect(growth([], goal: nil, recommended: 4).goal == 4)
        #expect(growth([], goal: nil, recommended: 4).usesRecommendedGoal)
        #expect(growth([], goal: 7, recommended: 4).goal == 7)
        #expect(!growth([], goal: 7, recommended: 4).usesRecommendedGoal)
        // 범위를 벗어난 값은 1~7로 맞춘다.
        #expect(growth([], goal: 0).goal == 1)
        #expect(growth([], goal: 12).goal == 7)
    }

    @Test func recommendationFollowsTheRoutineSchedule() {
        #expect(WeeklyGrowthCalculator.recommendedGoal(routineWeekdays: []) == 5)
        #expect(WeeklyGrowthCalculator.recommendedGoal(routineWeekdays: [[1, 3, 5]]) == 3)
        #expect(WeeklyGrowthCalculator.recommendedGoal(routineWeekdays: [[1, 3], [3, 6]]) == 3)
        // 매일 하는 루틴이어도 주 5일까지만 권한다.
        #expect(WeeklyGrowthCalculator.recommendedGoal(routineWeekdays: [Weekdays.all]) == 5)
        #expect(WeeklyGrowthCalculator.recommendedGoal(routineWeekdays: [[6]]) == 1)
    }

    @Test func messagesSayOnlyWhatTheRecordsShow() {
        let done = { (key: String) in self.outcome(key, .recorded, done: 1, total: 2) }
        let pending = { (key: String) in self.outcome(key, .unrecorded, done: 0, total: 2) }

        // 3 / 5일, 남은 날로 채울 수 있다.
        let onTrack = growth(
            [done("2026-10-05"), done("2026-10-06"), pending("2026-10-07")],
            upcoming: ["2026-10-08", "2026-10-09", "2026-10-10", "2026-10-11"], goal: 5
        )
        #expect(onTrack.practicedDays == 2 && onTrack.remainingToGoal == 3 && onTrack.remainingChances == 5)
        #expect(onTrack.headline == "이번 주 목표까지 3일 남았어요.")
        #expect(onTrack.detail == "오늘도 작은 습관 하나부터 시작해 보세요.")
        #expect(onTrack.filledDots == 2)

        // 오늘 이미 실천했으면 오늘은 남은 기회에서 빠진다.
        let today = growth([done("2026-10-05"), done("2026-10-07")], upcoming: ["2026-10-08", "2026-10-09"], goal: 4)
        #expect(today.practicedToday && today.remainingChances == 2)
        #expect(today.headline == "이번 주 목표까지 2일 남았어요.")
        #expect(today.detail == "오늘도 한 걸음 나아갔어요.")

        // 목표 달성. 목표보다 많이 해도 칸은 목표만큼만 채운다.
        let reached = growth([done("2026-10-05"), done("2026-10-06"), done("2026-10-07")], goal: 2)
        #expect(reached.isGoalReached && reached.filledDots == 2)
        #expect(reached.headline == "이번 주 목표를 달성했어요!")

        // 남은 날로는 목표에 닿지 않으면 닿을 수 있는 것처럼 말하지 않는다.
        let behind = growth([done("2026-10-05"), pending("2026-10-10")], upcoming: ["2026-10-11"], today: saturday, goal: 5)
        #expect(behind.remainingToGoal == 4 && behind.remainingChances == 2)
        #expect(behind.headline == "이번 주에 1일 실천했어요.")
        let none = growth([pending("2026-10-11")], today: sunday, goal: 5)
        #expect(none.headline == "이번 주는 아직 실천한 날이 없어요.")

        // 루틴이 없으면 숫자를 꾸며 내지 않는다.
        let empty = growth([], hasRoutines: false)
        #expect(empty.practicedDays == 0)
        #expect(empty.headline == "첫 루틴을 만들면 이번 주 실천이 여기에 쌓여요.")
    }

    // MARK: - 실제 기록에서

    private func makeStore(_ env: TestEnv, today: Day) -> AppStore {
        let clock = TestClock(today)
        let store = AppStore(container: env.container, clock: { clock.today })
        store.start()
        return store
    }

    private func id(_ index: Int, in store: AppStore) throws -> UUID {
        try #require(store.checkSections.flatMap(\.checks).dropFirst(index).first).id
    }

    @Test func completingCancellingAndSkippingUpdateTheCountRightAway() throws {
        let env = try TestEnv()
        _ = try env.addRoutines(2, today: monday)
        try env.log(monday, done: 2)
        let store = makeStore(env, today: wednesday)
        func count() -> Int { store.weeklyGrowth(weekStart: .monday, chosenGoal: 5).practicedDays }
        // 월요일 하루. 화요일은 열지 않았고 오늘은 아직이다.
        #expect(count() == 1)
        let first = try id(0, in: store), second = try id(1, in: store)
        store.setDone(routineID: first, true)
        #expect(count() == 2)
        // 같은 날 하나 더 해도 하루다.
        store.setDone(routineID: second, true)
        #expect(count() == 2)
        // 둘 다 취소하면 오늘은 다시 빠진다.
        store.setDone(routineID: first, false)
        store.setDone(routineID: second, false)
        #expect(count() == 1)
        // 건너뛰기는 완료가 아니다.
        store.setSkipped(routineID: first, true)
        #expect(count() == 1)
        #expect(store.weeklyGrowth(weekStart: .monday, chosenGoal: 5).isTodayEligible)
    }

    @Test func vacationDaysAndLaterScheduleChangesAreRespected() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(1, today: monday)
        try env.log(monday, done: 1)
        try env.log(day("2026-10-06"), done: 1)
        let store = makeStore(env, today: wednesday)
        #expect(store.weeklyGrowth(weekStart: .monday, chosenGoal: nil).practicedDays == 2)

        // 오늘부터 주말에만 하도록 바꿔도 지난 날의 실천은 그대로다(그날의 기록이 기준).
        let routine = try #require(store.routines.first { $0.id == routines[0].id })
        #expect(store.updateRoutine(routine, weekdays: Weekdays.weekend))
        let changed = store.weeklyGrowth(weekStart: .monday, chosenGoal: nil)
        #expect(changed.practicedDays == 2)
        // 오늘(수)은 이제 예정된 루틴이 없는 날이고, 남은 기회는 토·일이다. 추천 목표도 일정(주말 2일)을 따른다.
        #expect(!changed.isTodayEligible && changed.remainingChances == 2)
        #expect(changed.goal == 2 && changed.usesRecommendedGoal)

        // 월요일을 휴가로 하면 그날은 대상에서 빠진다(기록은 지워지지 않는다).
        #expect(store.saveVacation(start: monday, end: monday))
        #expect(store.weeklyGrowth(weekStart: .monday, chosenGoal: nil).practicedDays == 1)
        #expect(try env.records.record(on: monday)?.checkList.contains { $0.isDone } == true)
    }

    // MARK: - 목표 저장

    @Test func weeklyGoalIsStoredOnThisDeviceAndSurvivesRelaunch() {
        let defaults = testDefaults()
        let preferences = DevicePreferences(defaults: defaults)
        #expect(preferences.weeklyGoal == nil)
        preferences.setWeeklyGoal(3)
        #expect(DevicePreferences(defaults: defaults).weeklyGoal == 3)
        // 범위 밖은 1~7로 맞춘다.
        preferences.setWeeklyGoal(9)
        #expect(preferences.weeklyGoal == 7 && DevicePreferences(defaults: defaults).weeklyGoal == 7)
        // 추천값으로 되돌리면 저장값이 없어진다.
        preferences.setWeeklyGoal(nil)
        #expect(DevicePreferences(defaults: defaults).weeklyGoal == nil)
        // 손상된 저장값은 쓰지 않는다.
        defaults.set(40, forKey: DevicePreferences.weeklyGoalKey)
        #expect(DevicePreferences(defaults: defaults).weeklyGoal == nil)
    }

    // MARK: - 카드 배치

    /// 이 카드가 생기기 전에 저장된 배치(카드 11개).
    private func legacyDefaults(order: [String], hidden: [String], left: [String], customized: Bool) -> UserDefaults {
        let defaults = testDefaults()
        defaults.set(order, forKey: DevicePreferences.orderKey)
        defaults.set(hidden, forKey: DevicePreferences.hiddenKey)
        defaults.set(left, forKey: DevicePreferences.leftKey)
        defaults.set(DevicePreferences.layoutVersion, forKey: DevicePreferences.layoutVersionKey)
        defaults.set(customized, forKey: DevicePreferences.customizedKey)
        return defaults
    }

    private let legacyOrder = [
        "summary", "nextRoutine", "vacation", "routines", "meals", "achievement", "recentDays", "tomorrow",
        "calendar", "trend", "routineRates",
    ]

    @Test func newCardStartsWhereItDoesNotPushTheRoutines() {
        // Mac·iPad: 오른쪽 열의 맨 위. 왼쪽 열은 다음 루틴·휴가·오늘 루틴, 그 아래 새싹이 성장·주간 회고(오른쪽 열만 길어지지 않게).
        let wide = DevicePreferences(defaults: testDefaults(), isPhone: false)
        let layout = wide.layout(of: wide.visibleCards)
        #expect(layout.left == [.nextRoutine, .vacation, .routines, .saessagiGrowth])
        #expect(layout.right.first == .weeklyGrowth)
        // iPhone: 오늘의 달성 현황 바로 아래.
        let phone = DevicePreferences(defaults: testDefaults(), isPhone: true)
        #expect(phone.visibleCards.prefix(3) == [.achievement, .weeklyGrowth, .nextRoutine])
        #expect(DashboardCard.weeklyGrowth.rawValue == "weeklyGrowth" && DashboardCard(rawValue: "weeklyGrowth") == .weeklyGrowth)
    }

    @Test func untouchedLayoutGetsTheNewCardInItsDefaultPlace() {
        let defaults = legacyDefaults(
            order: legacyOrder, hidden: ["calendar", "routineRates", "summary", "trend"],
            left: ["nextRoutine", "routines", "vacation"], customized: false
        )
        let preferences = DevicePreferences(defaults: defaults, isPhone: false)
        #expect(!preferences.isLayoutCustomized)
        #expect(preferences.cardOrder == DashboardCard.defaultOrder)
        #expect(preferences.layout(of: preferences.visibleCards).right == [
            .weeklyGrowth, .meals, .achievement, .recentDays, .tomorrow,
        ])
        // 바꾼 적 없는 배치는 새 기본값을 따라 성장 카드가 왼쪽 열로 간다.
        #expect(preferences.layout(of: preferences.visibleCards).left == [.nextRoutine, .vacation, .routines, .saessagiGrowth])
        // 주간 회고는 처음에 숨겨 두고, 켜면 왼쪽 열에 나온다.
        #expect(preferences.hiddenCards.contains(.weeklyReview) && preferences.column(of: .weeklyReview) == .left)
    }

    @Test func customizedLayoutIsKeptAndTheNewCardGoesLast() {
        // 사용자가 식사를 맨 위로 올리고 최근 7일을 숨겨 둔 배치.
        let order = ["meals"] + legacyOrder.filter { $0 != "meals" }
        let defaults = legacyDefaults(
            order: order, hidden: ["recentDays", "summary"], left: ["meals", "routines"], customized: true
        )
        let preferences = DevicePreferences(defaults: defaults, isPhone: false)
        #expect(preferences.isLayoutCustomized)
        // 원래 카드의 순서·숨김·열은 그대로이고, 새 카드는 맨 뒤(오른쪽 열)에 보이는 채로 붙는다.
        // 나중에 생긴 카드(이번 주의 성장, 새싹이 성장, 주간 회고)가 내장 순서대로 맨 뒤에 붙는다.
        #expect(preferences.cardOrder.dropLast(3).map(\.rawValue) == order)
        #expect(preferences.cardOrder.suffix(3) == [.weeklyGrowth, .saessagiGrowth, .weeklyReview])
        // 원래 숨긴 카드는 그대로이고, 본 적 없는 주간 회고는 기본값(숨김)으로 들어온다. 이번 주의 성장·새싹이 성장은 보인다.
        #expect(preferences.hiddenCards == [.recentDays, .summary, .weeklyReview])
        #expect(preferences.visibleCards.contains(.saessagiGrowth))
        // 다시 켜면 그 선택이 남는다(다음 실행에서 다시 숨기지 않는다).
        preferences.setVisible(true, card: .weeklyReview)
        #expect(DevicePreferences(defaults: defaults, isPhone: false).visibleCards.contains(.weeklyReview))
        preferences.setVisible(false, card: .weeklyReview)
        #expect(preferences.leftCards == [.meals, .routines])
        // 사용자가 바꾼 배치의 열은 새 기본값으로 덮지 않는다(새 카드는 오른쪽 열 맨 뒤).
        #expect(preferences.column(of: .saessagiGrowth) == .right && preferences.column(of: .weeklyReview) == .right)
        #expect(preferences.visibleCards.contains(.weeklyGrowth) && preferences.column(of: .weeklyGrowth) == .right)
        // 숨기고, 옮기고, 다시 켜도 유지된다.
        preferences.setVisible(false, card: .weeklyGrowth)
        preferences.place(.weeklyGrowth, before: .routines)
        let relaunched = DevicePreferences(defaults: defaults, isPhone: false)
        #expect(relaunched.hiddenCards.contains(.weeklyGrowth) && relaunched.column(of: .weeklyGrowth) == .left)
        #expect(relaunched.cardOrder.firstIndex(of: .weeklyGrowth)! < relaunched.cardOrder.firstIndex(of: .routines)!)
        // 기본 배치 복원은 새 카드를 기본 자리로 돌려 놓는다.
        relaunched.restoreDashboard()
        #expect(relaunched.layout(of: relaunched.visibleCards).right.first == .weeklyGrowth)
    }

    @Test func publishedRemoteOrderWithoutTheCardStillPlacesItAfterProgress() {
        // 지금 게시돼 있는 설정의 순서(카드 11개).
        let published = [
            "achievement", "nextRoutine", "routines", "meals", "recentDays", "tomorrow", "vacation",
            "summary", "calendar", "trend", "routineRates",
        ]
        let preferences = DevicePreferences(defaults: testDefaults(), isPhone: true)
        preferences.applyRemoteDefaults(order: published, hidden: ["summary", "calendar", "trend", "routineRates"])
        // 게시된 설정이 모르는 주간 회고는 앱의 기본값대로 숨긴다.
        #expect(preferences.visibleCards == [
            .achievement, .weeklyGrowth, .nextRoutine, .routines, .saessagiGrowth, .meals, .recentDays, .tomorrow, .vacation
        ])
        // 설정이 이 카드의 자리를 직접 정하면 그대로 따른다.
        preferences.applyRemoteDefaults(order: published + ["weeklyGrowth"], hidden: [])
        #expect(preferences.cardOrder.last == .weeklyGrowth)
        // 사용자가 배치를 바꾼 뒤에는 원격 설정이 건드리지 않는다.
        preferences.setVisible(false, card: .weeklyGrowth)
        preferences.applyRemoteDefaults(order: published, hidden: [])
        #expect(preferences.hiddenCards.contains(.weeklyGrowth))
    }
}

/// 카드 표시 설정(Phase 7-H2): 이번 주의 성장·주간 회고를 끄고 켜도 다음 실행까지 남고, 기록 계산에는 영향이 없다.
@MainActor
struct DashboardCardVisibilityTests {
    @Test func weeklyCardsToggleAndSurviveRelaunch() {
        let defaults = testDefaults()
        let preferences = DevicePreferences(defaults: defaults, isPhone: true)
        // 새 사용자: 이번 주의 성장·새싹이 성장은 켜져 있고 주간 회고는 꺼져 있다.
        #expect(preferences.visibleCards.contains(.weeklyGrowth) && preferences.visibleCards.contains(.saessagiGrowth))
        #expect(!preferences.visibleCards.contains(.weeklyReview) && preferences.hiddenChoices.contains(.weeklyReview))

        preferences.setVisible(false, card: .weeklyGrowth)
        #expect(!preferences.visibleCards.contains(.weeklyGrowth))
        #expect(!DevicePreferences(defaults: defaults, isPhone: true).visibleCards.contains(.weeklyGrowth))
        preferences.setVisible(true, card: .weeklyGrowth)
        #expect(DevicePreferences(defaults: defaults, isPhone: true).visibleCards.contains(.weeklyGrowth))

        // 주간 회고: 끔 → 켬 → 끔, 순서를 바꾼 뒤 다시 켜도 그대로.
        preferences.setVisible(true, card: .weeklyReview)
        preferences.move(.weeklyReview, by: -1)
        let order = preferences.cardOrder
        var relaunched = DevicePreferences(defaults: defaults, isPhone: true)
        #expect(relaunched.visibleCards.contains(.weeklyReview) && relaunched.cardOrder == order)
        relaunched.setVisible(false, card: .weeklyReview)
        relaunched = DevicePreferences(defaults: defaults, isPhone: true)
        #expect(!relaunched.visibleCards.contains(.weeklyReview) && relaunched.cardOrder == order)

        // 기본 배치 복원: 기본 순서, 주간 회고는 다시 숨김.
        relaunched.restoreDashboard()
        #expect(relaunched.cardOrder == DashboardCard.defaultOrder(phone: true))
        #expect(relaunched.hiddenCards == DashboardCard.defaultHidden)
    }

    @Test func hidingCardsDoesNotChangeRecordsOrCalculations() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: monday)
        try env.log(monday, done: 2)
        let clock = TestClock(day("2026-10-13"))
        let store = AppStore(container: env.container, clock: { clock.today })
        store.start()
        let before = (store.growth.xp, store.weeklyReview(weekStart: .monday), store.stats.lastPracticedDay)
        let preferences = DevicePreferences(defaults: testDefaults(), isPhone: true)
        for card in [DashboardCard.weeklyGrowth, .saessagiGrowth, .weeklyReview, .achievement, .meals] {
            preferences.setVisible(false, card: card)
        }
        store.setDone(routineID: routines[0].id, true)
        // 카드를 숨겨도 기록과 XP·회고·마지막 완료일 계산은 그대로 돈다.
        #expect(store.growth.xp == before.0 + 10)
        #expect(store.weeklyReview(weekStart: .monday) == before.1)
        #expect(store.stats.lastPracticedDay == day("2026-10-13") && before.2 == monday)
    }
}
