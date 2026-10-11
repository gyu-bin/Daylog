import Foundation
import Observation

/// 루틴 알림의 설정과 예약. 설정은 이 기기에만 저장하고(UserDefaults) 동기화하지 않는다.
@MainActor
@Observable
final class RoutineNotifications {
    static let enabledKey = "routineNotificationsEnabled"
    static let mutedKey = "mutedRoutineNotificationIDs"

    private(set) var permission: NotificationPermission = .unknown
    /// 사용자가 이 기기에서 루틴 알림을 켰는가. 기본은 꺼짐(켜는 순간에 권한을 묻는다).
    private(set) var isEnabled: Bool
    /// 알림을 끈 루틴. 여기에 없는 루틴(새로 만든 루틴 포함)은 켜져 있다.
    private(set) var mutedRoutineIDs: Set<String>
    /// 마지막으로 맞춘 뒤 예약되어 있는 알림 수.
    private(set) var scheduledCount = 0

    @ObservationIgnored private let client: NotificationClient
    @ObservationIgnored private let defaults: UserDefaults

    init(client: NotificationClient, defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        mutedRoutineIDs = Set(defaults.stringArray(forKey: Self.mutedKey) ?? [])
    }

    /// 켜져 있고 권한도 있어야 실제로 울린다.
    var isActive: Bool { isEnabled && permission == .authorized }

    func isMuted(_ routineID: UUID) -> Bool {
        mutedRoutineIDs.contains(routineID.uuidString)
    }

    func refreshPermission() async {
        let updated = await client.permission()
        if updated != permission { permission = updated }
    }

    /// 켤 때 처음이면 시스템 권한을 묻는다. 거부되어 있어도 "켜고 싶다"는 설정은 남겨서,
    /// 사용자가 시스템 설정에서 허용하면 바로 울리게 한다(그동안은 화면에서 꺼져 있다고 안내한다).
    func setEnabled(_ enabled: Bool) async {
        if enabled {
            permission = await client.requestPermission()
        }
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
    }

    func setMuted(_ routineID: UUID, _ muted: Bool) {
        if muted {
            mutedRoutineIDs.insert(routineID.uuidString)
        } else {
            mutedRoutineIDs.remove(routineID.uuidString)
        }
        defaults.set(mutedRoutineIDs.sorted(), forKey: Self.mutedKey)
    }

    /// 예약을 지금의 루틴·완료 상태·설정에 맞춘다. 몇 번을 불러도 결과가 같다(중복 예약 없음).
    func reschedule(days: [PlannedDay], now: Date = .now, calendar: Calendar = .current) async {
        await refreshPermission()
        let plan = isActive
            ? RoutineNotificationPlanner.plan(days: days, now: now, calendar: calendar, muted: mutedRoutineIDs)
            : []
        let pending = await client.pending()
        let wanted = Set(plan.map(\.id))

        // 더는 필요 없는 예약(삭제·보관·완료·시간 삭제·알림 끔)을 지운다.
        client.removePending(ids: pending.keys.filter { !wanted.contains($0) }.sorted())
        // 없거나 내용이 달라진 것만 예약한다. 같은 식별자로 예약하면 기존 것을 대체한다.
        for notification in plan where pending[notification.id] != notification.signature {
            try? await client.add(notification)
        }
        // 오늘 이미 완료한 루틴의 알림이 알림 센터에 남아 있으면 치운다.
        if let today = days.first {
            let doneIDs = today.sections.flatMap(\.checks).filter(\.isDone)
                .map { PlannedNotification.id(routineID: $0.id, dateKey: today.day.key) }
            client.removeDelivered(ids: doneIDs)
        }
        scheduledCount = plan.count
    }
}
