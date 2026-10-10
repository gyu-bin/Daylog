import Foundation
import SwiftData
import Testing
@testable import Daylog

/// v1.3.1: 통계 기간 필터와 활동 히트맵
@MainActor
struct PeriodStatsTests {
    /// 100일 전부터 매일 루틴 2개. 5일마다 미기록, 나머지는 번갈아 100% / 50%.
    private func seeded() throws -> (TestEnv, Day) {
        let env = try TestEnv()
        let today = saturday
        let start = today.adding(days: -99)
        try env.addRoutines(2, today: start)
        for offset in 0..<100 where offset % 5 != 4 {
            try env.log(start.adding(days: offset), done: offset % 2 == 0 ? 2 : 1)
        }
        return (env, today)
    }

    @Test func eachPeriodCoversItsOwnRange() throws {
        let (env, today) = try seeded()
        func stats(_ period: StatsPeriod) throws -> PeriodStats { try env.stats.period(period, today: today) }

        #expect(try stats(.week).outcomes.count == 7)
        #expect(try stats(.month).outcomes.count == 30)
        #expect(try stats(.quarter).outcomes.count == 90)
        #expect(try stats(.all).outcomes.count == 100) // 통계 시작일부터
        #expect(try stats(.all).outcomes.first?.day == today.adding(days: -99))
        #expect(try stats(.week).outcomes.last?.day == today)

        // 미기록일은 0%로 평균에 들어가고, 기준(80%) 달성일은 100%인 날만 센다.
        let week = try stats(.week)
        #expect(week.outcomes.map(\.percent) == [50, 0, 50, 100, 50, 100, 0])
        #expect(week.averagePercent == 50)
        #expect(week.achievedDays == 2)
        #expect(week.countedDays == 7)

        let all = try stats(.all)
        #expect(all.countedDays == 100)
        #expect(all.achievedDays == 40)
        #expect(all.averagePercent == 60) // (40×100 + 40×50 + 20×0) / 100
        // 대시보드의 고정 지표와 같은 계산을 쓴다.
        #expect(week.averagePercent == (try env.stats.dashboard(today: today).weeklyAverage))
        #expect(try stats(.month).routineRates == (try env.stats.dashboard(today: today).routineRates))
    }

    @Test func restDaysAndDaysBeforeStartAreExcluded() throws {
        let env = try TestEnv()
        let start = saturday.adding(days: -9) // 목요일
        try env.addRoutines(1, weekdays: Weekdays.workdays, today: start)
        for offset in 0..<10 { try env.log(start.adding(days: offset), done: 1) }

        let month = try env.stats.period(.month, today: saturday)
        #expect(month.outcomes.count == 30)
        #expect(month.outcomes.prefix(20).allSatisfy { $0.status == .preStart })
        #expect(month.outcomes.suffix(10).filter { $0.status == .rest }.count == 3) // 토·일·토
        #expect(month.countedDays == 7)
        #expect(month.achievedDays == 7)
        #expect(month.averagePercent == 100)
    }

    @Test func nothingBeforeTheFirstRoutine() throws {
        let env = try TestEnv()
        for period in StatsPeriod.allCases {
            let stats = try env.stats.period(period, today: saturday)
            #expect(!stats.hasStarted)
            #expect(stats.outcomes.isEmpty)
            #expect(stats.heatmap.isEmpty)
            #expect(stats.averagePercent == nil)
            #expect(stats.groupRates.isEmpty)
        }
    }

    @Test func groupAndRoutineRatesFollowThePeriod() throws {
        let env = try TestEnv()
        let start = saturday.adding(days: -39)
        let morning = try env.routines.addGroup(title: "아침", colorKey: "orange")
        let evening = try env.routines.addGroup(title: "저녁", colorKey: "purple")
        try env.routines.add(title: "물", group: morning, today: start)
        try env.routines.add(title: "일기", group: evening, today: start)
        for offset in 0..<40 {
            // "물"은 매일, "일기"는 최근 7일에만 완료.
            try env.log(start.adding(days: offset), done: offset >= 33 ? 2 : 1)
        }

        let week = try env.stats.period(.week, today: saturday)
        #expect(week.groupRates.map { "\($0.title) \($0.done)/\($0.scheduled)" } == ["아침 7/7", "저녁 7/7"])
        let all = try env.stats.period(.all, today: saturday)
        #expect(all.groupRates.map { "\($0.title) \($0.done)/\($0.scheduled)" } == ["아침 40/40", "저녁 7/40"]) // 달성률 내림차순
        #expect(all.routineRates.map { "\($0.title)|\($0.groupTitle)|\($0.percent)" } == ["물|아침|100", "일기|저녁|18"])
        #expect(all.routineRates.map(\.colorKey) == ["orange", "purple"])
    }

