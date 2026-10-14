import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 휴가 화면: 며칠째인지, 휴가 중의 성장 카드 문구.
@MainActor
struct VacationRestTests {
    private let wednesday = day("2026-10-07")

    @Test func countsTheDayWithinThePeriod() throws {
        let period = VacationPeriod(start: monday, end: day("2026-10-09"))
        let info = try #require(VacationRestInfo.make(periods: [period], today: wednesday))
        #expect(info.dayNumber == 3 && info.totalDays == 5)
        #expect(info.title == "휴가 3일째 / 총 5일")
        #expect(info.periodTitle == "10월 5일 ~ 10월 9일")
        #expect(abs(info.progress - 0.6) < 1e-9)
        // 첫날과 마지막 날.
        #expect(VacationRestInfo.make(periods: [period], today: monday)?.dayNumber == 1)
        #expect(VacationRestInfo.make(periods: [period], today: day("2026-10-09"))?.progress == 1)
        // 하루짜리 휴가.
        let single = try #require(VacationRestInfo.make(periods: [VacationPeriod(start: wednesday, end: wednesday)], today: wednesday))
        #expect(single.title == "휴가 1일째 / 총 1일" && single.periodTitle == "10월 7일")
    }

    @Test func noInfoOutsideAVacationAndOverlapsUseTheEarliestStart() throws {
        let period = VacationPeriod(start: monday, end: wednesday)
        #expect(VacationRestInfo.make(periods: [period], today: day("2026-10-08")) == nil)
        #expect(VacationRestInfo.make(periods: [period], today: day("2026-10-04")) == nil)
        #expect(VacationRestInfo.make(periods: [], today: wednesday) == nil)
        let later = VacationPeriod(start: day("2026-10-06"), end: saturday)
        let info = try #require(VacationRestInfo.make(periods: [later, period], today: wednesday))
        #expect(info.start == monday && info.dayNumber == 3 && info.totalDays == 3)
    }

    @Test func growthCardDoesNotPushTheGoalDuringAVacation() throws {
        let env = try TestEnv()
        _ = try env.addRoutines(1, today: monday)
        try env.log(monday, done: 1)
        let clock = TestClock(wednesday)
        let store = AppStore(container: env.container, clock: { clock.today })
        store.start()
        // 평소에는 목표까지 남은 날을 말한다.
        let before = store.weeklyGrowth(weekStart: .monday, chosenGoal: 5)
        #expect(!before.isOnVacation && before.headline.contains("목표까지"))
        // 휴가 중에는 실천한 날만 말하고 재촉하지 않는다.
        #expect(store.saveVacation(start: wednesday, end: day("2026-10-09")))
        let during = store.weeklyGrowth(weekStart: .monday, chosenGoal: 5)
        #expect(during.isOnVacation)
        #expect(during.headline == "이번 주에 1일 실천했어요." && !during.headline.contains("목표까지"))
        #expect(during.detail.contains("휴가"))
        // 이미 달성한 목표는 휴가 중에도 그대로 알려 준다.
        #expect(store.weeklyGrowth(weekStart: .monday, chosenGoal: 1).headline == "이번 주 목표를 달성했어요!")
    }
}
