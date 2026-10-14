import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 새싹이 성장: XP 규칙, 레벨과 성장 단계, 완료·취소·건너뛰기·휴가, 중복 기록, 반응이 되풀이되지 않는지.
@MainActor
struct SaessagiGrowthTests {
    private let tuesday = day("2026-10-06")
    private let wednesday = day("2026-10-07")

    private func outcome(_ status: DayStatus, done: Int, total: Int, skipped: Int = 0, on date: Day? = nil) -> DayOutcome {
        DayOutcome(day: date ?? monday, status: status, done: done, total: total, skipped: skipped)
    }

    private func makeStore(_ env: TestEnv, today: Day) -> AppStore {
        let clock = TestClock(today)
        let store = AppStore(container: env.container, clock: { clock.today })
        store.start()
        return store
    }

    // MARK: - 하루의 XP

    @Test func routinesEarnTenAndAFullDayEarnsTwentyMore() {
        #expect(GrowthCalculator.xp(for: outcome(.recorded, done: 1, total: 3)) == 10)
        #expect(GrowthCalculator.xp(for: outcome(.recorded, done: 2, total: 3)) == 20)
        // 예정된 루틴을 모두 완료했다.
        #expect(GrowthCalculator.xp(for: outcome(.recorded, done: 3, total: 3)) == 50)
        #expect(GrowthCalculator.xp(for: outcome(.unrecorded, done: 1, total: 1)) == 30)
        // 완료한 루틴이 없으면 하루 보상도 없다.
        #expect(GrowthCalculator.xp(for: outcome(.recorded, done: 0, total: 3)) == 0)
    }

    @Test func skipsVacationsAndRestDaysEarnNothing() {
        // 건너뛰기는 완료가 아니다: 다 건너뛴 날은 0, 하나 완료하고 나머지를 건너뛴 날은 하루 보상이 없다.
        #expect(GrowthCalculator.xp(for: outcome(.recorded, done: 0, total: 2, skipped: 2)) == 0)
        #expect(GrowthCalculator.xp(for: outcome(.recorded, done: 1, total: 2, skipped: 1)) == 10)
        for status in [DayStatus.vacation, .rest, .preStart, .future] {
            #expect(GrowthCalculator.xp(for: outcome(status, done: 2, total: 2)) == 0, "\(status)")
        }
    }

    @Test func theSameDayCountsOnce() {
        let full = outcome(.recorded, done: 1, total: 1, on: monday)
        #expect(GrowthCalculator.totalXP([full, full, outcome(.recorded, done: 1, total: 2, on: tuesday)]) == 40)
    }

    // MARK: - 레벨과 성장 단계

    @Test func levelsAndStagesFollowTheThresholds() {
        let cases: [(xp: Int, level: Int, stage: GrowthStage)] = [
            (0, 1, .sprout), (99, 1, .sprout), (100, 2, .sprout), (899, 9, .sprout), (900, 10, .leaf), (2399, 24, .leaf),
            (2400, 25, .flower), (10_000, 101, .flower),
        ]
        for item in cases {
            let growth = SaessagiGrowth(xp: item.xp)
            #expect(growth.level == item.level && growth.stage == item.stage, "\(item.xp) XP")
        }
        #expect(GrowthCalculator.xp(forLevel: 10) == 900 && GrowthCalculator.xp(forLevel: 25) == 2400)
        let growth = SaessagiGrowth(xp: 1234)
        #expect(growth.level == 13 && growth.xpIntoLevel == 34 && growth.xpForNextLevel == 100)
        #expect(abs(growth.progress - 0.34) < 1e-9)
        #expect(growth.xpToNextStage == 1166)
        #expect(growth.nextStageNote == "Lv.25에 꽃이 피어요 · 1,166 XP 남음")
        #expect(SaessagiGrowth(xp: 120).nextStageNote == "Lv.10에 잎사귀로 자라요 · 780 XP 남음")
        // 꽃 뒤로는 레벨만 오르고 모습은 그대로다.
        #expect(SaessagiGrowth(xp: 5000).xpToNextStage == nil)
        #expect(GrowthStage.allCases.map(\.pose) == [.growthSprout, .growthLeaf, .growthFlower])
    }

