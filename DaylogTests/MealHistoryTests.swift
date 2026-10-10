import Foundation
import SwiftData
import Testing
@testable import Daylog

/// v1.3: 식사 기록 조회 (명세 18절 TEST 12~18)
@MainActor
struct MealHistoryTests {
    private let today = saturday

    private func meals(_ env: TestEnv) -> MealHistoryService {
        MealHistoryService(context: env.context)
    }

    /// `offset`일 전 날짜에 식사 내용을 적는다.
    @discardableResult
    private func write(
        _ env: TestEnv, daysAgo offset: Int,
        breakfast: String = "", lunch: String = "", dinner: String = "", snack: String = "", memo: String = ""
    ) throws -> DayRecord {
        let record = try env.records.fetchOrCreate(day: today.adding(days: -offset), today: today)
        env.records.setText(breakfast, at: \.breakfast, of: record)
        env.records.setText(lunch, at: \.lunch, of: record)
        env.records.setText(dinner, at: \.dinner, of: record)
        env.records.setText(snack, at: \.snack, of: record)
        env.records.setText(memo, at: \.mealMemo, of: record)
        try env.context.save()
        return record
    }

    /// TEST 12
    @Test func recordedDaysCountsDaysWithAnyMeal() throws {
        let env = try TestEnv()
        try write(env, daysAgo: 0, breakfast: "그릭요거트")
        _ = try env.records.fetchOrCreate(day: today.adding(days: -1), today: today) // 열어 보기만 한 날
        try write(env, daysAgo: 2, dinner: "닭가슴살 샐러드", snack: "바나나")

        #expect(try meals(env).summary(period: .week, today: today).recordedDays == 2)
        #expect(try meals(env).page(period: .week, query: "", today: today).days.map(\.day)
            == [today, today.adding(days: -2)])
    }

    /// TEST 13: 메모만 있는 날은 식사 기록일로 세지 않지만, 목록과 검색에는 나온다.
    @Test func memoOnlyDayIsListedButNotCounted() throws {
        let env = try TestEnv()
        try write(env, daysAgo: 0, lunch: "김치찌개")
        try write(env, daysAgo: 1, memo: "물 2L 마심")
        try write(env, daysAgo: 2, lunch: "   ", memo: "  ") // 공백뿐

        let summary = try meals(env).summary(period: .week, today: today)
        #expect(summary.recordedDays == 1)
        let days = try meals(env).page(period: .week, query: "", today: today).days
        #expect(days.map(\.day) == [today, today.adding(days: -1)])
        #expect(days.map(\.hasMeal) == [true, false])
        #expect(try meals(env).page(period: .week, query: "물 2L", today: today).days.map(\.day) == [today.adding(days: -1)])
    }

    /// TEST 14
    @Test func searchFindsMatchingDaysOnly() throws {
        let env = try TestEnv()
        try write(env, daysAgo: 0, breakfast: "그릭요거트", dinner: "닭가슴살 샐러드")
        try write(env, daysAgo: 1, lunch: "김치찌개")
        try write(env, daysAgo: 3, lunch: "Chicken Sandwich", memo: "닭가슴살은 내일")
        try write(env, daysAgo: 5, snack: "바나나")

        let service = meals(env)
        #expect(try service.page(period: .month, query: "닭가슴살", today: today).days.map(\.day)
            == [today, today.adding(days: -3)])
        #expect(try service.page(period: .month, query: "chicken", today: today).days.map(\.day) == [today.adding(days: -3)])
        #expect(try service.page(period: .month, query: "  바나나 ", today: today).days.count == 1)
        #expect(try service.page(period: .month, query: "피자", today: today).days.isEmpty)
        // 검색어가 비면 전체 목록.
        #expect(try service.page(period: .month, query: "  ", today: today).days.count == 4)
    }

    /// TEST 15
    @Test func periodFilters() throws {
        let env = try TestEnv()
        for offset in [0, 6, 7, 29, 30, 100] {
            try write(env, daysAgo: offset, lunch: "식사 \(offset)")
        }
        // 미래 날짜의 기록(시계가 뒤로 간 경우)은 어떤 기간에도 나오지 않는다.
        let future = DayRecord(day: today.adding(days: 2))
        future.lunch = "미래"
        env.context.insert(future)
        try env.context.save()

        func offsets(_ period: MealPeriod, query: String = "") throws -> [Int] {
            try meals(env).page(period: period, query: query, today: today).days.map { $0.day.days(until: today) }
        }
        #expect(try offsets(.week) == [0, 6])
        #expect(try offsets(.month) == [0, 6, 7, 29])
        #expect(try offsets(.all) == [0, 6, 7, 29, 30, 100])
        #expect(try offsets(.week, query: "식사 7").isEmpty) // 기간과 검색을 함께 적용
        #expect(try offsets(.month, query: "식사 7") == [7])
        #expect(try meals(env).summary(period: .week, today: today).recordedDays == 2)
        #expect(try meals(env).summary(period: .month, today: today).recordedDays == 4)
        #expect(try meals(env).summary(period: .all, today: today).recordedDays == 6)
    }

    /// TEST 16
    @Test func editsShowUpOnTheNextQuery() throws {
        let env = try TestEnv()
        let store = AppStore(container: env.container, clock: { saturday })
        store.start()
        store.setText("김치찌개", at: \.lunch)
        store.flush()
        #expect(store.mealPage(period: .month, query: "").days.first?.lunch == "김치찌개")
        let version = store.dataVersion

        // 식사 기록 탭에서 지난 날짜를 열어 고친다.
        store.open(saturday.adding(days: -1))
        store.setText("어제 저녁", at: \.dinner)
        store.flush()
        store.goToToday()
        store.setText("김치찌개, 밥", at: \.lunch)
        store.flush()

        let days = store.mealPage(period: .month, query: "").days
        #expect(days.map(\.day) == [saturday, saturday.adding(days: -1)])
        #expect(days.first?.lunch == "김치찌개, 밥")
        #expect(days.last?.dinner == "어제 저녁")
        #expect(store.dataVersion > version)
        #expect(store.mealSummary(period: .month).recordedDays == 2)
        #expect(try DayRecordService(context: env.freshContext()).record(on: saturday)?.lunch == "김치찌개, 밥")
    }

    /// TEST 17·18: 같은 날짜가 둘이어도 한 번만 세고, 병합된 최종 내용을 보여 준다.
    @Test func duplicateDatesAreCountedOnce() throws {
        let env = try TestEnv()
        try write(env, daysAgo: 0, lunch: "김치찌개")
        let remote = insertRemoteRecord(env, day: today, createdAt: later, routines: [])
        remote.lunch = "샐러드"
        remote.dinner = "계란"
        try env.context.save()

        // 병합 전에도 중복 집계하지 않는다.
        #expect(try meals(env).summary(period: .week, today: today).recordedDays == 1)
        #expect(try meals(env).page(period: .week, query: "", today: today).days.count == 1)

        _ = try reconcile(env, today: today)
        let days = try meals(env).page(period: .week, query: "", today: today).days
        #expect(days.count == 1)
        #expect(days.first?.lunch == "김치찌개\n샐러드") // 두 기기의 내용을 모두 보존한 결과
        #expect(days.first?.dinner == "계란")
        #expect(try meals(env).page(period: .week, query: "샐러드", today: today).days.count == 1)
        #expect(try meals(env).summary(period: .all, today: today).recordedDays == 1)
    }

    /// 이번 달 기록률: 앱을 쓰기 시작한 날 이전은 분모에 넣지 않는다.
    @Test func monthRateStartsFromFirstUse() throws {
        let env = try TestEnv()
        // 아무것도 쓰지 않았으면 기록률 자체가 없다.
        #expect(try meals(env).summary(period: .month, today: today).monthPercent == nil)

        try env.addRoutines(1, today: day("2026-10-04")) // 10월 4일부터 사용
        try write(env, daysAgo: 0, breakfast: "a")
        try write(env, daysAgo: 2, lunch: "b")
        try write(env, daysAgo: 5, dinner: "c")
        try write(env, daysAgo: 1, memo: "메모만")

        let summary = try meals(env).summary(period: .month, today: today)
        #expect(summary.monthElapsedDays == 7) // 10/4 ~ 10/10
        #expect(summary.monthRecordedDays == 3)
        #expect(summary.monthPercent == 43)

        // 지난달부터 쓰고 있었다면 이번 달 1일부터 센다.
        try write(env, daysAgo: 20, lunch: "지난달")
        let whole = try meals(env).summary(period: .month, today: today)
        #expect(whole.monthElapsedDays == 10)
        #expect(whole.monthPercent == 30)
        #expect(whole.recordedDays == 4)
    }

    /// 기록이 많아도 한 번에 한 페이지씩만 읽고, 이어 읽으면 빠짐·중복 없이 전부 나온다.
    @Test func paginationCoversEverythingWithoutDuplicates() throws {
        let env = try TestEnv()
        let total = 400
        for offset in 0..<total {
            let record = DayRecord(day: today.adding(days: -offset))
            if offset % 2 == 0 { record.lunch = offset % 10 == 0 ? "닭가슴살 \(offset)" : "식사 \(offset)" }
            env.context.insert(record)
        }
        try env.context.save()

        var collected: [Day] = []
        var offset: Int? = 0
        var pages = 0
        while let current = offset {
            let page = try meals(env).page(period: .all, query: "", today: today, offset: current)
            #expect(page.days.count <= MealHistoryService.pageSize + 300)
            collected += page.days.map(\.day)
            offset = page.nextOffset
            pages += 1
        }
        #expect(collected.count == total / 2)
        #expect(Set(collected).count == collected.count)
        #expect(collected == collected.sorted(by: >))
        #expect(pages > 1)

        let first = try meals(env).page(period: .all, query: "닭가슴살", today: today)
        #expect(first.days.count == total / 10)
        #expect(try meals(env).summary(period: .all, today: today).recordedDays == total / 2)
    }
}
