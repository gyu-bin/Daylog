import Foundation
import WidgetKit

struct TodayEntry: TimelineEntry {
    enum Content: Equatable {
        /// 앱이 아직 데이터를 적어 두지 않았거나, 적어 둔 기간(7일)이 지났다.
        case needsApp
        /// 루틴이 하나도 없다.
        case noRoutines
        case day(WidgetDay)
    }

    let date: Date
    let content: Content
    /// 그 시점의 "자정부터 몇 분". 다음 루틴을 고를 때 쓴다.
    let nowMinutes: Int
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        // 가짜 루틴을 보여 주지 않는다. 데이터가 있으면 그것을, 없으면 안내를 그린다.
        Self.entry(at: .now, snapshot: WidgetBridge.shared?.readSnapshot(), pending: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(Self.entry(
            at: .now, snapshot: WidgetBridge.shared?.readSnapshot(), pending: WidgetBridge.shared?.readPending() ?? []
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let bridge = WidgetBridge.shared
        let snapshot = bridge?.readSnapshot()
        let pending = bridge?.readPending() ?? []
        let now = Date.now
        let dates = Self.refreshDates(from: now, snapshot: snapshot)
        let entries = dates.map { Self.entry(at: $0, snapshot: snapshot, pending: pending) }
        // 마지막 항목(가장 먼 자정)까지 쓰고 나면 다시 묻는다. 그 사이의 변경은 앱이 새로 고침을 요청한다.
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// 화면이 달라지는 시점들: 지금, 오늘 남은 루틴의 예정 시각(다음 루틴이 넘어간다), 앞으로의 자정(날짜가 바뀐다).
    static func refreshDates(from now: Date, snapshot: WidgetSnapshot?, calendar: Calendar = .current) -> [Date] {
        var dates = [now]
        let startOfToday = calendar.startOfDay(for: now)
        if let today = snapshot?.day(Day.today(now: now, timeZone: calendar.timeZone).key) {
            for item in today.items {
                guard let minutes = TimeLabel.minutes(item.timeLabel),
                      // 예정 시각을 1분 넘긴 때: 그 루틴이 "다음"에서 "지난 것"으로 바뀐다.
                      let date = calendar.date(byAdding: .minute, value: minutes + 1, to: startOfToday), date > now
                else { continue }
                dates.append(date)
            }
        }
        for offset in 1...WidgetSnapshot.dayCount {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: startOfToday) {
                dates.append(midnight)
            }
        }
        return Array(Set(dates)).sorted()
    }

    static func entry(
        at date: Date, snapshot: WidgetSnapshot?, pending: [PendingCheck], calendar: Calendar = .current
    ) -> TodayEntry {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let nowMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let dateKey = Day.today(now: date, timeZone: calendar.timeZone).key
        let content: TodayEntry.Content
        if let snapshot, let day = snapshot.day(dateKey) {
            content = (snapshot.hasRoutines || day.isVacation == true) ? .day(day.applying(pending)) : .noRoutines
        } else {
            content = .needsApp
        }
        return TodayEntry(date: date, content: content, nowMinutes: nowMinutes)
    }
}
