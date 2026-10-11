import Foundation
import Testing
@testable import Daylog

/// Phase 2: 어떤 루틴 알림을 예약하는가
@MainActor
struct NotificationPlanTests {
    @Test func schedulesOnlyOnTheRoutinesWeekdaysAtItsTime() throws {
        let env = try CompanionEnv()
        env.addRoutine("헬스장 가기", time: "07:30", weekdays: [1, 3, 5])

        let plan = env.plan(at: seoulTime(monday, 6))
        // 오늘(월)부터 14일: 월·수·금이 여섯 번.
        #expect(plan.map(\.dateKey) == ["2026-10-05", "2026-10-07", "2026-10-09", "2026-10-12", "2026-10-14", "2026-10-16"])
        #expect(plan.allSatisfy { $0.hour == 7 && $0.minute == 30 })
        let first = try #require(plan.first)
        #expect(first.notificationTitle == "Daylog · 루틴 시간이에요")
        #expect(first.notificationBody == "헬스장 가기 — 오늘의 루틴을 완료해 보세요.")
        #expect(first.notificationSubtitle == "07:30 · 아침")
    }

    /// 시간이 없거나 시각으로 읽히지 않는 루틴은 알리지 않는다.
    @Test func skipsRoutinesWithoutAClockTime() throws {
        let env = try CompanionEnv()
        env.addRoutine("일기")
        env.addRoutine("정리", time: "저녁 먹고")
        #expect(env.plan(at: seoulTime(monday, 6)).isEmpty)
    }

    @Test func followsTimeAndNameChanges() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동", time: "07:30")
        let before = try #require(env.plan(at: seoulTime(monday, 6)).first)

