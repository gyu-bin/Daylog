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
    var isVacation: Bool? = nil
    /// 휴가이지만 고른 루틴은 이어 가는 날. `groups`에는 그 루틴만 들어 있다. 이전에 적어 둔 파일에는 없다.
    var keepsRoutines: Bool? = nil

    var items: [WidgetItem] { groups.flatMap(\.items) }
    var total: Int { items.count }
    var done: Int { items.filter(\.isDone).count }
    /// 완료하지도 건너뛰지도 않은 항목 수.
    var remaining: Int { items.filter { !$0.isSettled }.count }
    /// 건너뛴 항목 수(완료한 것은 빼고). 달성률은 그대로 두고, 남은 개수에서만 뺀다(앱의 오늘 화면과 같다).
    var skipped: Int { items.filter { $0.isSkipped == true && !$0.isDone }.count }
    var percent: Int? { isVacation == true ? nil : Achievement.percent(done: done, total: total) }
    var ratio: Double? { isVacation == true ? nil : Achievement.ratio(done: done, total: total) }

    /// 휴가 안내만 보여 줄 날: 전체 휴식이거나, 유지하는 루틴 가운데 오늘 해당하는 것이 없다.
    var isVacationRest: Bool { isVacation == true && !(keepsRoutines == true && total > 0) }
    /// 휴가 중에 이어 가는 루틴의 진행(달성률 통계와는 별개다). 그런 날이 아니면 nil.
    var keptRatio: Double? {
        isVacation == true && !isVacationRest ? Achievement.ratio(done: done, total: total) : nil
    }

    var hasPending: Bool { items.contains { $0.pendingIsDone != nil } }

    /// 다음 예정 루틴. 시간이 정해진 남은 항목이 없으면 nil.
    func nextTimed(nowMinutes: Int) -> (item: WidgetItem, isOverdue: Bool)? {
        let all = items
        guard let pick = NextRoutine.pick(
            timeLabels: all.map(\.timeLabel), isDone: all.map(\.isSettled), nowMinutes: nowMinutes
        ) else { return nil }
        return (all[pick.index], pick.isOverdue)
    }

    /// 작은 위젯의 아래 줄에 보여 줄 항목: 다음 예정 루틴, 없으면 아직 안 한 첫 항목.
    func nextToShow(nowMinutes: Int) -> WidgetItem? {
        nextTimed(nowMinutes: nowMinutes)?.item ?? items.first { !$0.isSettled }
    }

    /// Pending targets are separate from confirmed values; progress always uses the saved snapshot.
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
                    copy.groups[groupIndex].items[itemIndex].pendingIsDone = check.isDone
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
    var pendingIsDone: Bool? = nil
    /// 오늘 쉬기로 한 항목. 평소에는 칸을 쓰지 않아 이전에 적어 둔 파일과 모양이 같다.
    var isSkipped: Bool? = nil

    var requestedIsDone: Bool { pendingIsDone ?? isDone }
    /// 완료했거나 건너뛰어서 "다음 루틴"으로 고르지 않는다.
    var isSettled: Bool { isDone || isSkipped == true }
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
