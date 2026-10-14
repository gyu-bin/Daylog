import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 루틴 알림과 복귀 알림을 한 알림 센터에 함께 예약한다(서로 지우지 않는지 보려고).
@MainActor
private final class SharedCenter: NotificationClient, ComebackNotificationClient {
    var status: NotificationPermission
    var answer: NotificationPermission = .authorized
    private(set) var requests = 0
    private(set) var pendingIDs: [String: String] = [:]
    private(set) var comebackAdds = 0

    init(status: NotificationPermission = .notDetermined) { self.status = status }

    func permission() async -> NotificationPermission { status }
    func requestPermission() async -> NotificationPermission {
        guard status == .notDetermined else { return status }
        requests += 1
        status = answer
        return status
    }
    func pending() async -> [String: String] { pendingIDs.filter { $0.key.hasPrefix(PlannedNotification.idPrefix) } }
    func add(_ notification: PlannedNotification) async throws { pendingIDs[notification.id] = notification.signature }
    func pendingComebacks() async -> [String: String] { pendingIDs.filter { $0.key.hasPrefix(PlannedComeback.idPrefix) } }
    func addComeback(_ comeback: PlannedComeback) async throws {
        comebackAdds += 1
        pendingIDs[comeback.id] = comeback.signature
    }
    func removePending(ids: [String]) { for id in ids { pendingIDs[id] = nil } }
    func removeDelivered(ids: [String]) {}
}

/// 새싹이 복귀 알림: 3·7·14·30일째 계산, 휴가·루틴 없는 날, 예약·취소, 루틴 알림 보존, 기록이 바뀔 때의 다시 계산.
@MainActor
struct ComebackNotificationTests {
    private let evening = 19 * 60

    private func input(
        last: Day?, today: Day, vacation: ClosedRange<Day>? = nil, scheduled: ((Day) -> Bool)? = nil,
        routines: Bool = true, current: Bool = true
    ) -> ComebackInput {
        ComebackInput(
            lastCompletion: last, today: today, hasActiveRoutines: routines,
            isVacation: { day in vacation?.contains(day) ?? false },
            isScheduled: scheduled ?? { _ in true }, dataIsCurrent: current
        )
    }

    private func plan(_ input: ComebackInput, now: Date, calendar: Calendar = seoul) -> [(Int, String)] {
        ComebackPlanner.plan(input, now: now, calendar: calendar, minutes: evening).map { ($0.stage.rawValue, $0.day.key) }
    }

    // MARK: - 며칠째

    @Test func stagesFallOnTheThirdSeventhFourteenthAndThirtiethDay() {
        let result = plan(input(last: monday, today: monday), now: seoulTime(monday, 9))
        #expect(result.map(\.0) == [3, 7, 14, 30])
        #expect(result.map(\.1) == ["2026-10-08", "2026-10-12", "2026-10-19", "2026-11-04"])
        // 늦은 밤에 계산해도 달력 날짜로 센다.
        #expect(plan(input(last: monday, today: monday), now: seoulTime(monday, 23, 50)).first?.1 == "2026-10-08")
        // 30일째 뒤로는 보내지 않는다.
        #expect(plan(input(last: monday, today: day("2026-11-05")), now: seoulTime(day("2026-11-05"), 9)).isEmpty)
    }

    @Test func passedStagesAreNotScheduledAndTodayDependsOnTheTime() {
        let today = day("2026-10-13")
        #expect(plan(input(last: monday, today: today), now: seoulTime(today, 9)).map(\.0) == [14, 30])
        // 7일째 당일: 알림 시각 전이면 오늘 저녁에, 지났으면 건너뛴다.
        let seventh = day("2026-10-12")
        #expect(plan(input(last: monday, today: seventh), now: seoulTime(seventh, 18)).first! == (7, "2026-10-12"))
        #expect(plan(input(last: monday, today: seventh), now: seoulTime(seventh, 20)).first?.0 == 14)
    }

    @Test func completingAgainStartsOver() {
        let today = day("2026-10-20")
        #expect(plan(input(last: today, today: today), now: seoulTime(today, 9)).first! == (3, "2026-10-23"))
    }

    @Test func vacationDaysAreNotRestDaysAndTheCountRestartsAfter() {
        // 화요일까지 하고 수~토 휴가: 휴가가 끝난 토요일부터 센다.
        let result = plan(input(last: day("2026-10-06"), today: monday, vacation: day("2026-10-07")...day("2026-10-10")), now: seoulTime(monday, 9))
        #expect(result.first! == (3, "2026-10-13"))
        #expect(result.map(\.0) == [3, 7, 14, 30])
        // 휴가 중에는 알리지 않는다.
        let during = plan(input(last: monday, today: day("2026-10-08"), vacation: day("2026-10-07")...day("2026-10-20")), now: seoulTime(day("2026-10-08"), 9))
        #expect(during.first! == (3, "2026-10-23"))
        #expect(!during.contains { (day("2026-10-07")...day("2026-10-20")).contains(day($0.1)) })
    }