        env.store.updateRoutine(routine, title: "아침 운동", timeLabel: "08:15")
        let after = try #require(env.plan(at: seoulTime(monday, 6)).first)
        #expect(after.id == before.id)
        #expect(after.signature != before.signature)
        #expect((after.hour, after.minute) == (8, 15))
        #expect(after.title == "아침 운동")
    }

    @Test func stopsForDeletedAndArchivedRoutines() throws {
        let env = try CompanionEnv()
        let deleted = env.addRoutine("물", time: "07:00")
        let archived = env.addRoutine("운동", time: "08:00")
        #expect(env.plan(at: seoulTime(monday, 6)).count == 28)

        env.store.deleteRoutine(deleted)
        env.store.setArchived(archived, true)
        // 오늘 것은 완료하지 않은 채 목록에서 빠졌고, 내일부터는 예정에도 없다.
        #expect(env.plan(at: seoulTime(monday, 6)).isEmpty)

        env.store.setArchived(archived, false)
        #expect(env.plan(at: seoulTime(monday, 6)).allSatisfy { $0.title == "운동" })
        #expect(env.plan(at: seoulTime(monday, 6)).count == 14)
    }

    /// 완료하면 오늘 것만 빠지고, 체크를 취소하면 시간이 남아 있을 때 다시 들어온다.
    @Test func completingCancelsOnlyTodayAndUncheckingRestoresIt() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동", time: "07:30")

        env.store.setDone(routineID: routine.id, true)
        let afterDone = env.plan(at: seoulTime(monday, 6))
        #expect(!afterDone.contains { $0.dateKey == monday.key })
        #expect(afterDone.count == 13)

        env.store.setDone(routineID: routine.id, false)
        #expect(env.plan(at: seoulTime(monday, 6)).first?.dateKey == monday.key)
        // 예정 시간이 지난 뒤에 취소하면 오늘 것은 다시 예약하지 않는다.
        #expect(env.plan(at: seoulTime(monday, 9)).first?.dateKey == "2026-10-06")
    }

    /// 지난 시각을 예약하지 않는다. 이미 울린 알림이 같은 날 또 울리지 않는 이유다.
    @Test func neverSchedulesAPastTime() throws {
        let env = try CompanionEnv()
        env.addRoutine("운동", time: "07:30")
        let now = seoulTime(monday, 7, 30)
        let plan = env.plan(at: now)
        #expect(plan.first?.dateKey == "2026-10-06")
        #expect(plan.allSatisfy { seoul.date(from: $0.dateComponents)! > now })
    }

    /// 같은 날 같은 루틴은 하나뿐이고, 다시 계산해도 같은 식별자다.
    @Test func identifiersAreUniqueAndStable() throws {
        let env = try CompanionEnv()
        env.addRoutine("물", time: "07:00")
        env.addRoutine("운동", time: "07:00")
        let first = env.plan(at: seoulTime(monday, 6))
        #expect(Set(first.map(\.id)).count == first.count)
        #expect(env.plan(at: seoulTime(monday, 6)) == first)
    }

    /// 시스템 한도(64개)를 넘기지 않고 가까운 것부터 채운다.
    @Test func keepsWithinTheSystemLimitSoonestFirst() throws {
        let env = try CompanionEnv()
        for index in 0..<10 { env.addRoutine("루틴 \(index)", time: String(format: "%02d:00", 8 + index)) }
        let plan = env.plan(at: seoulTime(monday, 6))
        #expect(plan.count == RoutineNotificationPlanner.maxPending)
        #expect(Set(plan.map(\.dateKey)).sorted() == (0..<6).map { monday.adding(days: $0).key })
    }

    /// 같은 순간이라도 기기의 시간대가 바뀌면 "아직 안 지난 시각"이 달라진다.
    @Test func followsTheDeviceTimeZone() throws {
        let env = try CompanionEnv()
        env.addRoutine("운동", time: "07:30")
        let days = env.store.upcomingDays(count: 14)
        let now = seoulTime(monday, 6)
        var honolulu = Calendar(identifier: .gregorian)
        honolulu.timeZone = TimeZone(identifier: "Pacific/Honolulu")!

        #expect(RoutineNotificationPlanner.plan(days: days, now: now, calendar: seoul).first?.dateKey == monday.key)
        // 호놀룰루에서는 10월 5일 07:30이 아직 한참 뒤다. 날짜와 시·분은 그대로 두고 그 기기의 시각으로 울린다.
        let moved = try #require(RoutineNotificationPlanner.plan(days: days, now: now, calendar: honolulu).first)
        #expect((moved.dateKey, moved.hour, moved.minute) == (monday.key, 7, 30))
        #expect(honolulu.date(from: moved.dateComponents)! > seoul.date(from: moved.dateComponents)!)
    }

    /// 자정이 지나면 어제 것은 없고 새 날짜부터 다시 채운다.
    @Test func rollsOverAtMidnight() throws {
        let env = try CompanionEnv()
        env.addRoutine("운동", time: "07:30", weekdays: [1, 3, 5])
        env.clock.today = monday.adding(days: 1)
        env.store.refreshToday()

        let plan = env.plan(at: seoulTime(monday.adding(days: 1), 0, 1))
        #expect(plan.first?.dateKey == "2026-10-07")
        #expect(plan.last?.dateKey == "2026-10-19")
    }

    @Test func mutedRoutinesAreLeftOut() throws {
        let env = try CompanionEnv()
        let muted = env.addRoutine("물", time: "07:00")
        env.addRoutine("운동", time: "08:00")
        let plan = env.plan(at: seoulTime(monday, 6), muted: [muted.id.uuidString])
        #expect(Set(plan.map(\.title)) == ["운동"])
    }
}

/// Phase 2: 예약을 맞추는 일(중복 방지, 권한, 재실행)
@MainActor
struct NotificationScheduleTests {
    private func days(_ env: CompanionEnv) -> [PlannedDay] {
        env.store.upcomingDays(count: RoutineNotificationPlanner.horizonDays)
    }

    /// 앱을 처음 열 때는 권한을 묻지 않고, 사용자가 켤 때 묻는다.
    @Test func asksForPermissionOnlyWhenTurnedOn() async throws {
        let env = try CompanionEnv()
        env.addRoutine("운동", time: "07:30")
        let client = FakeNotificationClient()
        let notifications = RoutineNotifications(client: client, defaults: testDefaults())

        await notifications.reschedule(days: days(env), now: seoulTime(monday, 6), calendar: seoul)
        #expect(client.requests == 0)
        #expect(client.scheduled.isEmpty)
        #expect(!notifications.isEnabled)

        await notifications.setEnabled(true)
        #expect(client.requests == 1)
        await notifications.reschedule(days: days(env), now: seoulTime(monday, 6), calendar: seoul)
        #expect(client.scheduled.count == 14)
        #expect(notifications.scheduledCount == 14)
    }

