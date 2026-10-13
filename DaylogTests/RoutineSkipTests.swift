import Foundation
import SwiftData
import Testing
@testable import Daylog

/// Phase 5-A: 루틴 건너뛰기. 상태 전환, 저장과 재실행, 예전 앱과의 호환, 통계·알림·위젯.
@MainActor
struct RoutineSkipTests {
    private func makeStore(_ env: TestEnv, today: Day, device: String = thisMac) -> (AppStore, TestClock) {
        let clock = TestClock(today)
        let store = AppStore(container: env.container, deviceID: device, clock: { clock.today })
        store.start()
        return (store, clock)
    }

    /// 화면에 보이는 상태(그룹 순서 → 항목 순서).
    private func shown(_ store: AppStore) -> [CheckStatus] {
        store.checkSections.flatMap(\.checks).map(\.status)
    }

    private func savedDone(_ env: TestEnv, on day: Day) throws -> [Bool] {
        let record = try #require(try DayRecordService(context: env.freshContext()).record(on: day))
        return record.checkList.map(\.isDone)
    }

    private func edits(_ env: TestEnv, day: Day, routine: UUID) throws -> [FieldEdit] {
        try FieldEditService(context: env.context, deviceID: thisMac)
            .entries(dateKey: day.key, fieldName: CheckEdit.fieldName(routine))
    }

    // MARK: - 상태 전환

