import Foundation

struct OnboardingRoutineDraft {
    var groupID: UUID?
    var groupTitle = ""
    var routineTitle = ""

    var validationMessage: String? {
        let routine = routineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if routine.isEmpty { return "루틴 이름을 입력해 주세요." }
        if routine.count > 60 { return "루틴 이름은 60자 이내로 입력해 주세요." }
        if groupID == nil {
            let group = groupTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if group.isEmpty { return "그룹 이름을 입력해 주세요." }
            if group.count > 40 { return "그룹 이름은 40자 이내로 입력해 주세요." }
        }
        return nil
    }
}

extension AppStore {
    /// This is only called by the explicit Create button, never by launch or sync callbacks.
    @discardableResult
    func createOnboardingRoutine(_ draft: OnboardingRoutineDraft) -> Bool {
        guard draft.validationMessage == nil else { return false }
        return mutateRoutines { service in
            // Fetch current definitions at confirmation time, including data that arrived while the sheet was open.
            let groups = try service.groups().filter { !$0.isArchived && !$0.isRemoved }
            let group: RoutineGroup
            if let id = draft.groupID {
                guard let selected = groups.first(where: { $0.id == id }) else { throw OnboardingError.groupChanged }
                group = selected
            } else {
                let title = draft.groupTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let matches = groups.filter { $0.title == title }
                guard matches.count <= 1 else { throw OnboardingError.ambiguousGroup }
                group = try matches.first ?? service.addGroup(title: title)
            }
            let title = draft.routineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            // A repeated confirmation or late sync must not create another routine with the same group and title.
            let matches = try service.routines().filter { $0.effectiveGroupID == group.id && $0.title == title }
            if matches.contains(where: { !$0.isArchived }) { return }
            if !matches.isEmpty { throw OnboardingError.archivedRoutine }
            try service.add(title: title, group: group, today: today)
        }
    }
}

private enum OnboardingError: LocalizedError {
    case groupChanged, ambiguousGroup, archivedRoutine
    var errorDescription: String? {
        switch self {
        case .groupChanged: return "선택한 그룹이 변경됐어요. 그룹을 다시 선택해 주세요."
        case .ambiguousGroup: return "같은 이름의 그룹이 여러 개예요. 사용할 그룹을 목록에서 선택해 주세요."
        case .archivedRoutine: return "같은 이름의 루틴이 보관되어 있어요. 루틴 화면에서 복원하거나 다른 이름을 입력해 주세요."
        }
    }
}