    /// 몇 번을 맞춰도 같은 알림을 다시 예약하지 않는다.
    @Test func reschedulingTwiceAddsNothingNew() async throws {
        let env = try CompanionEnv()
        env.addRoutine("운동", time: "07:30")
        let client = FakeNotificationClient(status: .authorized)
        let notifications = RoutineNotifications(client: client, defaults: testDefaults())
        await notifications.setEnabled(true)

        await notifications.reschedule(days: days(env), now: seoulTime(monday, 6), calendar: seoul)
        await notifications.reschedule(days: days(env), now: seoulTime(monday, 6), calendar: seoul)
        #expect(client.addCount == 14)
        #expect(client.scheduled.count == 14)
    }

    /// 완료·삭제·시간 변경이 예약에 반영된다.
    @Test func followsChangesToRoutinesAndChecks() async throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동", time: "07:30")
        let client = FakeNotificationClient(status: .authorized)
        let notifications = RoutineNotifications(client: client, defaults: testDefaults())
        await notifications.setEnabled(true)
        let now = seoulTime(monday, 6)
        let todayID = PlannedNotification.id(routineID: routine.id, dateKey: monday.key)
        await notifications.reschedule(days: days(env), now: now, calendar: seoul)
        #expect(client.scheduled[todayID] != nil)

        // 완료 → 오늘 예약이 지워지고, 알림 센터에 남은 알림도 치운다.
        env.store.setDone(routineID: routine.id, true)
        await notifications.reschedule(days: days(env), now: now, calendar: seoul)
        #expect(client.scheduled[todayID] == nil)
        #expect(client.scheduled.count == 13)
        #expect(client.removedDelivered.contains(todayID))

        // 체크 취소 → 다시 예약.
        env.store.setDone(routineID: routine.id, false)
        await notifications.reschedule(days: days(env), now: now, calendar: seoul)
        #expect(client.scheduled[todayID] != nil)

        // 시간 변경 → 같은 식별자가 새 시각으로 바뀐다.
        env.store.updateRoutine(routine, timeLabel: "09:00")
        await notifications.reschedule(days: days(env), now: now, calendar: seoul)
        #expect(client.scheduled.count == 14)
        #expect(client.scheduled.values.allSatisfy { $0.hour == 9 })

        // 삭제 → 모두 취소.
        env.store.deleteRoutine(routine)
        await notifications.reschedule(days: days(env), now: now, calendar: seoul)
        #expect(client.scheduled.isEmpty)
    }

    /// 권한을 거부하면 아무것도 예약하지 않고, 켜고 싶다는 설정과 거부 상태를 함께 알 수 있다.
    @Test func deniedPermissionSchedulesNothing() async throws {
        let env = try CompanionEnv()
        env.addRoutine("운동", time: "07:30")
        let client = FakeNotificationClient()
        client.answer = .denied
        let notifications = RoutineNotifications(client: client, defaults: testDefaults())

        await notifications.setEnabled(true)
        await notifications.reschedule(days: days(env), now: seoulTime(monday, 6), calendar: seoul)
        #expect(notifications.isEnabled)
        #expect(notifications.permission == .denied)
        #expect(!notifications.isActive)
        #expect(client.scheduled.isEmpty)

        // 시스템 설정에서 허용하면 다음에 맞출 때 예약된다.
        client.status = .authorized
        await notifications.reschedule(days: days(env), now: seoulTime(monday, 6), calendar: seoul)
        #expect(client.scheduled.count == 14)
    }

    /// 끄면 예약을 모두 지운다.
    @Test func turningOffRemovesEverything() async throws {
        let env = try CompanionEnv()
        env.addRoutine("운동", time: "07:30")
        let client = FakeNotificationClient(status: .authorized)
        let notifications = RoutineNotifications(client: client, defaults: testDefaults())
        await notifications.setEnabled(true)
        await notifications.reschedule(days: days(env), now: seoulTime(monday, 6), calendar: seoul)

        await notifications.setEnabled(false)
        await notifications.reschedule(days: days(env), now: seoulTime(monday, 6), calendar: seoul)
        #expect(client.scheduled.isEmpty)
    }

    /// 앱을 다시 실행해도 설정과 예약이 그대로고, 다시 예약하지 않는다.
    @Test func settingsAndScheduleSurviveARelaunch() async throws {
        let env = try CompanionEnv()
        let muted = env.addRoutine("물", time: "07:00")
        env.addRoutine("운동", time: "07:30")
        let client = FakeNotificationClient(status: .authorized)
        let defaults = testDefaults()
        let first = RoutineNotifications(client: client, defaults: defaults)
        await first.setEnabled(true)
        first.setMuted(muted.id, true)
        await first.reschedule(days: days(env), now: seoulTime(monday, 6), calendar: seoul)
        let added = client.addCount
        #expect(client.scheduled.count == 14)

        let relaunched = RoutineNotifications(client: client, defaults: defaults)
        #expect(relaunched.isEnabled)
        #expect(relaunched.isMuted(muted.id))
        await relaunched.reschedule(days: days(env), now: seoulTime(monday, 6), calendar: seoul)
        #expect(client.addCount == added)
        #expect(client.scheduled.count == 14)
    }
}