    @Test func doneThenSkippedThenPending() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: monday)
        let (store, _) = makeStore(env, today: monday)
        let target = routines[0].id

        store.setDone(routineID: target, true)
        #expect(shown(store) == [.done, .pending])
        #expect(store.selectedOutcome.percent == 50)

        // 완료한 항목을 건너뛰면 상태가 건너뛰기로 바뀐다. 하루에 상태는 하나다.
        store.setSkipped(routineID: target, true)
        #expect(shown(store) == [.skipped, .pending])
        #expect(store.selectedOutcome.percent == 0)
        #expect(try savedDone(env, on: monday) == [false, false])

        // 건너뛰기를 취소하면 미완료로 돌아간다(완료로 되돌리지 않는다).
        store.setSkipped(routineID: target, false)
        #expect(shown(store) == [.pending, .pending])
        #expect(try edits(env, day: monday, routine: target).map(\.value) == ["0"])
    }

    @Test func checkingASkippedRoutineCompletesIt() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(1, today: monday)
        let (store, _) = makeStore(env, today: monday)
        let target = routines[0].id

        store.setSkipped(routineID: target, true)
        #expect(shown(store) == [.skipped])
        // 체크 칸은 전과 같이 동작한다: 누르면 완료, 다시 누르면 미완료.
        store.toggleDone(routineID: target)
        #expect(shown(store) == [.done])
        store.toggleDone(routineID: target)
        #expect(shown(store) == [.pending])
    }

    @Test func cancellingASkipNeverUndoesACompletion() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(1, today: monday)
        let (store, _) = makeStore(env, today: monday)
        let target = routines[0].id

        store.setDone(routineID: target, true)
        // 건너뛴 항목이 아니면 "건너뛰기 취소"는 아무것도 바꾸지 않는다.
        store.setSkipped(routineID: target, false)
        #expect(shown(store) == [.done])
        #expect(try savedDone(env, on: monday) == [true])
    }

    @Test func skippingKeepsTheCheckAndItsHistory() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: monday)
        let (store, _) = makeStore(env, today: monday)
        store.setDone(routineID: routines[1].id, true)
        let checksBefore = try env.context.fetchCount(FetchDescriptor<DayCheck>())

        store.setSkipped(routineID: routines[0].id, true)
        // 체크 줄을 지우거나 새로 만들지 않고, 다른 루틴의 완료도 그대로다.
        #expect(try env.context.fetchCount(FetchDescriptor<DayCheck>()) == checksBefore)
        #expect(shown(store) == [.skipped, .done])
        // 건너뛰기는 기존 체크 편집 기록 한 줄의 값으로만 남는다.
        #expect(try edits(env, day: monday, routine: routines[0].id).map(\.value) == [CheckEdit.skippedValue])
    }

    // MARK: - 저장과 재실행, 과거 날짜

    @Test func skipSurvivesARelaunch() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: monday)
        let (store, _) = makeStore(env, today: monday)
        store.setSkipped(routineID: routines[0].id, true)

        // 앱을 다시 켠 것처럼 같은 저장소로 새 AppStore를 만든다.
        let (relaunched, _) = makeStore(env, today: monday)
        #expect(shown(relaunched) == [.skipped, .pending])
        #expect(relaunched.todaySections.flatMap(\.checks).map(\.status) == [.skipped, .pending])
        // 저장된 편집 기록으로도 확인한다.
        let saved = try FieldEditService(context: env.freshContext(), deviceID: "reader").skippedRoutines(dateKey: monday.key)
        #expect(saved == [routines[0].id])
    }

    @Test func pastDaysCanBeSkippedWithoutTouchingToday() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: monday)
        let (store, clock) = makeStore(env, today: monday)
        clock.today = monday.adding(days: 2)
        store.refreshToday()

        store.select(monday)
        store.setSkipped(routineID: routines[1].id, true)
        #expect(shown(store) == [.pending, .skipped])
        #expect(store.todaySections.flatMap(\.checks).map(\.status) == [.pending, .pending])

        store.goToToday()
        #expect(shown(store) == [.pending, .pending])
        store.select(monday)
        #expect(shown(store) == [.pending, .skipped])
    }

    @Test func futureDaysCannotBeSkipped() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(1, today: monday)
        let (store, _) = makeStore(env, today: monday)
        store.setSkipped(routineID: routines[0].id, on: monday.adding(days: 1), true)
        #expect(try env.context.fetchCount(FetchDescriptor<FieldEdit>()) == 0)
    }

    // MARK: - 예전 앱과의 호환, 기기 간 판정

    /// 건너뛰기를 모르는 앱은 편집 값이 "1"인지로만 완료를 판정한다. 그 판정에서 건너뛰기는 미완료다.
    @Test func olderAppsReadASkipAsNotDone() {
        let skip = FieldEditSnapshot(deviceID: thisMac, value: CheckEdit.skippedValue, editedAt: 10, seen: [:])
        #expect(CheckEdit.resolve([skip]) == false)
        #expect(CheckEdit.status([skip]) == .skipped)
        // 값의 글자는 예전 형식과 겹치지 않는다.
        #expect(CheckEdit.value(.done) == "1" && CheckEdit.value(.pending) == "0" && CheckEdit.value(.skipped) == "skip")
        #expect(CheckEdit.status(value: "알 수 없는 값") == .pending)
    }

    /// 예전 앱이 건너뛴 항목을 완료하면(편집 값 "1") 새 앱에서도 완료다.
    @Test func aLaterCompletionFromAnotherDeviceReplacesTheSkip() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(1, today: saturday)
        let (store, _) = makeStore(env, today: saturday)
        let target = routines[0].id
        store.setSkipped(routineID: target, true)
        let mine = try #require(try edits(env, day: saturday, routine: target).first)

        let remote = FieldEdit(dateKey: saturday.key, field: CheckEdit.fieldName(target), deviceID: otherMac)
        remote.value = "1"
        remote.editedAt = mine.editedAt.addingTimeInterval(60)
        remote.seen = [thisMac: mine.editedAt.timeIntervalSinceReferenceDate]
        env.context.insert(remote)
        try env.context.save()

        store.handleExternalChanges()
        #expect(shown(store) == [.done])
        #expect(try savedDone(env, on: saturday) == [true])
    }

    /// 다른 기기의 옛 완료 표시가 뒤늦게 체크 값을 덮어써도, 더 나중에 한 건너뛰기가 남는다.
    @Test func aStaleCompletionDoesNotReplaceALaterSkip() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(1, today: saturday)
        let (store, _) = makeStore(env, today: saturday)
        let target = routines[0].id
        store.setSkipped(routineID: target, true)
        let mine = try #require(try edits(env, day: saturday, routine: target).first)

        let remote = FieldEdit(dateKey: saturday.key, field: CheckEdit.fieldName(target), deviceID: otherMac)
        remote.value = "1"
        remote.editedAt = mine.editedAt.addingTimeInterval(-600)
        env.context.insert(remote)
        try #require(store.checks.first { $0.routineID == target }).isDone = true
        try env.context.save()

        store.handleExternalChanges()
        #expect(shown(store) == [.skipped])
        #expect(try reconcile(env).changed == false)
    }

    /// 편집 기록 없이 완료 표시만 들어온 경우(완료를 잃지 않는 예전 병합)에는 완료로 본다.
    @Test func aCompletionMarkAlwaysWinsOverASkipRecord() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(1, today: monday)
        let (store, _) = makeStore(env, today: monday)
        let target = routines[0].id
        store.setSkipped(routineID: target, true)

        try #require(store.checks.first { $0.routineID == target }).isDone = true
        try env.context.save()
        store.refreshChecks()
        #expect(shown(store) == [.done])
        // 그 뒤 해제하면 미완료가 되고, 예전 건너뛰기가 되살아나지 않는다.
        store.setDone(routineID: target, false)
        #expect(shown(store) == [.pending])
    }

    // MARK: - 통계

    @Test func skippedCountsAsNotAchieved() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(4, today: monday)
        let (store, _) = makeStore(env, today: monday)
        store.setDone(routineID: routines[0].id, true)
        store.setDone(routineID: routines[1].id, true)
        store.setDone(routineID: routines[2].id, true)
        #expect(store.stats.today.percent == 75)

        // 미완료 항목을 건너뛰어도 달성률은 그대로다(분모에 남는다).
        store.setSkipped(routineID: routines[3].id, true)
        #expect(store.stats.today.percent == 75)
        #expect((store.stats.today.done, store.stats.today.total) == (3, 4))
        // 완료한 항목을 건너뛰면 그만큼 내려간다.
        store.setSkipped(routineID: routines[2].id, true)
        #expect(store.stats.today.percent == 50)
        #expect(store.checkSections.reduce(0) { $0 + $1.skipped } == 2)
    }

    @Test func streakPolicyIsUnchangedBySkips() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(1, today: monday)
        try env.log(monday, done: 1)
        try env.log(monday.adding(days: 1), done: 1)
        let (store, _) = makeStore(env, today: monday.adding(days: 2))
        #expect(store.stats.currentStreak == 2)

        // 오늘을 건너뛰어도 오늘은 "아직 기준 미만"일 뿐이라 어제까지의 연속이 유지된다(미완료와 같다).
        store.setSkipped(routineID: routines[0].id, true)
        #expect(store.stats.currentStreak == 2)
        // 지난 날짜를 건너뛰면 그날은 미달성이므로 미완료로 둔 것과 똑같이 끊긴다.
        store.select(monday.adding(days: 1))
        store.setSkipped(routineID: routines[0].id, true)
        #expect(store.stats.currentStreak == 0)
        #expect(store.stats.longestStreak == 1)
    }

    // MARK: - 루틴별 최근 기록

    @Test func historyDistinguishesDoneSkippedMissedAndPending() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(1, today: monday)
        let target = routines[0].id
        let (store, clock) = makeStore(env, today: monday)
        store.setDone(routineID: target, true)                 // 월: 완료
        clock.today = monday.adding(days: 1)
        store.refreshToday()
        store.setSkipped(routineID: target, true)              // 화: 건너뛰기
        clock.today = monday.adding(days: 3)                   // 수: 열지 않음 → 기록 없음
        store.refreshToday()                                   // 목: 오늘, 아직 안 함 → 진행 중

        let history = try #require(store.routineHistories().first)
        #expect(history.marks.map(\.day) == (0...3).map { monday.adding(days: $0) })
        #expect(history.marks.map(\.state) == [.done, .skipped, .missed, .pending])
        let summary = RoutineHistory.Summary(history.marks)
        #expect((summary.done, summary.skipped, summary.missed, summary.pending) == (1, 1, 1, 1))
        #expect(summary.text == "완료 1 · 건너뛰기 1 · 기록 없음 1 · 진행 중 1")
    }

    @Test func historyCountsOnlyScheduledDaysAndKeepsTheLatest() throws {
        let env = try TestEnv()
        // 월·수·금에만 하는 루틴.
        let routine = try env.routines.add(title: "운동", weekdays: [1, 3, 5], today: monday)
        let (store, clock) = makeStore(env, today: monday)
        clock.today = monday.adding(days: 60)
        store.refreshToday()

        let history = try #require(store.routineHistories().first { $0.routineID == routine.id })
        // 예정이 없던 날은 세지 않고, 가장 최근 14번만 남긴다.
        #expect(history.marks.count == RoutineHistory.wideCount)
        #expect(history.marks.allSatisfy { [1, 3, 5].contains($0.day.weekday) })
        #expect(history.marks.last?.day == monday.adding(days: 60))
        #expect(history.recent(RoutineHistory.compactCount).count == 7)
        #expect(history.recent(7).last == history.marks.last)
    }

    @Test func historyShowsVacationSeparately() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(1, today: monday)
        let (store, clock) = makeStore(env, today: monday)
        store.setDone(routineID: routines[0].id, true)
        clock.today = monday.adding(days: 2)
        store.refreshToday()
        // 화요일은 휴가. 그날 체크했더라도 통계에서 빠지므로 휴가로 표시한다.
        #expect(store.saveVacation(start: monday.adding(days: 1), end: monday.adding(days: 1)))

        let history = try #require(store.routineHistories().first)
        #expect(history.marks.map(\.state) == [.done, .vacation, .pending])
        #expect(RoutineHistory.Summary(history.marks).text == "완료 1 · 건너뛰기 0 · 기록 없음 0 · 진행 중 1 · 휴가 1")
    }

    @Test func historyLeavesOutArchivedRoutines() throws {
        let env = try TestEnv()
        try env.addRoutines(2, today: monday)
        let (store, _) = makeStore(env, today: monday)
        let archived = try #require(store.routines.last)
        store.setArchived(archived, true)
        #expect(store.routineHistories().map(\.title) == ["루틴 1"])
    }

    // MARK: - 다음 루틴, 알림, 위젯

    @Test func skippedRoutinesAreNotOfferedAsNext() throws {
        let env = try CompanionEnv()
        let first = env.addRoutine("물", time: "07:00")
        env.addRoutine("운동", time: "08:00")
        env.store.setSkipped(routineID: first.id, true)
        let next = try #require(NextCheck.pick(from: env.store.checkSections, nowMinutes: 6 * 60))
        #expect(next.check.title == "운동")
    }

    @Test func skippedRoutinesAreNotNotifiedToday() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동", time: "07:30")
        #expect(env.plan(at: seoulTime(monday, 6)).first?.dateKey == monday.key)

        env.store.setSkipped(routineID: routine.id, true)
        // 오늘 것만 빠지고 내일부터는 그대로 울린다.
        #expect(env.plan(at: seoulTime(monday, 6)).first?.dateKey == monday.adding(days: 1).key)

        env.store.setSkipped(routineID: routine.id, false)
        #expect(env.plan(at: seoulTime(monday, 6)).first?.dateKey == monday.key)
    }

    @Test func widgetSnapshotCarriesTheSkipAndStaysReadableByOlderWidgets() throws {
        let env = try CompanionEnv()
        let first = env.addRoutine("물", time: "07:00")
        env.addRoutine("운동", time: "08:00")
        let plain = WidgetSnapshot.make(days: env.store.upcomingDays(count: 2), hasRoutines: true)
        // 건너뛴 것이 없으면 새 칸을 쓰지 않는다.
        #expect(!String(decoding: try JSONEncoder().encode(plain), as: UTF8.self).contains("isSkipped"))

        env.store.setSkipped(routineID: first.id, true)
        let snapshot = WidgetSnapshot.make(days: env.store.upcomingDays(count: 2), hasRoutines: true)
        let today = try #require(snapshot.days.first)
        #expect(today.items.map(\.isSkipped) == [true, nil])
        #expect(today.items.map(\.isDone) == [false, false])
        #expect((today.done, today.total, today.remaining) == (0, 2, 1))
        #expect(today.nextToShow(nowMinutes: 6 * 60)?.title == "운동")
        // 이 칸을 모르는 위젯도 파일을 읽는다.
        struct OldItem: Codable { var routineID: UUID; var title: String; var timeLabel: String; var isDone: Bool }
        struct OldGroup: Codable { var items: [OldItem] }
        struct OldDay: Codable { var dateKey: String; var groups: [OldGroup] }
        struct OldSnapshot: Codable { var days: [OldDay]; var hasRoutines: Bool }
        let old = try JSONDecoder().decode(OldSnapshot.self, from: try JSONEncoder().encode(snapshot))
        #expect(old.days.first?.groups.first?.items.map(\.isDone) == [false, false])
    }

    /// 위젯에서 건너뛴 항목을 누르면 완료가 된다.
    @Test func aWidgetCheckCompletesASkippedRoutine() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("물", time: "07:00")
        env.store.setSkipped(routineID: routine.id, true)
        try env.store.applyWidgetCheck(
            PendingCheck(dateKey: monday.key, routineID: routine.id, isDone: true, at: .now.addingTimeInterval(5))
        )
        env.store.reloadStats()
        #expect(env.store.checkSections.flatMap(\.checks).map(\.status) == [.done])
    }

    /// 줄의 [✓ | »] 단추: 미완료에서 ✓는 완료·»는 건너뜀, 완료에서 ✓는 취소·»는 건너뜀으로,
    /// 건너뜀에서 »는 취소·✓는 완료로. 둘이 함께 켜지는 일은 없다.
    @Test func rowButtonsMoveBetweenTheThreeStates() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(1, today: monday)
        let (store, _) = makeStore(env, today: monday)
        let id = routines[0].id
        func check() -> CheckValue { store.checkSections.flatMap(\.checks)[0] }
        func tapDone() { RoutineActionButtons.toggleDone(check()) { store.setDone(routineID: id, $0) } }
        func tapSkip() { RoutineActionButtons.toggleSkipped(check()) { store.setSkipped(routineID: id, $0) } }

        #expect(check().status == .pending)
        tapDone()
        #expect(check().status == .done)
        tapDone()
        #expect(check().status == .pending)
        tapSkip()
        #expect(check().status == .skipped)
        tapSkip()
        #expect(check().status == .pending)
        // 완료 → » → 건너뜀, 건너뜀 → ✓ → 완료.
        tapDone()
        tapSkip()
        #expect(check().status == .skipped && !check().isDone)
        tapDone()
        #expect(check().status == .done && !check().isSkipped)
    }

    /// 건너뛴 줄은 회색 "—"와 "건너뜀" 글자로 보이고, ⋯ 메뉴는 미완료면 건너뛰기를, 건너뛴 뒤에는 취소를 준다.
    @Test func skipMarkAndMenuTitles() {
        #expect(SkipStyle.symbol == "minus")
        #expect(SkipStyle.label == "건너뜀")
        #expect(CheckSkipActions.title(isSkipped: false, isToday: true) == "오늘 건너뛰기")
        #expect(CheckSkipActions.title(isSkipped: false, isToday: false) == "이날 건너뛰기")
        #expect(CheckSkipActions.title(isSkipped: true, isToday: true) == "건너뛰기 취소")
    }
}
