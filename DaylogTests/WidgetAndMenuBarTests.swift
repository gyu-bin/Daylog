import Foundation
import Testing
@testable import Daylog

/// Phase 2: 위젯이 그리는 값
@MainActor
struct WidgetSnapshotTests {
    private func snapshot(_ env: CompanionEnv) -> WidgetSnapshot {
        WidgetSnapshot.make(days: env.store.upcomingDays(count: 14), hasRoutines: !env.store.activeRoutines.isEmpty)
    }

    /// 작은 위젯: 달성률, 완료/전체, 다음 루틴과 시간.
    @Test func smallShowsProgressAndTheNextRoutine() throws {
        let env = try CompanionEnv()
        let water = env.addRoutine("물", time: "07:00")
        env.addRoutine("운동", time: "07:30")
        env.addRoutine("일기")
        env.store.setDone(routineID: water.id, true)

        let today = try #require(snapshot(env).day(monday.key))
        #expect((today.done, today.total, today.percent) == (1, 3, 33))
        #expect(today.nextToShow(nowMinutes: 6 * 60)?.title == "운동")
        // 시간이 있는 것이 다 끝나면 아직 안 한 항목을 보여 준다.
        let after = today.applying([PendingCheck(dateKey: monday.key, routineID: today.items[1].routineID, isDone: true, at: .now)])
        #expect(after.nextToShow(nowMinutes: 6 * 60)?.title == "일기")
        // 모두 끝나면 보여 줄 다음 항목이 없다("오늘 루틴 완료").
        let allDone = after.applying([PendingCheck(dateKey: monday.key, routineID: today.items[2].routineID, isDone: true, at: .now)])
        #expect(allDone.done == allDone.total)
        #expect(allDone.nextToShow(nowMinutes: 6 * 60) == nil)
    }

    /// 중간 위젯: 그룹별 진행률이 앱과 같은 규칙으로 계산된다.
    @Test func mediumShowsProgressPerGroup() throws {
        let env = try CompanionEnv()
        let water = env.addRoutine("물", group: "아침")
        env.addRoutine("운동", group: "아침")
        env.addRoutine("일기", group: "저녁")
        env.store.setDone(routineID: water.id, true)

        let today = try #require(snapshot(env).day(monday.key))
        #expect(today.groups.map(\.title) == ["아침", "저녁"])
        #expect(today.groups.map(\.done) == [1, 0])
        #expect(today.groups.map(\.ratio) == [0.5, 0])
        #expect(today.groups.map(\.colorKey) == env.store.todaySections.map(\.group.colorKey))
    }

    /// 큰 위젯: 들어갈 만큼만 담고 나머지 개수를 알린다.
    @Test func largeListsRoutinesWithinTheRowLimit() throws {
        let env = try CompanionEnv()
        for index in 1...6 { env.addRoutine("아침 \(index)", group: "아침") }
        for index in 1...5 { env.addRoutine("저녁 \(index)", group: "저녁") }
        let today = try #require(snapshot(env).day(monday.key))

        let all = WidgetRows.fit(today, limit: 20)
        #expect(all.rows.count == 13)
        #expect(all.hiddenItems == 0)

        let fitted = WidgetRows.fit(today, limit: 9)
        #expect(fitted.rows.count == 9)
        #expect(fitted.hiddenItems == 4)
        // 머리말만 남는 그룹은 넣지 않는다.
        let tight = WidgetRows.fit(today, limit: 8)
        #expect(tight.rows.count == 7)
        #expect(tight.hiddenItems == 5)
    }

    /// 루틴이 없는 날과 루틴이 아예 없는 경우를 구분한다. 내일부터는 지금의 루틴 설정으로 채운다.
    @Test func coversRestDaysAndTheComingWeek() throws {
        let env = try CompanionEnv()
        #expect(!snapshot(env).hasRoutines)
        env.addRoutine("운동", time: "07:30", weekdays: [2])

        let filled = snapshot(env)
        #expect(filled.hasRoutines)
        #expect(filled.days.count == WidgetSnapshot.dayCount)
        #expect(try #require(filled.day(monday.key)).total == 0)
        #expect(try #require(filled.day(monday.key)).percent == nil)
        let tuesday = try #require(filled.day("2026-10-06"))
        #expect(tuesday.items.map(\.title) == ["운동"])
        #expect(tuesday.items.allSatisfy { !$0.isDone })
        #expect(filled.day("2026-10-12") == nil)
    }
}