    @Test func heatmapCoversAtLeastNinetyDaysAndAtMostAYear() throws {
        let (env, today) = try seeded()
        #expect(try env.stats.period(.week, today: today).heatmap.count == 90)
        #expect(try env.stats.period(.quarter, today: today).heatmap.count == 90)
        #expect(try env.stats.period(.all, today: today).heatmap.count == 100)
        #expect(try env.stats.period(.all, today: today).heatmap.last?.day == today)

        // 2년 넘게 썼어도 히트맵은 최근 53주까지만.
        let long = try TestEnv()
        try long.addRoutines(1, today: today.adding(days: -800))
        let all = try long.stats.period(.all, today: today)
        #expect(all.outcomes.count == 801)
        #expect(all.heatmap.count == StatsService.heatmapMaximumDays)
    }

    @Test func heatLevelsAndGridLayout() throws {
        func level(_ status: DayStatus, _ done: Int, _ total: Int) -> HeatLevel {
            HeatLevel(DayOutcome(day: monday, status: status, done: done, total: total), threshold: 80)
        }
        #expect(level(.recorded, 4, 5) == .achieved)
        #expect(level(.recorded, 3, 5) == .mid)
        #expect(level(.recorded, 2, 5) == .low)
        #expect(level(.recorded, 0, 5) == .low)
        #expect(level(.unrecorded, 0, 5) == .unrecorded)
        #expect(level(.rest, 0, 0) == .rest)
        #expect(level(.preStart, 0, 0) == HeatLevel.none)
        #expect(level(.future, 0, 0) == HeatLevel.none)
        #expect(HeatLevel.unrecorded.label == "미기록")

        // 수요일부터 다음 주 화요일까지 7일 → 두 주(열)에 걸친다. 행은 월~일.
        let wednesday = monday.adding(days: 2)
        let outcomes = (0..<7).map { DayOutcome(day: wednesday.adding(days: $0), status: .recorded, done: 1, total: 1) }
        let weeks = HeatmapLayout.weeks(outcomes)
        #expect(weeks.count == 2)
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(weeks[0].map { $0 == nil } == [true, true, false, false, false, false, false])
        #expect(weeks[1].map { $0 == nil } == [false, false, true, true, true, true, true])
        #expect(weeks[0][2]?.day == wednesday)
        #expect(weeks[1][1]?.day == wednesday.adding(days: 6)) // 최근 날짜가 오른쪽 열
        #expect(HeatmapLayout.weeks([]).isEmpty)

        // 9월 28일(월)이 든 주와 10월 5일(월)이 든 주: 달이 바뀌는 열에만 머리글.
        let span = Day.range(from: day("2026-09-21"), to: day("2026-10-11"))
            .map { DayOutcome(day: $0, status: .rest, done: 0, total: 0) }
        #expect(HeatmapLayout.monthLabels(HeatmapLayout.weeks(span)) == ["9월", nil, "10월"])
    }

    /// 히트맵·차트·캘린더에서 날짜를 누르면 그 날짜의 기록으로 간다(미래는 안 된다).
    @Test func openingADayFromStatistics() throws {
        let (env, today) = try seeded()
        let store = AppStore(container: env.container, clock: { today })
        store.start()
        store.section = .statistics

        store.open(today.adding(days: -40))
        #expect(store.section == .dashboard)
        #expect(store.selectedDay == today.adding(days: -40))
        #expect(store.checks.count == 2)

        store.section = .statistics
        store.open(today.adding(days: 1))
        #expect(store.selectedDay == today.adding(days: -40))
        #expect(store.periodStats(.week).outcomes.count == 7)
    }

    @Test func mealCalendarMarksOnlyDaysWithMeals() throws {
        let env = try TestEnv()
        let store = AppStore(container: env.container, clock: { saturday }) // 2026-10-10
        store.start()
        store.setText("김치찌개", at: \.lunch)
        store.open(day("2026-10-03"))
        store.setText("메모만", at: \.mealMemo)
        store.open(day("2026-10-01"))
        store.setText("바나나", at: \.snack)
        store.open(day("2026-09-30"))
        store.setText("지난달", at: \.dinner)
        store.flush()

        #expect(store.mealDays(inMonth: saturday) == [day("2026-10-01"), saturday])
        #expect(store.mealDays(inMonth: day("2026-09-15")) == [day("2026-09-30")])
        #expect(store.mealDays(inMonth: day("2026-11-01")).isEmpty)
        // 같은 날짜가 둘이어도 한 번만.
        insertRemoteRecord(env, day: saturday, createdAt: later, routines: []).lunch = "샐러드"
        try env.context.save()
        #expect(store.mealDays(inMonth: saturday).count == 2)
    }
}
