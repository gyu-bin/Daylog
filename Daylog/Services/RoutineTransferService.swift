import Foundation
import SwiftData

struct RoutineImportPreview: Equatable {
    /// 이미 있는 루틴·그룹과 이름이 겹칠 때 어떻게 할지.
    enum ConflictPolicy: Equatable, Sendable {
        /// 파일 가져오기: 설정이 다른 같은 이름은 오류로 세우고, 사용자가 파일을 고쳐야 저장된다.
        case strict
        /// 템플릿 가져오기: 겹치는 줄만 건너뛰고 나머지를 추가한다. 기존 루틴은 고치지 않는다.
        case skipConflicts
    }

    enum Action: Equatable {
        case create(groupID: UUID?)
        case duplicate
        /// 이름이 같은 루틴·그룹이 이미 있어 건너뛴다(설정이 다르거나 보관돼 있다). `skipConflicts`에서만 나온다.
        case conflict(String)
        case error(String)

        var label: String {
            switch self {
            case .create(let id): return id == nil ? "새 그룹에 추가" : "기존 그룹에 추가"
            case .duplicate: return "같은 루틴 · 건너뜀"
            case .conflict(let message): return "\(message) · 건너뜀"
            case .error(let message): return message
            }
        }
    }
    struct Row: Identifiable, Equatable {
        let id: Int
        let routine: TransferRoutine
        let action: Action
    }
    let source: [TransferRoutine]
    let rows: [Row]
    let catalogStamp: Data
    let day: Day
    var policy: ConflictPolicy = .strict
    var createdCount: Int { rows.filter { if case .create = $0.action { return true }; return false }.count }
    /// 건너뛰는 줄: 같은 루틴이 이미 있거나, 이름이 겹쳐 건너뛴다.
    var duplicateCount: Int {
        rows.filter { row in
            switch row.action {
            case .duplicate, .conflict: return true
            default: return false
            }
        }.count
    }
    var errorCount: Int { rows.filter { if case .error = $0.action { return true }; return false }.count }
    var newGroupCount: Int {
        Set(rows.compactMap { row -> String? in
            if case .create(groupID: nil) = row.action { return row.routine.group }; return nil
        }).count
    }
    var reusedGroupCount: Int {
        Set(rows.compactMap { row -> UUID? in
            if case .create(let id) = row.action { return id }; return nil
        }).count
    }
    var canSave: Bool { errorCount == 0 && createdCount > 0 }
}

@MainActor
struct RoutineTransferService {
    let context: ModelContext
    var persist: ((ModelContext) throws -> Void)? = nil

    func preview(
        _ source: [TransferRoutine], today: Day, policy: RoutineImportPreview.ConflictPolicy = .strict
    ) throws -> RoutineImportPreview {
        guard !source.isEmpty, source.count <= RoutineTransferFormat.maximumRows else {
            throw RoutineTransferError.invalid("한 번에 1~1,000개 루틴을 가져올 수 있어요.")
        }
        let service = RoutineService(context: context)
        let groups = try service.groups(includingRemoved: true)
        let routines = try service.routines(includingRemoved: true)
        struct NameKey: Hashable { var group: String; var title: String }
        var seen: [NameKey: TransferRoutine] = [:]
        let rows = source.enumerated().map { index, definition -> RoutineImportPreview.Row in
            func row(_ action: RoutineImportPreview.Action) -> RoutineImportPreview.Row {
                .init(id: index + 1, routine: definition, action: action)
            }
            /// 이미 있는 것과 겹치는 줄. 파일에서는 오류, 템플릿에서는 그 줄만 건너뛴다.
            func clash(_ strict: String, _ short: String) -> RoutineImportPreview.Row {
                row(policy == .strict ? .error(strict) : .conflict(short))
            }
            if let error = RoutineTransferFormat.validation(definition) { return row(.error(error)) }
            let matchingGroups = groups.filter { $0.title == definition.group }
            guard matchingGroups.count <= 1 else {
                return clash("같은 이름의 그룹이 여러 개예요. 그룹 이름을 구별해 주세요.", "같은 이름의 그룹이 여러 개예요")
            }
            let group = matchingGroups.first
            if let group, group.isArchived || group.isRemoved {
                return clash("보관·삭제된 그룹과 이름이 같아요. 다른 그룹명을 사용해 주세요.", "보관·삭제한 그룹과 이름이 같아요")
            }
            let key = NameKey(group: definition.group, title: definition.title)
            if let earlier = seen[key] {
                return row(same(earlier, definition) ? .duplicate : .error("파일 안의 같은 이름 루틴과 설정이 달라요."))
            }
            seen[key] = definition
            if let group {
                let matches = routines.filter { $0.effectiveGroupID == group.id && $0.title == definition.title }
                if matches.count > 1 { return clash("같은 그룹에 이름이 같은 루틴이 여러 개예요.", "이름이 같은 루틴이 여러 개예요") }
                if let existing = matches.first {
                    let old = TransferRoutine(group: group.title, title: existing.title, weekdays: existing.weekdays, time: existing.timeLabel, note: existing.note)
                    if existing.isArchived || existing.isRemoved { return clash("보관·삭제된 루틴과 이름이 같아요.", "보관·삭제한 루틴과 이름이 같아요") }
                    if same(old, definition) { return row(.duplicate) }
                    return clash("기존 루틴과 설정이 달라요. 덮어쓰지 않으므로 이름을 바꿔 주세요.", "이름이 같은 루틴이 이미 있어요")
                }
            }
            return row(.create(groupID: group?.id))
        }
        return RoutineImportPreview(
            source: source, rows: rows, catalogStamp: try DataExportService(context: context).catalogStamp(), day: today, policy: policy
        )
    }