/// Phase 2: 위젯에서 누른 체크를 저장소에 반영하기
@MainActor
struct WidgetCheckTests {
    private func pending(_ routine: RoutineItem, _ isDone: Bool, at date: Date, day: Day = monday) -> PendingCheck {
        PendingCheck(dateKey: day.key, routineID: routine.id, isDone: isDone, at: date)
    }

    @Test func checksAndUnchecks() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동")
        let start = Date.now

        env.store.applyWidgetChecks([pending(routine, true, at: start.addingTimeInterval(1))])
        #expect(env.store.todaySections.flatMap(\.checks).map(\.isDone) == [true])
        #expect(env.store.stats.today.done == 1)

        env.store.applyWidgetChecks([pending(routine, false, at: start.addingTimeInterval(2))])
        #expect(env.store.todaySections.flatMap(\.checks).map(\.isDone) == [false])
        #expect(env.store.stats.today.done == 0)
    }

    /// 같은 날짜의 기록과 같은 루틴의 체크가 늘지 않는다.
    @Test func neverDuplicatesRecordsOrChecks() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동")
        let start = Date.now
        let taps = (1...4).map { pending(routine, $0 % 2 == 1, at: start.addingTimeInterval(Double($0))) }

        env.store.applyWidgetChecks(taps)
        #expect(try env.env.records.physicalRecords(on: monday).count == 1)
        let record = try #require(try env.env.records.record(on: monday))
        #expect(record.checkList.count == 1)
        #expect(record.checkList.first?.isDone == false)
        // 저장된 값은 새 컨텍스트(앱을 다시 실행한 것)에서도 같다.
        let reopened = try #require(try DayRecordService(context: env.env.freshContext()).record(on: monday))
        #expect(reopened.checkList.map(\.isDone) == [false])
    }

    /// 한 번 반영한 요청은 다시 들어와도 건너뛴다.
    @Test func appliedRequestsAreNotReplayed() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동")
        let tap = pending(routine, true, at: .now.addingTimeInterval(1))

        let watermark = env.store.applyWidgetChecks([tap])
        env.store.setDone(routineID: routine.id, on: monday, false, at: .now.addingTimeInterval(5))
        env.store.applyWidgetChecks([tap], after: watermark)
        #expect(env.store.todaySections.flatMap(\.checks).map(\.isDone) == [false])
    }

    /// 위젯에서 누른 뒤에 앱(또는 다른 기기)에서 더 나중에 정한 값이 있으면 그 값을 따른다.
    @Test func aNewerDecisionWins() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동")
        let tapped = Date.now.addingTimeInterval(-60)

        env.store.setDone(routineID: routine.id, true)
        env.store.setDone(routineID: routine.id, false)
        env.store.applyWidgetChecks([pending(routine, true, at: tapped)])
        #expect(env.store.todaySections.flatMap(\.checks).map(\.isDone) == [false])
    }

    /// 미래 날짜의 기록은 만들지 않는다. 모르는 루틴도 무시한다.
    @Test func ignoresFutureDaysAndUnknownRoutines() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동")
        let tomorrow = monday.adding(days: 1)

        env.store.applyWidgetChecks([
            pending(routine, true, at: .now.addingTimeInterval(1), day: tomorrow),
            PendingCheck(dateKey: monday.key, routineID: UUID(), isDone: true, at: .now.addingTimeInterval(2)),
        ])
        #expect(try env.env.records.physicalRecords(on: tomorrow).isEmpty)
        #expect(env.store.todaySections.flatMap(\.checks).map(\.isDone) == [false])
        #expect(env.store.errorMessage == nil)
    }

    /// 앱과 위젯이 주고받는 파일.
    @Test func bridgeKeepsSnapshotAndQueue() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DaylogBridge-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let bridge = WidgetBridge(directory: directory)
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동", time: "07:30")
        let snapshot = WidgetSnapshot.make(days: env.store.upcomingDays(count: 14), hasRoutines: true)

        #expect(bridge.readSnapshot() == nil)
        #expect(try bridge.writeSnapshot(snapshot))
        // 내용이 같으면 다시 쓰지 않는다(위젯을 괜히 새로 그리지 않는다).
        #expect(try !bridge.writeSnapshot(snapshot))
        #expect(bridge.readSnapshot() == snapshot)

        try bridge.appendPending(pending(routine, true, at: Date(timeIntervalSinceReferenceDate: 10)))
        try bridge.appendPending(pending(routine, false, at: Date(timeIntervalSinceReferenceDate: 20)))
        // 위젯은 반영 전의 요청을 겹쳐서 보여 준다: 같은 항목에는 가장 나중 것.
        let shown = try #require(snapshot.day(monday.key)).applying(bridge.readPending())
        #expect(shown.items.map(\.isDone) == [false])
        #expect(bridge.takePending().map(\.isDone) == [true, false])
        #expect(bridge.readPending().isEmpty)
        #expect(bridge.takePending().isEmpty)
    }

    /// 앱이 켜질 때 대기열을 반영하고 위젯용 데이터를 새로 적는다.
    @Test func runtimeDrainsTheQueueIntoTheStore() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DaylogBridge-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let bridge = WidgetBridge(directory: directory)
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동", time: "07:30")
        let runtime = AppRuntime(
            store: env.store,
            notifications: RoutineNotifications(client: FakeNotificationClient(), defaults: testDefaults()),
            bridge: bridge, defaults: testDefaults()
        )
        await runtime.refreshNow()
        #expect(bridge.readSnapshot()?.day(monday.key)?.done == 0)

        try bridge.appendPending(pending(routine, true, at: .now.addingTimeInterval(1)))
        runtime.drainWidgetChecks()
        await runtime.refreshNow()
        #expect(env.store.todaySections.flatMap(\.checks).map(\.isDone) == [true])
        #expect(bridge.readPending().isEmpty)
        #expect(bridge.readSnapshot()?.day(monday.key)?.done == 1)
    }
}

