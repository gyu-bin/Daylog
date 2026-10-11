import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 알림 센터를 흉내 낸다. 예약한 것을 기억하고, 몇 번 예약·삭제·권한 요청했는지 센다.
@MainActor
final class FakeNotificationClient: NotificationClient {
    var status: NotificationPermission
    /// 권한을 물었을 때 사용자가 고르는 답.
    var answer: NotificationPermission = .authorized
    private(set) var requests = 0
    private(set) var scheduled: [String: PlannedNotification] = [:]
    private(set) var addCount = 0
    private(set) var removedDelivered: [String] = []

    init(status: NotificationPermission = .notDetermined) {
        self.status = status
    }

    func permission() async -> NotificationPermission { status }

    func requestPermission() async -> NotificationPermission {
        guard status == .notDetermined else { return status }
        requests += 1
        status = answer
        return status
    }

    func pending() async -> [String: String] { scheduled.mapValues(\.signature) }

    func add(_ notification: PlannedNotification) async throws {
        addCount += 1
        scheduled[notification.id] = notification
    }

    func removePending(ids: [String]) {
        for id in ids { scheduled[id] = nil }
    }

    func removeDelivered(ids: [String]) {
        removedDelivered.append(contentsOf: ids)
    }
}

/// 2026-10-05(월)의 한국 시각.
let seoul: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return calendar
}()

func seoulTime(_ day: Day, _ hour: Int, _ minute: Int = 0) -> Date {
    seoul.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute))!
}

func testDefaults() -> UserDefaults {
    UserDefaults(suiteName: "daylog-tests-\(UUID().uuidString)")!
}

@MainActor
struct CompanionEnv {
    let env: TestEnv
    let clock: TestClock
    let store: AppStore

    init(today: Day = monday) throws {
        env = try TestEnv()
        clock = TestClock(today)
        let clock = clock
        store = AppStore(container: env.container, deviceID: "iphone", clock: { clock.today })
        store.start()
    }

    /// 그룹 하나에 시간이 있는 루틴을 만든다.
    @discardableResult
    func addRoutine(_ title: String, time: String = "", weekdays: [Int] = Weekdays.all, group: String = "아침") -> RoutineItem {
        let target = store.groups.first { $0.title == group } ?? store.addGroup(title: group)
        store.addRoutine(title: title, in: target)
        let routine = store.routines.first { $0.title == title }!
        store.updateRoutine(routine, timeLabel: time, weekdays: weekdays)
        return routine
    }

    func plan(at now: Date, muted: Set<String> = []) -> [PlannedNotification] {
        RoutineNotificationPlanner.plan(
            days: store.upcomingDays(count: RoutineNotificationPlanner.horizonDays), now: now, calendar: seoul, muted: muted
        )
    }
}
