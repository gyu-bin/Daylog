import Foundation

/// 예약할 루틴 알림 하나. 하루에 한 번 울리는 일회성 알림이다.
struct PlannedNotification: Equatable, Identifiable {
    let routineID: UUID
    let dateKey: String
    let title: String
    let timeLabel: String
    let groupTitle: String
    let year: Int
    let month: Int
    let day: Int
    let hour: Int
    let minute: Int

    /// 루틴과 날짜로 정해지는 식별자. 같은 날 같은 루틴은 몇 번을 예약해도 하나다.
    var id: String { Self.id(routineID: routineID, dateKey: dateKey) }

    static let idPrefix = "routine."

    static func id(routineID: UUID, dateKey: String) -> String {
        "\(idPrefix)\(routineID.uuidString).\(dateKey)"
    }

    /// 내용이 바뀌었는지 비교하는 값. 이름·그룹·시간이 바뀌면 다시 예약한다.
    var signature: String { "\(title)|\(groupTitle)|\(hour):\(minute)" }

    var notificationTitle: String { "Daylog · 루틴 시간이에요" }
    var notificationSubtitle: String { "\(TimeLabel.label(minutes: hour * 60 + minute)) · \(groupTitle)" }
    var notificationBody: String { "\(title) — 오늘의 루틴을 완료해 보세요." }

    var dateComponents: DateComponents {
        DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    }
}

/// 어떤 알림을 예약해야 하는지 정한다(순수 함수).
///
/// 요일마다 반복되는 알림 대신 날짜별 일회성 알림을 쓴다. 반복 알림은 "오늘 이미 완료한 루틴은 오늘만 건너뛴다"를
/// 표현할 수 없어서, 완료해도 울리거나 반복 전체를 지워야 한다. 일회성 알림은 그날 것만 지우면 된다.
/// 대신 앞으로 며칠치만 예약해 두므로, 앱이 그 기간 동안 한 번도 실행되지 않으면 그 뒤로는 울리지 않는다.
enum RoutineNotificationPlanner {
    /// 앞으로 며칠치를 예약하는가(오늘 포함).
    static let horizonDays = 14
    /// 시스템이 앱 하나에 허용하는 대기 알림은 64개다. 여유를 두고 가까운 것부터 채운다.
    static let maxPending = 60

    /// - Parameters:
    ///   - days: 오늘부터의 예정(`AppStore.upcomingDays`). 첫 날의 완료 여부만 본다.
    ///   - muted: 알림을 끈 루틴의 ID.
    static func plan(
        days: [PlannedDay], now: Date, calendar: Calendar = .current, muted: Set<String> = []
    ) -> [PlannedNotification] {
        var planned: [(fireDate: Date, notification: PlannedNotification)] = []
        for day in days.prefix(horizonDays) {
            for section in day.sections {
                for check in section.checks where !check.isDone && !muted.contains(check.id.uuidString) {
                    // 시간이 없거나 시각으로 읽히지 않는 루틴은 알리지 않는다.
                    guard let minutes = TimeLabel.minutes(check.timeLabel) else { continue }
                    let notification = PlannedNotification(
                        routineID: check.id, dateKey: day.day.key, title: check.title,
                        timeLabel: check.timeLabel, groupTitle: section.group.title,
                        year: day.day.year, month: day.day.month, day: day.day.day,
                        hour: minutes / 60, minute: minutes % 60
                    )
                    // 이미 지난 시각은 예약하지 않는다(예약하면 곧바로 울리거나, 전달된 알림이 한 번 더 울린다).
                    guard let fireDate = calendar.date(from: notification.dateComponents), fireDate > now else { continue }
                    planned.append((fireDate, notification))
                }
            }
        }
        return planned
            .sorted { ($0.fireDate, $0.notification.id) < ($1.fireDate, $1.notification.id) }
            .prefix(maxPending)
            .map(\.notification)
    }
}