    /// The caller confirms this exact preview. Revalidation never silently accepts a changed catalog.
    @discardableResult
    func commit(_ confirmed: RoutineImportPreview, today: Day, now: Date = .now) throws -> Int {
        guard !context.hasChanges else { throw RoutineTransferError.pendingEdits }
        let current = try preview(confirmed.source, today: today, policy: confirmed.policy)
        guard current == confirmed else { throw RoutineTransferError.changed }
        guard current.canSave else { throw RoutineTransferError.invalid("오류를 해결하고 추가할 루틴을 확인해 주세요.") }
        let service = RoutineService(context: context)
        do {
            var groups = try service.groups(includingRemoved: true)
            var groupsByTitle: [String: RoutineGroup] = [:]
            let routines = try service.routines(includingRemoved: true)
            var nextOrders: [UUID: Int] = [:]
            for routine in routines { nextOrders[routine.effectiveGroupID] = max(nextOrders[routine.effectiveGroupID] ?? 0, routine.order + 1) }
            for row in current.rows {
                guard case .create(let groupID) = row.action else { continue }
                let definition = row.routine
                let group: RoutineGroup
                if let groupID, let existing = groups.first(where: { $0.id == groupID }) { group = existing }
                else if let created = groupsByTitle[definition.group] { group = created }
                else {
                    group = RoutineGroup(title: definition.group, colorKey: GroupColor.next(after: groups.map(\.colorKey)).rawValue,
                                         order: (groups.map(\.order).max() ?? -1) + 1, createdAt: now)
                    context.insert(group)
                    groups.append(group)
                    groupsByTitle[definition.group] = group
                }
                let routine = RoutineItem(title: definition.title, note: definition.note, timeLabel: definition.time,
                                          weekdays: definition.weekdays, order: nextOrders[group.id] ?? 0, createdAt: now, groupID: group.id)
                nextOrders[group.id] = routine.order + 1
                context.insert(routine)
                // Only the newly created identity receives a revision/today check. Existing checks are not synchronized.
                try service.applyChange(to: routine, today: today, now: now)
            }
            let settings = try SettingsService(context: context).settings()
            if settings.firstRoutineDate == nil { settings.firstRoutineDate = today.anchorDate }
            if let persist { try persist(context) } else { try context.save() }
            return current.createdCount
        } catch {
            context.rollback()
            throw error
        }
    }

    private func same(_ left: TransferRoutine, _ right: TransferRoutine) -> Bool {
        left.group == right.group && left.title == right.title && left.weekdays.sorted() == right.weekdays.sorted()
            && left.time == right.time && left.note == right.note
    }
}