/// Phase 2: 메뉴 막대의 빠른 체크(보고 있는 날짜와 상관없이 오늘을 다룬다)
@MainActor
struct MenuBarTests {
    @Test func showsTodayEvenWhenAnotherDayIsOpen() throws {
        let env = try CompanionEnv()
        env.addRoutine("물", group: "아침")
        env.addRoutine("일기", group: "저녁")
        env.clock.today = monday.adding(days: 1)
        env.store.refreshToday()
        env.store.select(monday)

        #expect(env.store.selectedDay == monday)
        #expect(env.store.todaySections.map(\.group.title) == ["아침", "저녁"])
        #expect(env.store.todaySections.flatMap(\.checks).count == 2)
    }

    /// 체크와 취소가 저장되고, 대시보드가 읽는 값(통계, 그룹 달성률)이 바로 바뀐다.
    @Test func checkingAndUncheckingUpdatesTheDashboard() throws {
        let env = try CompanionEnv()
        let water = env.addRoutine("물", group: "아침")
        env.addRoutine("운동", group: "아침")

        env.store.setDone(routineID: water.id, on: env.store.today, true)
        #expect(env.store.checkSections.first?.done == 1)
        #expect(env.store.stats.today.done == 1)
        #expect(env.store.todaySections.first?.percent == 50)
        let saved = try #require(try DayRecordService(context: env.env.freshContext()).record(on: monday))
        #expect(saved.checkList.filter(\.isDone).map(\.title) == ["물"])

        env.store.setDone(routineID: water.id, on: env.store.today, false)
        #expect(env.store.checkSections.first?.done == 0)
        #expect(env.store.stats.today.done == 0)
    }

    /// 지난 날짜를 보고 있을 때 메뉴 막대에서 오늘을 체크해도 보고 있는 날짜는 그대로다.
    @Test func checkingTodayLeavesTheOpenDayAlone() throws {
        let env = try CompanionEnv()
        let water = env.addRoutine("물")
        env.clock.today = monday.adding(days: 1)
        env.store.refreshToday()
        env.store.select(monday)

        env.store.setDone(routineID: water.id, on: env.store.today, true)
        #expect(env.store.checkSections.flatMap(\.checks).map(\.isDone) == [false])
        #expect(env.store.todaySections.flatMap(\.checks).map(\.isDone) == [true])
        #expect(env.store.stats.today.done == 1)
    }

    /// 미래 날짜는 체크하지 않는다.
    @Test func refusesFutureDays() throws {
        let env = try CompanionEnv()
        let water = env.addRoutine("물")
        env.store.setDone(routineID: water.id, on: monday.adding(days: 1), true)
        #expect(try env.env.records.physicalRecords(on: monday.adding(days: 1)).isEmpty)
        #expect(env.store.errorMessage == nil)
    }

    /// 메뉴 막대는 기본으로 켜져 있다.
    @Test func menuBarIsOnByDefault() {
        #expect(UserDefaults(suiteName: "daylog-tests-\(UUID().uuidString)")!.object(forKey: MenuBarSettings.key) == nil)
        #expect(MenuBarSettings.key == "showsMenuBarExtra")
    }
}
