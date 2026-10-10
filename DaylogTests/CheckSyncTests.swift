import Foundation
import SwiftData
import Testing
@testable import Daylog

/// v1.3.2: 체크 해제와 동기화. 해제한 완료 표시가 병합이나 늦게 도착한 옛 값 때문에 되살아나지 않아야 한다.
@MainActor
struct CheckSyncTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func makeStore(_ env: TestEnv, today: Day = saturday) -> AppStore {
        let clock = TestClock(today)
        let store = AppStore(container: env.container, deviceID: thisMac, clock: { clock.today })
        store.start()
        return store
    }

    private func shown(_ store: AppStore) -> [Bool] {
        store.checkSections.flatMap(\.checks).map(\.isDone)
    }

    /// 다른 Mac이 그 체크를 바꿨다는 편집 기록이 동기화로 들어온 상황.
    @discardableResult
    private func insertRemoteCheckEdit(
        _ env: TestEnv, day: Day, routine: UUID, isDone: Bool, at time: Date, seen: [String: Date] = [:]
    ) -> FieldEdit {
        let edit = FieldEdit(dateKey: day.key, field: CheckEdit.fieldName(routine), deviceID: otherMac)
        edit.value = CheckEdit.value(isDone)
        edit.editedAt = time
        edit.seen = seen.mapValues(\.timeIntervalSinceReferenceDate)
        env.context.insert(edit)
        return edit
    }

    private func myEdit(_ env: TestEnv, day: Day, routine: UUID) throws -> FieldEdit {
        try #require(
            try FieldEditService(context: env.context, deviceID: thisMac)
                .entries(dateKey: day.key, fieldName: CheckEdit.fieldName(routine))
                .first { $0.deviceID == thisMac }
        )
    }

    // MARK: - 중복 체크 병합 (TEST J, L)

    /// 한 기록 안에 같은 루틴의 체크가 둘 들어온 경우: 처음 합칠 때는 완료를 잃지 않고,
    /// 그 뒤 사용자가 해제하면 병합을 몇 번 다시 해도 해제가 유지된다.
    @Test func uncheckSurvivesDuplicateMerge() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: saturday)
        let record = try env.records.fetchOrCreate(day: saturday, today: saturday)
        let duplicate = DayCheck(routine: routines[0])
        duplicate.isDone = true
        record.attach(duplicate)
        try env.context.save()

        let store = makeStore(env)
        #expect(shown(store) == [true, false])

        store.setDone(routineID: routines[0].id, false)
        #expect(shown(store) == [false, false])
        for _ in 1...3 { store.handleExternalChanges() }
        #expect(shown(store) == [false, false])
        #expect(store.stats.today.done == 0)
        #expect(try reconcile(env).changed == false)
    }

    /// 다른 기록(다른 Mac이 따로 만든 같은 날짜의 기록)의 완료 표시도 한 번만 가져온다.
    @Test func uncheckSurvivesMergeWithAnotherRecord() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: saturday)
        _ = try env.records.fetchOrCreate(day: saturday, today: saturday)
        insertRemoteRecord(env, day: saturday, createdAt: .now.addingTimeInterval(60), done: [routines[0].id], routines: routines)
        try env.context.save()

        let store = makeStore(env)
        #expect(shown(store) == [true, false])
        store.setDone(routineID: routines[0].id, false)
        store.handleExternalChanges()
        store.handleExternalChanges()
        #expect(shown(store) == [false, false])
    }

    // MARK: - 늦게 도착한 옛 값 (TEST K)

    /// 이 Mac에서 완료했다가 해제한 뒤, 다른 Mac의 옛 완료 표시가 뒤늦게 올라와 값을 덮어쓴 경우.
    /// 편집 기록으로 순서를 가려 해제 상태로 되돌린다.
    @Test func staleDoneFromAnotherMacDoesNotReviveAnUncheck() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: saturday)
        let store = makeStore(env)
        let target = routines[0].id
        store.setDone(routineID: target, true)
        store.setDone(routineID: target, false)
        let myEditAt = try myEdit(env, day: saturday, routine: target).editedAt

        // 다른 Mac은 내 변경을 보지 못한 채 그보다 "먼저" 완료했다. 그 값이 나중에 동기화되어 체크를 덮어썼다.
        insertRemoteCheckEdit(env, day: saturday, routine: target, isDone: true, at: myEditAt.addingTimeInterval(-600))
        try #require(store.checks.first { $0.routineID == target }).isDone = true
        try env.context.save()

        store.handleExternalChanges()
        #expect(shown(store) == [false, false])
        #expect(store.stats.today.done == 0)

        // 몇 번을 다시 병합해도 같다.
        store.handleExternalChanges()
        #expect(shown(store) == [false, false])
        #expect(try reconcile(env).changed == false)
    }

    /// 반대로 다른 Mac의 변경이 더 나중이면 그 값을 따른다.
    @Test func newerChangeFromAnotherMacWins() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: saturday)
        let store = makeStore(env)
        let target = routines[0].id
        store.setDone(routineID: target, true)
        // 편집 기록은 같은 객체를 고쳐 쓰므로 시각은 값으로 붙잡아 둔다.
        let firstEditAt = try myEdit(env, day: saturday, routine: target).editedAt
        let remoteEditAt = firstEditAt.addingTimeInterval(120)

        // 다른 Mac이 내 완료를 보고 나서 해제했다. iCloud는 아직 체크 값을 전달하지 않았다.
        insertRemoteCheckEdit(
            env, day: saturday, routine: target, isDone: false, at: remoteEditAt, seen: [thisMac: firstEditAt]
        )
        try env.context.save()
        store.handleExternalChanges()
        #expect(shown(store) == [false, false])

        // 이 Mac에서 다시 완료하면(같은 값을 다시 쓰는 것이지만 그 사이 다른 Mac이 바꿨다) 새 변경으로 남아 이긴다.
        store.setDone(routineID: target, true)
        store.handleExternalChanges()
        #expect(shown(store) == [true, false])
        #expect(try myEdit(env, day: saturday, routine: target).editedAt > remoteEditAt)
    }

    /// 상대의 변경을 "보고 나서" 한 변경은 시계가 늦게 가는 Mac에서 했더라도 이긴다.
    @Test func changeMadeAfterSeeingTheOtherWinsEvenWithASlowClock() {
        let done = FieldEditSnapshot(deviceID: thisMac, value: CheckEdit.value(true), editedAt: 1_000, seen: [:])
        let undoneAfterSeeing = FieldEditSnapshot(
            deviceID: otherMac, value: CheckEdit.value(false), editedAt: 400, seen: [thisMac: 1_000]
        )
        #expect(CheckEdit.resolve([done, undoneAfterSeeing]) == false)
        #expect(CheckEdit.resolve([undoneAfterSeeing, done]) == false)
    }

    /// 서로 보지 못한 채 바꿨다면 시각이 늦은 쪽, 시각까지 같으면 기기 식별자 순으로 정한다(어느 Mac에서 계산해도 같다).
    @Test func concurrentChangesResolveDeterministically() {
        let early = FieldEditSnapshot(deviceID: thisMac, value: CheckEdit.value(true), editedAt: 100, seen: [:])
        let late = FieldEditSnapshot(deviceID: otherMac, value: CheckEdit.value(false), editedAt: 200, seen: [:])
        #expect(CheckEdit.resolve([early, late]) == false)
        #expect(CheckEdit.resolve([late, early]) == false)

        let tieA = FieldEditSnapshot(deviceID: "a", value: CheckEdit.value(true), editedAt: 100, seen: [:])
        let tieB = FieldEditSnapshot(deviceID: "b", value: CheckEdit.value(false), editedAt: 100, seen: [:])
        #expect(CheckEdit.resolve([tieA, tieB]) == CheckEdit.resolve([tieB, tieA]))
        #expect(CheckEdit.resolve([]) == nil)
    }

    // MARK: - 기록 형식

    /// 체크 편집 기록은 (날짜, 루틴, 기기)마다 하나만 두고 고쳐 쓴다. 텍스트 칸의 병합에는 섞이지 않는다.
    @Test func checkEditsAreOnePerDeviceAndInvisibleToTextMerge() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(1, today: saturday)
        let store = makeStore(env)
        for _ in 1...4 { store.toggleDone(routineID: routines[0].id) }

        let edits = try env.context.fetch(FetchDescriptor<FieldEdit>())
        #expect(edits.count == 1)
        #expect(edits.first?.field == CheckEdit.fieldName(routines[0].id))
        #expect(edits.first?.value == CheckEdit.value(false))
        #expect(CheckEdit.routineID(fieldName: CheckEdit.fieldName(routines[0].id)) == routines[0].id)
        #expect(CheckEdit.routineID(fieldName: DayTextField.breakfast.rawValue) == nil)
        // v1.3.1 이하가 쓰는 텍스트 칸 묶음에는 나타나지 않는다(예전 버전은 이 기록을 무시한다).
        #expect(try FieldEditService(context: env.context, deviceID: thisMac).groups().isEmpty)
        // 한 기기만 바꾼 체크는 판정 대상이 아니다.
        #expect(try FieldEditService(context: env.context, deviceID: thisMac).checkGroups().isEmpty)
    }

    /// 같은 텍스트를 다시 쓰더라도, 그 사이 다른 Mac이 고쳤다면 새 편집으로 남는다(되돌린 값이 다시 덮이지 않게).
    @Test func rewritingTheSameTextAfterAnotherMacChangedItCounts() throws {
        let env = try TestEnv()
        let record = try env.records.fetchOrCreate(day: saturday, today: saturday)
        try type(env, "토스트", in: .breakfast, of: record, at: t0)
        let service = FieldEditService(context: env.context, deviceID: thisMac)
        let mine = try #require(try service.entries(dateKey: saturday.key, field: .breakfast).first)

        let remote = FieldEdit(dateKey: saturday.key, field: DayTextField.breakfast.rawValue, deviceID: otherMac)
        remote.value = "샐러드"
        remote.editedAt = t0.addingTimeInterval(60)
        remote.seen = [thisMac: mine.editedAt.timeIntervalSinceReferenceDate]
        env.context.insert(remote)
        _ = try reconcile(env)
        #expect(record.breakfast == "샐러드")

        try type(env, "토스트", in: .breakfast, of: record, at: t0.addingTimeInterval(120))
        _ = try reconcile(env)
        #expect(record.breakfast == "토스트")
    }
}
