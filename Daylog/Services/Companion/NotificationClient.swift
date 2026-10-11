import Foundation
import UserNotifications

/// 알림 권한 상태.
enum NotificationPermission: Equatable {
    /// 아직 확인하지 못했다.
    case unknown
    /// 아직 물어본 적 없다.
    case notDetermined
    case denied
    case authorized

    var title: String {
        switch self {
        case .unknown: return "확인 중…"
        case .notDetermined: return "아직 허용하지 않았어요"
        case .denied: return "꺼져 있어요"
        case .authorized: return "허용됨"
        }
    }
}

/// 시스템 알림 센터를 감싼다. 테스트에서는 가짜로 바꾼다.
@MainActor
protocol NotificationClient: AnyObject {
    func permission() async -> NotificationPermission
    /// 권한을 묻는다. 이미 정해졌으면 묻지 않고 지금 상태를 돌려준다.
    func requestPermission() async -> NotificationPermission
    /// 예약되어 있는 루틴 알림: 식별자 → 내용 비교값.
    func pending() async -> [String: String]
    func add(_ notification: PlannedNotification) async throws
    func removePending(ids: [String])
    func removeDelivered(ids: [String])
}

/// 루틴 알림의 종류와 버튼.
enum RoutineNotificationAction {
    static let category = "DAYLOG_ROUTINE"
    static let complete = "DAYLOG_COMPLETE"
    static let later = "DAYLOG_LATER"

    static let routineIDKey = "routineID"
    static let dateKeyKey = "dateKey"
    static let signatureKey = "signature"
}

/// 실제 알림 센터.
@MainActor
final class SystemNotificationClient: NotificationClient {
    private let center = UNUserNotificationCenter.current()

    init() {
        // [완료]는 앱을 앞으로 띄우지 않고 처리한다. [나중에]는 알림만 닫는다(미루기 알림을 새로 만들지 않는다).
        let complete = UNNotificationAction(identifier: RoutineNotificationAction.complete, title: "완료", options: [])
        let later = UNNotificationAction(identifier: RoutineNotificationAction.later, title: "나중에", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: RoutineNotificationAction.category, actions: [complete, later], intentIdentifiers: [], options: []
            ),
        ])
    }

    func permission() async -> NotificationPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized, .provisional, .ephemeral: return .authorized
        @unknown default: return .denied
        }
    }

    func requestPermission() async -> NotificationPermission {
        let current = await permission()
        guard current == .notDetermined else { return current }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        return await permission()
    }

    func pending() async -> [String: String] {
        var result: [String: String] = [:]
        for request in await center.pendingNotificationRequests()
        where request.identifier.hasPrefix(PlannedNotification.idPrefix) {
            result[request.identifier] = request.content.userInfo[RoutineNotificationAction.signatureKey] as? String ?? ""
        }
        return result
    }

    func add(_ notification: PlannedNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.notificationTitle
        content.subtitle = notification.notificationSubtitle
        content.body = notification.notificationBody
        content.sound = .default
        content.categoryIdentifier = RoutineNotificationAction.category
        content.threadIdentifier = notification.dateKey
        content.userInfo = [
            RoutineNotificationAction.routineIDKey: notification.routineID.uuidString,
            RoutineNotificationAction.dateKeyKey: notification.dateKey,
            RoutineNotificationAction.signatureKey: notification.signature,
        ]
        // 시간대를 적지 않은 날짜 구성 요소는 울릴 때의 기기 시간대로 해석된다.
        let trigger = UNCalendarNotificationTrigger(dateMatching: notification.dateComponents, repeats: false)
        try await center.add(UNNotificationRequest(identifier: notification.id, content: content, trigger: trigger))
    }

    func removePending(ids: [String]) {
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func removeDelivered(ids: [String]) {
        guard !ids.isEmpty else { return }
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}

/// 알림을 쓰지 않는 환경(단위 테스트의 호스트 앱)용. 아무것도 예약하지 않는다.
@MainActor
final class DisabledNotificationClient: NotificationClient {
    func permission() async -> NotificationPermission { .denied }
    func requestPermission() async -> NotificationPermission { .denied }
    func pending() async -> [String: String] { [:] }
    func add(_ notification: PlannedNotification) async throws {}
    func removePending(ids: [String]) {}
    func removeDelivered(ids: [String]) {}
}
