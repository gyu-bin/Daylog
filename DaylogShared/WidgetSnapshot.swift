import Foundation

/// 위젯이 그리는 데이터. 앱이 저장소에서 만들어 앱 그룹 폴더에 적어 두고, 위젯은 이 파일만 읽는다.
/// 위젯은 SwiftData 저장소를 열지 않는다(저장소는 한 번에 한 프로세스만 연다는 규칙을 지킨다).
struct WidgetSnapshot: Codable, Equatable {
    /// 오늘부터 며칠치. 앱을 열지 않아도 자정을 넘겨 다음 날의 루틴을 보여 주기 위해서다.
    var days: [WidgetDay]
    /// 루틴이 하나라도 있는가. 없으면 "쉬는 날"이 아니라 "아직 루틴이 없음"으로 안내한다.
    var hasRoutines: Bool

    static let dayCount = 7

    func day(_ dateKey: String) -> WidgetDay? {
        days.first { $0.dateKey == dateKey }
    }
}

struct WidgetDay: Codable, Equatable {
    var dateKey: String
    var groups: [WidgetGroup]

    var items: [WidgetItem] { groups.flatMap(\.items) }
    var total: Int { items.count }
    var done: Int { items.filter(\.isDone).count }
    var percent: Int? { Achievement.percent(done: done, total: total) }
    var ratio: Double? { Achievement.ratio(done: done, total: total) }

    /// 다음 예정 루틴. 시간이 정해진 남은 항목이 없으면 nil.
    func nextTimed(nowMinutes: Int) -> (item: WidgetItem, isOverdue: Bool)? {
        let all = items
        guard let pick = NextRoutine.pick(
            timeLabels: all.map(\.timeLabel), isDone: all.map(\.isDone), nowMinutes: nowMinutes
        ) else { return nil }
        return (all[pick.index], pick.isOverdue)
    }

    /// 작은 위젯의 아래 줄에 보여 줄 항목: 다음 예정 루틴, 없으면 아직 안 한 첫 항목.
    func nextToShow(nowMinutes: Int) -> WidgetItem? {
        nextTimed(nowMinutes: nowMinutes)?.item ?? items.first { !$0.isDone }
    }

    /// 아직 반영되지 않은 위젯의 체크를 겹쳐 본 모습. 같은 항목에는 가장 나중 것만 쓴다.
    func applying(_ pending: [PendingCheck]) -> WidgetDay {
        var latest: [UUID: PendingCheck] = [:]
        for check in pending where check.dateKey == dateKey {
            if let existing = latest[check.routineID], existing.at > check.at { continue }
            latest[check.routineID] = check
        }
        guard !latest.isEmpty else { return self }
        var copy = self
        for groupIndex in copy.groups.indices {
            for itemIndex in copy.groups[groupIndex].items.indices {
                if let check = latest[copy.groups[groupIndex].items[itemIndex].routineID] {
                    copy.groups[groupIndex].items[itemIndex].isDone = check.isDone
                }
            }
        }
        return copy
    }
}

struct WidgetGroup: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var colorKey: String
    var items: [WidgetItem]

    var done: Int { items.filter(\.isDone).count }
    var ratio: Double { Achievement.ratio(done: done, total: items.count) ?? 0 }
}

struct WidgetItem: Codable, Equatable, Identifiable {
    var routineID: UUID
    var title: String
    var timeLabel: String
    var isDone: Bool

    var id: UUID { routineID }
}

/// 위젯에서 누른 체크. 앱이 다음에 실행될 때 저장소에 반영한다("뒤집기"가 아니라 "이 값으로"라서 두 번 반영해도 같다).
struct PendingCheck: Codable, Equatable {
    var dateKey: String
    var routineID: UUID
    var isDone: Bool
    var at: Date
}

/// 큰 위젯에 들어갈 줄을 고른다. 그룹 머리말과 항목이 각각 한 줄이다.
enum WidgetRows {
    enum Row: Equatable, Identifiable {
        case group(WidgetGroup)
        case item(WidgetItem, colorKey: String)

        var id: String {
            switch self {
            case .group(let group): return "g-\(group.id.uuidString)"
            case .item(let item, _): return "i-\(item.routineID.uuidString)"
            }
        }
    }

    /// `limit`줄 안에 들어가는 만큼만 담고, 못 담은 항목 수를 함께 돌려준다.
    /// 머리말만 남고 항목이 하나도 안 들어가는 그룹은 넣지 않는다.
    static func fit(_ day: WidgetDay, limit: Int) -> (rows: [Row], hiddenItems: Int) {
        var rows: [Row] = []
        var shown = 0
        for group in day.groups where !group.items.isEmpty {
            guard rows.count + 2 <= limit else { break }
            rows.append(.group(group))
            for item in group.items {
                guard rows.count < limit else { break }
                rows.append(.item(item, colorKey: group.colorKey))
                shown += 1
            }
        }
        return (rows, day.total - shown)
    }
}