    @Test func daysWithoutRoutinesAreSkippedNotCountedAgainstTheUser() {
        // 월요일에만 루틴이 있다: 3일째(목)는 다음 월요일로 미루는데 그날이 7일째라 7일째 알림만 보낸다.
        let mondaysOnly: (Day) -> Bool = { $0.weekday == 1 }   // 1 = 월요일
        let result = plan(input(last: monday, today: monday, scheduled: mondaysOnly), now: seoulTime(monday, 9))
        #expect(result.map(\.0) == [7, 14, 30])
        #expect(result.map(\.1) == ["2026-10-12", "2026-10-19", "2026-11-09"])
    }

    @Test func nothingIsScheduledWithoutCompletionsRoutinesOrFreshData() {
        #expect(plan(input(last: nil, today: monday), now: seoulTime(monday, 9)).isEmpty)
        #expect(plan(input(last: monday, today: monday, routines: false), now: seoulTime(monday, 9)).isEmpty)
        #expect(plan(input(last: monday, today: monday, current: false), now: seoulTime(monday, 9)).isEmpty)
    }

    @Test func fireTimeIsLocalWallClockAcrossDaylightSavingChanges() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        // 11월 1일에 서머타임이 끝난다. 30일째(11/4) 알림도 그곳 시각으로 저녁 7시다.
        let now = try #require(newYork.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 9)))
        let planned = ComebackPlanner.plan(input(last: monday, today: monday), now: now, calendar: newYork, minutes: evening)
        let last = try #require(planned.last)
        #expect(last.day.key == "2026-11-04")
        let fire = try #require(newYork.date(from: last.dateComponents))
        #expect(newYork.component(.hour, from: fire) == 19)
    }

    @Test func freshDataRuleWaitsForTheFirstImport() {
        func current(_ sync: Bool, _ account: CloudSyncMonitor.Account, imported: Bool, importing: Bool = false, gate: Bool = false) -> Bool {
            ComebackPlanner.isDataCurrent(
                syncEnabled: sync, account: account, lastImportAt: imported ? .now : nil, isImporting: importing, firstSyncActive: gate
            )
        }
        #expect(current(false, .notConfigured, imported: false))
        #expect(current(true, .noAccount, imported: false))
        #expect(!current(true, .checking, imported: false))
        #expect(!current(true, .available, imported: false))
        #expect(!current(true, .available, imported: true, importing: true))
        #expect(current(true, .available, imported: true))
        #expect(!current(true, .temporarilyUnavailable, imported: true))
        #expect(!current(true, .available, imported: true, gate: true))
    }

    // MARK: - 예약과 취소

    @Test func offByDefaultAndScheduledOnlyAfterTurningOnWithPermission() async {
        let center = SharedCenter(status: .notDetermined)
        let comeback = ComebackNotifications(client: center, defaults: testDefaults())
        #expect(!comeback.isEnabled && comeback.minutes == evening)
        await comeback.reschedule(input(last: monday, today: monday), now: seoulTime(monday, 9), calendar: seoul)
        #expect(center.pendingIDs.isEmpty && center.requests == 0)

        // 권한을 거부하면 켜도 예약하지 않는다.
        center.answer = .denied
        await comeback.setEnabled(true)
        #expect(center.requests == 1 && comeback.isEnabled && !comeback.isActive)
        await comeback.reschedule(input(last: monday, today: monday), now: seoulTime(monday, 9), calendar: seoul)
        #expect(center.pendingIDs.isEmpty)
    }

    @Test func reschedulingIsIdempotentAndLeavesRoutineNotificationsAlone() async throws {
        let center = SharedCenter(status: .authorized)
        let routine = PlannedNotification(
            routineID: UUID(), dateKey: "2026-10-06", title: "물", timeLabel: "08:00", groupTitle: "아침",
            year: 2026, month: 10, day: 6, hour: 8, minute: 0
        )
        try await center.add(routine)
        let comeback = ComebackNotifications(client: center, defaults: testDefaults())
        await comeback.setEnabled(true)
        let now = seoulTime(monday, 9)
        await comeback.reschedule(input(last: monday, today: monday), now: now, calendar: seoul)
        await comeback.reschedule(input(last: monday, today: monday), now: now, calendar: seoul)
        // 앱을 다시 켠 것처럼 새로 만들어도 같은 단계를 다시 쌓지 않는다.
        let relaunched = ComebackNotifications(client: center, defaults: testDefaults())
        await relaunched.setEnabled(true)
        await relaunched.reschedule(input(last: monday, today: monday), now: now, calendar: seoul)
        #expect(center.comebackAdds == 4)
        #expect(Set(center.pendingIDs.keys) == Set(["comeback.3", "comeback.7", "comeback.14", "comeback.30", routine.id]))
        #expect(relaunched.scheduled.map(\.stage) == [.day3, .day7, .day14, .day30])

        // 완료하면 그날부터 다시 센다(같은 식별자를 새 날짜로 바꾼다).
        await relaunched.reschedule(input(last: day("2026-10-07"), today: day("2026-10-07")), now: seoulTime(day("2026-10-07"), 9), calendar: seoul)
        #expect(relaunched.scheduled.first?.day == day("2026-10-10"))
        #expect(center.pendingIDs["comeback.3"] == "2026-10-10 19:0")

        // 기록을 아직 받아 오지 못한 상태면 있던 복귀 알림도 치운다(루틴 알림은 그대로).
        await relaunched.reschedule(input(last: monday, today: monday, current: false), now: now, calendar: seoul)
        #expect(relaunched.isWaitingForSync && relaunched.scheduled.isEmpty)
        #expect(Set(center.pendingIDs.keys) == [routine.id])

        // 끄면 복귀 알림만 모두 지운다.
        await relaunched.reschedule(input(last: monday, today: monday), now: now, calendar: seoul)
        await relaunched.setEnabled(false)
        await relaunched.reschedule(input(last: monday, today: monday), now: now, calendar: seoul)
        #expect(Set(center.pendingIDs.keys) == [routine.id])
    }

    // MARK: - 기록에서

    @Test func inputFollowsCompletionsUndoSyncAndVacations() throws {
        let env = try TestEnv()
        let routines = try env.addRoutines(2, today: monday)
        try env.log(day("2026-10-06"), done: 1)
        let today = day("2026-10-10")
        let clock = TestClock(today)
        let store = AppStore(container: env.container, clock: { clock.today })
        store.start()
        func input() -> ComebackInput { store.comebackInput(days: store.upcomingDays(count: 40), dataIsCurrent: true) }
        #expect(input().lastCompletion == day("2026-10-06") && input().hasActiveRoutines)

        // 오늘 완료하면 오늘부터, 취소하면 다시 앞의 날부터.
        store.setDone(routineID: routines[0].id, true)
        #expect(input().lastCompletion == today)
        store.setDone(routineID: routines[0].id, false)
        #expect(input().lastCompletion == day("2026-10-06"))
        // 건너뛰기는 완료가 아니다.
        store.setSkipped(routineID: routines[1].id, true)
        #expect(input().lastCompletion == day("2026-10-06"))

        // 다른 기기에서 완료한 기록이 iCloud로 들어오면 그 날부터 센다.
        let remote = DayRecord(day: day("2026-10-08"))
        env.context.insert(remote)
        for routine in routines {
            let check = DayCheck(routine: routine)
            check.isDone = routine.id == routines[1].id
            remote.attach(check)
        }
        try env.context.save()
        store.handleExternalChanges()
        #expect(input().lastCompletion == day("2026-10-08"))

        // 휴가와 루틴이 있는 날은 기존 정책 그대로다.
        #expect(store.saveVacation(start: day("2026-10-12"), end: day("2026-10-14")))
        #expect(input().isVacation(day("2026-10-13")) && !input().isVacation(day("2026-10-15")))
        #expect(input().isScheduled(day("2026-10-15")))
    }
    @Test func runtimeRefreshMovesTheScheduleWhenAnotherDeviceCompletes() async throws {
        let today = Day.today()
        let env = try TestEnv()
        let routines = try env.addRoutines(1, today: today.adding(days: -10))
        try env.log(today.adding(days: -5), done: 1)
        let clock = TestClock(today)
        let store = AppStore(container: env.container, clock: { clock.today })
        store.start()
        let center = SharedCenter(status: .authorized)
        let comeback = ComebackNotifications(client: center, defaults: testDefaults())
        await comeback.setEnabled(true)
        let runtime = AppRuntime(
            store: store, notifications: RoutineNotifications(client: center, defaults: testDefaults()), comeback: comeback, bridge: nil
        )
        var current = false
        runtime.isDataCurrent = { current }

        // iCloud에서 아직 받아 오지 못했으면 예약하지 않는다.
        await runtime.refreshNow()
        #expect(comeback.isWaitingForSync && center.pendingIDs.keys.filter { $0.hasPrefix("comeback.") }.isEmpty)

        // 받아 온 뒤: 5일 전 완료 기준으로 7일째(이틀 뒤)부터.
        current = true
        await runtime.refreshNow()
        #expect(comeback.scheduled.first?.stage == .day7 && comeback.scheduled.first?.day == today.adding(days: 2))

        // 다른 기기에서 오늘 완료한 기록이 동기화로 들어왔다: 오늘부터 다시 센다.
        let remote = DayRecord(day: today)
        env.context.insert(remote)
        let check = DayCheck(routine: routines[0])
        check.isDone = true
        remote.attach(check)
        try env.context.save()
        store.handleExternalChanges()
        await runtime.refreshNow()
        #expect(comeback.scheduled.first?.stage == .day3 && comeback.scheduled.first?.day == today.adding(days: 3))
        #expect(center.pendingIDs.keys.filter { $0.hasPrefix("comeback.") }.count == 4)
    }
}