    @Test func eventsMarkLevelUpsAndGrowth() throws {
        // Lv.9 → 10: 잎사귀로 자란다.
        let leaf = try #require(GrowthEvent.make(before: 890, after: 920))
        #expect(leaf.gained == 30 && leaf.includesPerfectDay && leaf.leveledUp && leaf.grewUp && leaf.after.stage == .leaf)
        #expect(leaf.celebration == "잎사귀로 자랐어요!")
        // Lv.24 → 25: 꽃이 핀다.
        let flower = try #require(GrowthEvent.make(before: 2395, after: 2405))
        #expect(flower.grewUp && flower.after.stage == .flower && flower.celebration == "꽃이 피었어요!")
        // 레벨만 오른다.
        let level = try #require(GrowthEvent.make(before: 195, after: 205))
        #expect(level.leveledUp && !level.grewUp && level.celebration == "Lv.3 달성!" && level.detail == nil)
        // 같은 레벨 안.
        let small = try #require(GrowthEvent.make(before: 10, after: 20))
        #expect(!small.leveledUp && small.celebration == nil)
        // XP가 줄거나 그대로면 반응하지 않는다.
        #expect(GrowthEvent.make(before: 30, after: 10) == nil && GrowthEvent.make(before: 30, after: 30) == nil)
    }

    // MARK: - 실제 기록에서

    @Test func completingUndoingAndSkippingUpdateXP() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: monday)
        let store = makeStore(env, today: monday)
        #expect(store.growth.xp == 0 && store.growthEvent == nil)

        store.setDone(routineID: routines[0].id, true)
        #expect(store.growth.xp == 10)
        let first = try #require(store.growthEvent)
        #expect(first.gained == 10 && !first.includesPerfectDay)

        // 남은 하나까지 완료: 10 + 하루 보상 20.
        store.setDone(routineID: routines[1].id, true)
        #expect(store.growth.xp == 40)
        let second = try #require(store.growthEvent)
        #expect(second.id != first.id && second.gained == 30 && second.includesPerfectDay)

        // 완료를 취소하면 다시 계산된다(하루 보상도 빠진다). 취소에는 반응하지 않는다.
        store.setDone(routineID: routines[1].id, false)
        #expect(store.growth.xp == 10)
        #expect(store.growthEvent?.id == second.id)

        // 건너뛰기는 0 XP이고 하루 보상도 주지 않는다.
        store.setSkipped(routineID: routines[1].id, true)
        #expect(store.growth.xp == 10)
        #expect(store.growthEvent?.id == second.id)
    }

    @Test func pastRecordsCountAndVacationDaysDoNot() throws {
        let env = try TestEnv()
        _ = try env.addRoutines(2, today: monday)
        try env.log(monday, done: 2)      // 20 + 20
        try env.log(tuesday, done: 1)     // 10
        try env.log(wednesday, done: 2)   // 휴가로 바꾼다
        let store = makeStore(env, today: saturday)
        #expect(store.growth.xp == 90)
        #expect(store.saveVacation(start: wednesday, end: wednesday))
        #expect(store.growth.xp == 50)
        // 앱을 다시 켜도 같은 값이고, 지난 기록의 축하는 다시 하지 않는다.
        let relaunched = makeStore(env, today: saturday)
        #expect(relaunched.growth.xp == 50 && relaunched.growthEvent == nil)
    }

    @Test func duplicateChecksAndRecordsCountOnce() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: monday)
        let record = try env.log(monday, done: 1)
        // 동기화로 같은 루틴의 완료 체크가 하나 더, 같은 날짜의 기록이 하나 더 들어왔다.
        let duplicate = DayCheck(routine: routines[0])
        duplicate.isDone = true
        record.attach(duplicate)
        let other = DayRecord(day: monday)
        env.context.insert(other)
        for routine in routines {
            let check = DayCheck(routine: routine)
            check.isDone = routine.id == routines[0].id
            other.attach(check)
        }
        try env.context.save()
        let store = makeStore(env, today: saturday)
        #expect(store.growth.xp == 10)
    }
}