/// Phase 2: 알림의 [완료]·[나중에]
@MainActor
struct NotificationActionTests {
    private func runtime(_ env: CompanionEnv) -> AppRuntime {
        AppRuntime(
            store: env.store,
            notifications: RoutineNotifications(client: FakeNotificationClient(), defaults: testDefaults()),
            bridge: nil, defaults: testDefaults()
        )
    }

    @Test func completeMarksThatRoutineDone() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동", time: "07:30")
        env.addRoutine("물", time: "08:00")
        let runtime = runtime(env)

        runtime.handleNotification(action: RoutineNotificationAction.complete, routineID: routine.id, dateKey: monday.key)
        #expect(env.store.todaySections.flatMap(\.checks).filter(\.isDone).map(\.title) == ["운동"])
        #expect(env.store.stats.today.done == 1)
        #expect(env.store.todaySections.first?.done == 1)
    }

    /// 이미 완료한 루틴을 또 완료해도 기록이 늘지 않는다.
    @Test func completingTwiceCreatesNoDuplicates() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동", time: "07:30")
        let runtime = runtime(env)

        for _ in 0..<2 {
            runtime.handleNotification(action: RoutineNotificationAction.complete, routineID: routine.id, dateKey: monday.key)
        }
        #expect(try env.env.records.physicalRecords(on: monday).count == 1)
        let record = try #require(try env.env.records.record(on: monday))
        #expect(record.checkList.filter { $0.routineID == routine.id }.count == 1)
        #expect(record.checkList.first?.isDone == true)
        #expect(try FieldEditService(context: env.env.context, deviceID: "iphone")
            .entries(dateKey: monday.key, fieldName: CheckEdit.fieldName(routine.id)).count == 1)
    }

    /// 다른 날짜를 보고 있어도 알림이 가리키는 날짜의 루틴이 완료된다.
    @Test func completeWorksWhileViewingAnotherDay() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동", time: "07:30")
        env.clock.today = monday.adding(days: 1)
        env.store.refreshToday()
        env.store.select(monday)
        let runtime = runtime(env)
        let tuesday = monday.adding(days: 1)

        runtime.handleNotification(action: RoutineNotificationAction.complete, routineID: routine.id, dateKey: tuesday.key)
        #expect(env.store.selectedDay == monday)
        #expect(env.store.checkSections.flatMap(\.checks).allSatisfy { !$0.isDone })
        #expect(env.store.todaySections.flatMap(\.checks).allSatisfy { $0.isDone })
    }

    /// [나중에]는 아무것도 바꾸지 않는다.
    @Test func laterChangesNothing() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동", time: "07:30")
        runtime(env).handleNotification(action: RoutineNotificationAction.later, routineID: routine.id, dateKey: monday.key)
        #expect(env.store.todaySections.flatMap(\.checks).allSatisfy { !$0.isDone })
    }

    /// 알림 자체를 누르면 그 날짜의 오늘 화면으로 간다.
    @Test func tappingTheNotificationOpensThatDay() throws {
        let env = try CompanionEnv()
        let routine = env.addRoutine("운동", time: "07:30")
        env.clock.today = monday.adding(days: 2)
        env.store.refreshToday()
        env.store.section = .statistics

        runtime(env).handleNotification(
            action: "com.apple.UNNotificationDefaultActionIdentifier", routineID: routine.id, dateKey: monday.adding(days: 1).key
        )
        #expect(env.store.section == .dashboard)
        #expect(env.store.selectedDay == monday.adding(days: 1))
    }
}
