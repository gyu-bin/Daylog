#if os(iOS)
import ActivityKit
import AppIntents
import Foundation
import WidgetKit

/// 잠금 화면 "오늘의 루틴" 라이브 액티비티(2026-10-26). 남은 루틴 몇 개를 줄마다 눌러 바로 체크한다.
struct RoutineActivityAttributes: ActivityAttributes {
    struct Item: Codable, Hashable, Identifiable {
        var routineID: String
        var title: String
        var timeLabel: String
        var isDone: Bool
        var id: String { routineID }
    }
    struct ContentState: Codable, Hashable {
        var dateKey: String
        var done: Int
        var total: Int
        var items: [Item]
        /// 지금 입은 피오 의상(PioOutfitID.rawValue). 카드 귀퉁이에 그 피오를 그린다.
        var outfit: String? = nil
    }
    /// 라이브 액티비티 하나는 하루를 맡는다.
    var dateKey: String
}

extension RoutineActivityAttributes.ContentState {
    static let maxItems = 4
    /// 위젯이 쓰는 오늘의 스냅샷으로 카드 내용을 만든다. 남은 루틴을 먼저, 자리가 남으면 끝낸 것을 보인다.
    init(day: WidgetDay, outfit: String? = RoutineLiveActivityOutfit.current) {
        let all = day.items
        let open = all.filter { !$0.isSettled }
        let settled = all.filter(\.isSettled)
        self.init(dateKey: day.dateKey, done: day.done, total: day.total,
                  items: Array((open + settled).prefix(Self.maxItems)).map {
                      .init(routineID: $0.routineID.uuidString, title: $0.title, timeLabel: $0.timeLabel, isDone: $0.requestedIsDone)
                  }, outfit: outfit)
    }
}

/// 라이브 액티비티의 체크 단추. 앱 프로세스에서 실행되어(LiveActivityIntent) 저장 뒤 카드가 바로 갱신된다.
struct ToggleRoutineLiveIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "루틴 체크"
    static var isDiscoverable: Bool { false }
    // 위젯 확장이 아니라 앱 프로세스에서 실행한다(저장소·카드 갱신이 앱에 있다). 확장에서 돌면 대기열에만 남는다.
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @Parameter(title: "루틴") var routineID: String
    @Parameter(title: "날짜") var dateKey: String
    @Parameter(title: "완료") var isDone: Bool

    init() {}
    init(routineID: String, dateKey: String, isDone: Bool) {
        self.routineID = routineID
        self.dateKey = dateKey
        self.isDone = isDone
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard dateKey == Day.today().key, let id = UUID(uuidString: routineID), let bridge = WidgetBridge.shared else { return .result() }
        try bridge.appendPending(PendingCheck(dateKey: dateKey, routineID: id, isDone: isDone, at: .now))
        #if !DAYLOG_WIDGET_EXTENSION
        if let runtime = AppRuntime.shared { _ = await runtime.commitWidgetChecks() }
        #endif
        // 카드는 기다리지 않고 바로 바꾼다(저장이 늦어도 누른 결과가 보이게).
        await RoutineLiveActivityRefresh.update(bridge: bridge)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// 카드에 그릴 피오 의상. 앱이 입힐 때마다 앱 그룹 설정에 적어 둔다(확장에서도 읽힌다).
enum RoutineLiveActivityOutfit {
    static let key = "liveActivity.outfit.v1"
    static var current: String? { UserDefaults(suiteName: WidgetBridge.appGroupID)?.string(forKey: key) }
    static func set(_ raw: String) { UserDefaults(suiteName: WidgetBridge.appGroupID)?.set(raw, forKey: key) }
}

/// 대기 중인 체크까지 반영한 오늘 내용으로 떠 있는 카드를 바꾼다.
enum RoutineLiveActivityRefresh {
    static func update(bridge: WidgetBridge) async {
        let key = Day.today().key
        guard let day = bridge.readSnapshot()?.day(key)?.applying(bridge.readPending()) else { return }
        let state = RoutineActivityAttributes.ContentState(day: day)
        for activity in Activity<RoutineActivityAttributes>.activities where activity.attributes.dateKey == key {
            if day.total > 0, day.done >= day.total {
                await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(30 * 60)))
            } else {
                await activity.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(8 * 60 * 60)))
            }
        }
    }
}

/// 잠금 화면 카드를 켤지(이 기기). 기본은 켬.
enum RoutineLiveActivityPreference {
    static let key = "liveActivity.today.v1"
    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool { defaults.object(forKey: key) as? Bool ?? true }
}
#endif
