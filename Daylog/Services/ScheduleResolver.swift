import Foundation
import SwiftData

/// `RoutineRevision`의 값 복사본. 순수 계산에 쓴다.
struct RevisionSnapshot: Equatable, Sendable {
    let routineID: UUID
    let effectiveFromKey: String
    let title: String
    let timeLabel: String
    let note: String
    let weekdayMask: Int
    let isArchived: Bool
    let order: Int
    let updatedAt: Date
    /// 당시 속해 있던 그룹.
    let group: GroupSnapshot

    var state: RoutineState {
        RoutineState(
            title: title, timeLabel: timeLabel, note: note, weekdayMask: weekdayMask,
            isArchived: isArchived, order: order, group: group
        )
    }

    func isScheduled(on day: Day) -> Bool {
        !isArchived && weekdayMask & (1 << (day.weekday - 1)) != 0
    }
}

extension RoutineRevision {
    var snapshot: RevisionSnapshot {
        RevisionSnapshot(
            routineID: routineID,
            effectiveFromKey: effectiveFromKey,
            title: title,
            timeLabel: timeLabel,
            note: note,
            weekdayMask: weekdayMask,
            isArchived: isArchived,
            order: order,
            updatedAt: updatedAt,
            group: group
        )
    }
}

/// 변경 이력만으로 "그 날짜에 어떤 루틴이 예정되어 있었는가"를 판정한다.
/// 현재 `RoutineItem` 상태는 보지 않으므로 이후의 루틴 수정이 과거 판정을 바꾸지 않는다.
struct ScheduleResolver: Sendable {
    private let revisionsByRoutine: [UUID: [RevisionSnapshot]]

    init(revisions: [RevisionSnapshot]) {
        revisionsByRoutine = Dictionary(grouping: revisions, by: \.routineID).mapValues { group in
            group.sorted { ($0.effectiveFromKey, $0.updatedAt) < ($1.effectiveFromKey, $1.updatedAt) }
        }
    }

    /// `day`에 유효했던 루틴 설정. 그 날짜에 루틴이 아직 없었다면 nil.
    func state(of routineID: UUID, on day: Day) -> RevisionSnapshot? {
        let key = day.key
        return revisionsByRoutine[routineID]?.last { $0.effectiveFromKey <= key }
    }

    /// `day`에 예정되어 있던 루틴. 표시 순서대로.
    func scheduled(on day: Day) -> [RevisionSnapshot] {
        revisionsByRoutine.keys
            .compactMap { state(of: $0, on: day) }
            .filter { $0.isScheduled(on: day) }
            .sorted {
                if $0.group.id != $1.group.id {
                    return ($0.group.order, $0.group.title, $0.group.id.uuidString)
                        < ($1.group.order, $1.group.title, $1.group.id.uuidString)
                }
                return ($0.order, $0.title, $0.routineID.uuidString) < ($1.order, $1.title, $1.routineID.uuidString)
            }
    }
}

extension ScheduleResolver {
    @MainActor
    init(context: ModelContext) throws {
        let revisions = try context.fetch(FetchDescriptor<RoutineRevision>())
        self.init(revisions: revisions.map(\.snapshot))
    }
}
