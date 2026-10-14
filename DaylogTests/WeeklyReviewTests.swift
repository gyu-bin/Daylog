import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 새싹이의 주간 회고: 회고하는 주, 통계·XP와 같은 셈, 건너뛰기·휴가·중복, 앞 주와의 비교와 문구.
@MainActor
struct WeeklyReviewTests {
    private let today = day("2026-10-14")   // 수요일

    private func outcome(_ key: String, _ status: DayStatus = .recorded, done: Int, total: Int) -> DayOutcome {
        DayOutcome(day: day(key), status: status, done: done, total: total)
    }

    private func week(_ start: String) -> ClosedRange<Day> { day(start)...day(start).adding(days: 6) }

    // MARK: - 회고하는 주

    @Test func reviewsTheLastFinishedWeekNotTheCurrentOne() {
        #expect(WeeklyReviewCalculator.reviewedWeek(today: today, weekStart: .monday) == week("2026-10-05"))
        #expect(WeeklyReviewCalculator.reviewedWeek(today: today, weekStart: .sunday) == week("2026-10-04"))
        // 주의 첫날이 오늘이어도 진행 중인 이번 주가 아니라 끝난 지난주다.
        #expect(WeeklyReviewCalculator.reviewedWeek(today: day("2026-10-12"), weekStart: .monday) == week("2026-10-05"))
        #expect(WeeklyReviewCalculator.reviewedWeek(today: day("2026-10-11"), weekStart: .monday) == week("2026-09-28"))
        // 해가 바뀌는 주.
        #expect(WeeklyReviewCalculator.reviewedWeek(today: day("2027-01-02"), weekStart: .monday) == week("2026-12-21"))
        #expect(WeeklyReviewCalculator.reviewedWeek(today: day("2027-01-05"), weekStart: .monday) == week("2026-12-28"))
    }

    // MARK: - 실제 기록에서

