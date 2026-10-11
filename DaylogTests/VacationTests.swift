import Foundation
import SwiftData
import Testing
@testable import Daylog

@MainActor
struct VacationTests {
    @Test func futureCalendarBrowsingDoesNotCreateFutureRecords() throws {
        let env = try TestEnv()
        let store = AppStore(container: env.container, clock: { monday })
        store.start()
        let count = try env.context.fetchCount(FetchDescriptor<DayRecord>())
        let next = monday.firstOfMonth.addingMonths(1)
        #expect(store.saveVacation(start: next, end: next))
        store.showNextMonth(allowFuture: true)
        #expect(store.calendarMonth == next)
        #expect(store.monthOutcomes[next]?.status == .vacation)
        store.select(next)
        #expect(store.selectedDay == monday)
        #expect(try env.context.fetchCount(FetchDescriptor<DayRecord>()) == count)
    }

    private enum SaveFailure: Error { case simulated }

    @Test func failedVacationSaveRestoresOnlyItsOwnEdits() throws {
        let env = try TestEnv()
        let service = VacationService(context: env.context, deviceID: "phone")
        let existing = try service.save(start: monday, end: monday, memo: "기존 휴가")
        let record = try env.records.fetchOrCreate(day: monday, today: monday)
        record.breakfast = "저장되지 않은 입력"
        let failing = VacationService(context: env.context, deviceID: "phone", persist: { _ in throw SaveFailure.simulated })
        #expect(throws: SaveFailure.self) {
            try failing.save(id: existing.id, start: monday, end: sunday, memo: "실패한 수정")
        }
        #expect(try service.periods() == [existing])
        #expect(record.breakfast == "저장되지 않은 입력")
        #expect(throws: SaveFailure.self) { try failing.remove(existing) }
        #expect(try service.periods() == [existing])
        #expect(throws: SaveFailure.self) { try failing.save(start: sunday, end: sunday) }
        #expect(try service.periods() == [existing])
        // 나중에 다른 입력을 저장해도 실패한 휴가가 되살아나지 않는다.
        try env.context.save()
        #expect(try VacationService(context: env.freshContext()).periods() == [existing])
        #expect(try env.context.fetchCount(FetchDescriptor<FieldEdit>()) == 1)
        #expect(try DayRecordService(context: env.freshContext()).record(on: monday)?.breakfast == "저장되지 않은 입력")
    }

    @Test func appStoreReloadsVacationStatsAndCalendarAfterLocalAndRemoteChanges() throws {
        let env = try TestEnv()
        try env.addRoutines(1, today: monday)
        try env.log(monday, done: 1)
        let store = AppStore(container: env.container, deviceID: "phone", clock: { monday })
        store.start()
        var reloads = 0
        store.onReload = { reloads += 1 }
        #expect(store.saveVacation(start: monday, end: monday, memo: "휴식"))
        #expect(store.isVacation(on: monday))
        #expect(store.stats.today.status == .vacation)
        #expect(store.monthOutcomes[monday]?.status == .vacation)
        #expect(reloads > 0)
        let period = try #require(store.vacations(on: monday).first)
        #expect(store.removeVacation(period))
        #expect(store.stats.today.percent == 100)
        #expect(store.monthOutcomes[monday]?.percent == 100)
        try VacationService(context: env.context, deviceID: "mac").save(start: monday, end: monday)
        store.handleExternalChanges()
        #expect(store.isVacation(on: monday))
        #expect(store.stats.today.status == .vacation)
        #expect(store.monthOutcomes[monday]?.status == .vacation)
    }

    @Test func periodsPersistEditAndRemoveWithoutDeletingRows() throws {
        let env = try TestEnv()
        let service = VacationService(context: env.context, deviceID: "phone")
        let original = try service.save(start: monday, end: monday, memo: " 하루 ")
        let fresh = VacationService(context: env.freshContext(), deviceID: "reader")
        #expect(try fresh.periods() == [VacationPeriod(id: original.id, start: monday, end: monday, memo: "하루")])
        let edited = try service.save(id: original.id, start: monday.adding(days: -3), end: sunday.adding(days: 30), memo: "여행")
        #expect(try service.periods() == [edited])
        try service.remove(edited)
        #expect(try service.periods().isEmpty)
        #expect(try env.context.fetchCount(FetchDescriptor<FieldEdit>()) == 1)
        #expect(try VacationService(context: env.freshContext()).periods().isEmpty)
    }

    @Test func overlappingPeriodsRemainIndependentAndCoverInclusiveBoundaries() throws {
        let env = try TestEnv()
        let service = VacationService(context: env.context, deviceID: "phone")
        let first = try service.save(start: monday, end: monday.adding(days: 3))
        let second = try service.save(start: monday.adding(days: 2), end: sunday)
        #expect(try service.periods().count == 2)
        #expect(try service.covers(monday))
        #expect(try service.covers(sunday))
        #expect(try !service.covers(sunday.adding(days: 1)))
        try service.remove(first)
        #expect(try !service.covers(monday))
        #expect(try service.covers(second.start))
        #expect(try service.covers(sunday))
    }

    @Test func invalidRangeDoesNotWrite() throws {
        let env = try TestEnv()
        let service = VacationService(context: env.context, deviceID: "phone")
        #expect(throws: VacationError.self) {
            try service.save(start: sunday, end: monday)
        }
        #expect(try env.context.fetchCount(FetchDescriptor<FieldEdit>()) == 0)
    }

    @Test func deletionWinsConcurrentEditAndStaleSyncRegardlessOfArrivalOrder() throws {
        let period = VacationPeriod(start: monday, end: sunday)
        let edited = VacationPeriod(id: period.id, start: monday, end: sunday.adding(days: 1), memo: "수정")
        let old = FieldEditSnapshot(deviceID: "phone", value: try VacationEdit.encode(period), editedAt: 10, seen: [:])
        let removal = FieldEditSnapshot(deviceID: "mac", value: try VacationEdit.encode(period, isRemoved: true), editedAt: 20, seen: ["phone": 10])
        let concurrent = FieldEditSnapshot(deviceID: "phone", value: try VacationEdit.encode(edited), editedAt: 30, seen: [:])
        #expect(VacationEdit.resolve(id: period.id, entries: [old, removal]) == nil)
        #expect(VacationEdit.resolve(id: period.id, entries: [removal, old]) == nil)
        #expect(VacationEdit.resolve(id: period.id, entries: [concurrent, removal]) == nil)
        #expect(VacationEdit.resolve(id: period.id, entries: [removal, concurrent]) == nil)
        // 사용자가 삭제를 본 다음 명시적으로 다시 설정한 편집만 복원할 수 있다.
        let restored = FieldEditSnapshot(deviceID: "phone", value: try VacationEdit.encode(edited), editedAt: 40, seen: ["mac": 20])
        #expect(VacationEdit.resolve(id: period.id, entries: [removal, restored]) == edited)
    }

    @Test func concurrentEditsChooseOneWholePeriodDeterministically() throws {
        let first = VacationPeriod(start: monday, end: sunday, memo: "첫 계획")
        let second = VacationPeriod(id: first.id, start: monday.adding(days: 4), end: sunday.adding(days: 4), memo: "두 번째 계획")
        let phone = FieldEditSnapshot(deviceID: "phone", value: try VacationEdit.encode(first), editedAt: 20, seen: [:])
        let tablet = FieldEditSnapshot(deviceID: "tablet", value: try VacationEdit.encode(second), editedAt: 20, seen: [:])
        #expect(VacationEdit.resolve(id: first.id, entries: [phone, tablet]) == second)
        #expect(VacationEdit.resolve(id: first.id, entries: [tablet, phone]) == second)
    }

    @Test func savedDeletionDoesNotResurrectWhenOfflineDeviceArrives() throws {
        let env = try TestEnv()
        let service = VacationService(context: env.context, deviceID: "phone")
        let period = try service.save(start: monday, end: sunday)
        try service.remove(period)
        let stale = FieldEdit(dateKey: VacationEdit.dateKey, field: VacationEdit.fieldName(period.id), deviceID: "offline-mac")
        stale.value = try VacationEdit.encode(period)
        // 미래 시각의 동시 편집도 삭제를 되살리지 않는다.
        stale.editedAt = Date.now.addingTimeInterval(100)
        env.context.insert(stale)
        try env.context.save()
        _ = try SyncReconciler(context: env.context, deviceID: "phone").reconcile(today: sunday)
        #expect(try service.periods().isEmpty)
        #expect(try env.context.fetchCount(FetchDescriptor<FieldEdit>()) == 2)
    }

    @Test func vacationExcludesBothTalliesAndRestoresOriginalRecordsOnRemoval() throws {
        let env = try TestEnv()
        try env.addRoutines(2, today: monday)
        let record = try env.log(monday, done: 1)
        record.breakfast = "토스트"
        record.mealMemo = "기록 유지"
        try env.context.save()
        let tuesday = monday.adding(days: 1)
        try env.log(tuesday, done: 2)
        let service = VacationService(context: env.context, deviceID: "phone")
        let period = try service.save(start: monday, end: monday)
        let stats = try env.stats.dashboard(today: tuesday)
        #expect(stats.weeklyAverage == 100)
        #expect(stats.routineRates.allSatisfy { $0.done == 1 && $0.scheduled == 1 })
        #expect(stats.groupRates.first?.done == 2)
        #expect(stats.groupRates.first?.scheduled == 2)
        let fresh = DayRecordService(context: env.freshContext())
        let preserved = try #require(try fresh.record(on: monday))
        #expect(preserved.breakfast == "토스트")
        #expect(preserved.mealMemo == "기록 유지")
        #expect(preserved.checkList.count == 2)
        #expect(preserved.checkList.filter(\.isDone).count == 1)
        try service.remove(period)
        #expect(try env.stats.dashboard(today: tuesday).weeklyAverage == 75)
        #expect(try env.stats.period(.all, today: tuesday).countedDays == 2)
    }

    @Test func vacationsOnlyHaveNoAverageOrRates() throws {
        let env = try TestEnv()
        try env.addRoutines(1, today: monday)
        try env.log(monday, done: 1)
        let service = VacationService(context: env.context, deviceID: "phone")
        try service.save(start: monday, end: sunday)
        let dashboard = try env.stats.dashboard(today: sunday)
        #expect(dashboard.today.status == .vacation)
        #expect(dashboard.today.percent == nil)
        #expect(dashboard.weeklyAverage == nil)
        #expect(dashboard.routineRates.isEmpty)
        #expect(dashboard.groupRates.isEmpty)
        for period in StatsPeriod.allCases {
            let result = try env.stats.period(period, today: sunday)
            #expect(result.averagePercent == nil)
            #expect(result.countedDays == 0)
            #expect(result.achievedDays == 0)
            #expect(result.groupRates.isEmpty)
            #expect(result.routineRates.isEmpty)
        }
    }

    @Test func vacationPrecedesFutureRestAndPreStartAndKeepsStreaks() throws {
        let env = try TestEnv()
        try env.addRoutines(1, today: monday)
        try env.log(monday, done: 1)
        try env.log(sunday, done: 1)
        let service = VacationService(context: env.context, deviceID: "phone")
        try service.save(start: monday.adding(days: 1), end: saturday)
        let stats = try env.stats.dashboard(today: sunday)
        #expect(stats.currentStreak == 2)
        #expect(stats.longestStreak == 2)
        try service.save(start: monday.adding(days: -7), end: monday.adding(days: -1))
        try service.save(start: sunday.adding(days: 1), end: sunday.adding(days: 7))
        let outcomes = try env.stats.outcomes(from: monday.adding(days: -1), to: sunday.adding(days: 1), today: sunday)
        #expect(outcomes.first?.status == .vacation)
        #expect(outcomes.last?.status == .vacation)
        #expect(HeatLevel(try #require(outcomes.first), threshold: 80) == .vacation)
        #expect(HeatLevel.vacation.label == "휴가")
    }
}
