import Testing
@testable import Daylog

/// 17-4. 달성률
struct AchievementTests {
    @Test(arguments: [
        (4, 5, 80),
        (5, 5, 100),
        (3, 5, 60),
        (1, 1, 100),
        (0, 1, 0),
        (1, 3, 33),
        (2, 3, 67),
    ])
    func percent(done: Int, total: Int, expected: Int) {
        #expect(Achievement.percent(done: done, total: total) == expected)
    }

    @Test func noRoutinesHasNoRate() {
        #expect(Achievement.percent(done: 0, total: 0) == nil)
        #expect(Achievement.ratio(done: 0, total: 0) == nil)
    }

    @Test func outcomeUsesTheSameFunction() {
        let recorded = DayOutcome(day: monday, status: .recorded, done: 4, total: 5)
        #expect(recorded.percent == 80)
        #expect(recorded.isAchieved(threshold: 80))
        #expect(!recorded.isAchieved(threshold: 81))

        #expect(DayOutcome(day: monday, status: .unrecorded, done: 0, total: 5).percent == 0)
        #expect(DayOutcome(day: monday, status: .rest, done: 0, total: 0).percent == nil)
        #expect(DayOutcome(day: monday, status: .preStart, done: 0, total: 0).percent == nil)
        #expect(DayOutcome(day: monday, status: .future, done: 0, total: 0).percent == nil)
    }
}