    @Test func countsLikeStatsAndXPWithSkipsVacationsAndDuplicates() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: day("2026-09-28"))
        // 앞 주: 이틀 하나씩.
        try env.log(day("2026-09-28"), done: 1)
        try env.log(day("2026-09-29"), done: 1)
        // 회고하는 주.
        try env.log(day("2026-10-05"), done: 2)
        try env.log(day("2026-10-06"), done: 2)
        try env.log(day("2026-10-07"), done: 1)
        try env.log(day("2026-10-09"), done: 2)   // 휴가로 바꾼다
        let saturday = try env.log(day("2026-10-10"), done: 2)
        // 동기화로 같은 루틴의 완료 체크가 하나 더 들어왔다.
        let duplicate = DayCheck(routine: routines[0])
        duplicate.isDone = true
        saturday.attach(duplicate)
        try env.context.save()

        let clock = TestClock(today)
        let store = AppStore(container: env.container, clock: { clock.today })
        store.start()
        // 목요일은 둘 다 건너뛰었다(완료가 아니다). 금요일은 휴가다.
        store.setSkipped(routineID: routines[0].id, on: day("2026-10-08"), true)
        store.setSkipped(routineID: routines[1].id, on: day("2026-10-08"), true)
        #expect(store.saveVacation(start: day("2026-10-09"), end: day("2026-10-09")))

        let review = store.weeklyReview(weekStart: .monday)
        #expect(review.start == day("2026-10-05") && review.end == day("2026-10-11") && review.days.count == 7)
        #expect(review.completed == 7)
        #expect(review.practicedDays == 4)
        // XP: 월 40, 화 40, 수 10, 목 0(건너뛰기), 금 0(휴가), 토 40(중복은 한 번), 일 0.
        #expect(review.xp == 130)
        #expect(review.topRoutine == WeeklyReview.TopRoutine(title: "루틴 1", days: 4))
        #expect(review.previousCompleted == 2 && review.change == 5)
        #expect(review.mood == .grew && review.isCelebration)
        #expect(review.changeNote == "지난주보다 5개 더 실천했어요!")

        // 통계·XP와 같은 값이다.
        let outcomes = try env.stats.outcomes(from: review.start, to: review.end, today: today)
        #expect(review.completed == outcomes.filter(WeeklyGrowthCalculator.isEligible).reduce(0) { $0 + $1.done })
        #expect(review.xp == GrowthCalculator.totalXP(outcomes))
        #expect(store.growth.xp == 20 + review.xp)   // 앞 주 10 + 10

        // 지난주의 기록을 고치면 회고도 바로 따라온다.
        store.setDone(routineID: routines[1].id, on: day("2026-10-07"), true)
        let updated = store.weeklyReview(weekStart: .monday)
        #expect(updated.completed == 8 && updated.xp == 160)
    }

    @Test func aWeekWithoutRecordsAndAFirstWeekAreToldAsTheyAre() throws {
        let env = try TestEnv()
        _ = try env.addRoutines(1, today: day("2026-10-05"))
        let clock = TestClock(today)
        let store = AppStore(container: env.container, clock: { clock.today })
        store.start()
        // 루틴은 있었지만 하나도 완료하지 않았다. 앞 주는 시작 전이라 비교하지 않는다.
        let review = store.weeklyReview(weekStart: .monday)
        #expect(review.completed == 0 && review.xp == 0 && review.topRoutine == nil && review.previousCompleted == nil)
        #expect(review.mood == .empty && !review.hasRecords && review.changeNote == nil)
        #expect(review.headline == "지난주 기록은 없지만, 이번 주부터 시작해 볼까요?")
    }

    // MARK: - 문구

    @Test func moodsFollowTheNumbersWithoutBlame() {
        let previous = week("2026-09-28"), current = week("2026-10-05")
        func review(previous done: [Int], current now: [Int], vacation: Bool = false) -> WeeklyReview {
            let before = done.enumerated().map { outcome(previous.lowerBound.adding(days: $0.offset).key, done: $0.element, total: 3) }
            let after = now.enumerated().map {
                outcome(current.lowerBound.adding(days: $0.offset).key, vacation ? .vacation : .recorded, done: $0.element, total: 3)
            }
            return WeeklyReviewCalculator.make(week: current, outcomes: before + after, rates: [])
        }
        // 늘었다.
        #expect(review(previous: [1, 1, 0, 0, 0, 0, 0], current: [3, 3, 2, 1, 0, 0, 0]).mood == .grew)
        // 비슷하다(한 개 차이).
        let steady = review(previous: [2, 2, 2, 0, 0, 0, 0], current: [2, 2, 1, 0, 0, 0, 0])
        #expect(steady.mood == .steady && steady.headline == "꾸준함을 이어가고 있어요!")
        #expect(steady.changeNote == "지난주(6개)와 비슷하게 실천했어요.")
        #expect(review(previous: [2, 2, 2, 0, 0, 0, 0], current: [2, 2, 2, 0, 0, 0, 0]).changeNote == "지난주와 같은 6개를 실천했어요.")
        // 줄었다: 탓하지 않는다.
        let eased = review(previous: [3, 3, 3, 3, 3, 0, 0], current: [1, 1, 0, 0, 0, 0, 0])
        #expect(eased.mood == .eased && eased.headline == "조금 쉬어가도 괜찮아요. 다시 함께해요!")
        #expect(eased.changeNote == "지난주보다 13개 적었어요. 이번 주에 천천히 이어 가요.")
        #expect(!eased.isCelebration)
        for text in [eased.headline, eased.changeNote ?? "", eased.cheer] {
            #expect(!text.contains("실패") && !text.contains("게으"))
        }
        // 한 주 내내 휴가.
        #expect(review(previous: [1, 0, 0, 0, 0, 0, 0], current: [0, 0, 0, 0, 0, 0, 0], vacation: true).mood == .vacation)
        // 5일 이상 실천하면 줄었어도 작게 축하한다.
        #expect(review(previous: [3, 3, 3, 3, 3, 3, 3], current: [1, 1, 1, 1, 1, 0, 0]).isCelebration)
        // 가장 꾸준한 루틴: 같은 일수면 앞의 것(달성률 순).
        let rates = [
            RoutineRate(routineID: UUID(), title: "물", isArchived: false, done: 3, scheduled: 3),
            RoutineRate(routineID: UUID(), title: "독서", isArchived: false, done: 3, scheduled: 7),
            RoutineRate(routineID: UUID(), title: "산책", isArchived: false, done: 1, scheduled: 7),
        ]
        let top = WeeklyReviewCalculator.make(week: current, outcomes: [], rates: rates).topRoutine
        #expect(top == WeeklyReview.TopRoutine(title: "물", days: 3))
    }
}
