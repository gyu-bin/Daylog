#if os(iOS)
import ActivityKit
import Foundation

/// 오늘의 루틴 라이브 액티비티를 켜고, 바꾸고, 끈다(2026-10-26).
/// 푸시 서버가 없어 앱이 화면에 있을 때만 새로 켤 수 있다. 앱을 열 때마다 오늘 카드가 없으면 켜고, 있으면 8시간을 다시 채운다.
@MainActor
enum RoutineLiveActivityController {
    private static let lifetime: TimeInterval = 8 * 60 * 60

    /// 위젯 스냅샷을 새로 쓸 때마다 부른다. `canStart`는 앱이 화면에 있을 때만 true.
    static func sync(today: WidgetDay?, canStart: Bool) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let current = Activity<RoutineActivityAttributes>.activities
        guard RoutineLiveActivityPreference.isEnabled(), let today, today.total > 0, !today.isVacationRest else {
            for activity in current { await activity.end(nil, dismissalPolicy: .immediate) }
            return
        }
        // 카드의 피오는 지금 입고 있는 옷(구매 확인을 거친 값)이다.
        let outfit = PioWardrobeStore.shared.equippedOutfit.rawValue
        RoutineLiveActivityOutfit.set(outfit)
        let state = RoutineActivityAttributes.ContentState(day: today, outfit: outfit)
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(lifetime))
        // 지난 날의 카드는 끈다.
        for activity in current where activity.attributes.dateKey != today.dateKey {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        if let activity = current.first(where: { $0.attributes.dateKey == today.dateKey && $0.activityState == .active }) {
            if today.done >= today.total {
                // 다 끝내면 잠깐 "완료"를 보여 주고 내린다.
                await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(60 * 30)))
            } else if activity.content.state != state || canStart {
                await activity.update(content)
            }
        } else if canStart, today.done < today.total {
            _ = try? Activity.request(attributes: RoutineActivityAttributes(dateKey: today.dateKey), content: content, pushType: nil)
        }
    }

    static func endAll() async {
        for activity in Activity<RoutineActivityAttributes>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
#endif
