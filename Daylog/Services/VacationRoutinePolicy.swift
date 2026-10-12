import Foundation

/// 어떤 날짜에 루틴을 어떻게 보여 줄지. 홈·메뉴 막대·위젯·알림이 같은 규칙을 쓴다.
/// 기록은 건드리지 않는다: 그날의 체크는 모두 저장돼 있고, 여기서는 보여 줄 것만 고른다.
/// 통계는 이 값과 상관없이 휴가 날짜 전체를 제외한다.
enum VacationRoutinePolicy: Equatable {
    /// 휴가가 아니다. 평소대로.
    case normal
    /// 휴가이고 모든 루틴을 쉰다.
    case fullRest
    /// 휴가이지만 고른 루틴은 이어 간다.
    case keep(Set<UUID>)

    /// 그날을 포함하는 기간이 여럿이면, 어느 한 기간에서라도 유지하기로 한 루틴은 유지한다.
    static func resolve(periods: [VacationPeriod], on day: Day) -> VacationRoutinePolicy {
        let containing = periods.filter { $0.contains(day) }
        guard !containing.isEmpty else { return .normal }
        let kept = containing.reduce(into: Set<UUID>()) { $0.formUnion($1.keptRoutineIDs) }
        return kept.isEmpty ? .fullRest : .keep(kept)
    }

    var isVacation: Bool { self != .normal }

    var keepsRoutines: Bool {
        if case .keep = self { return true }
        return false
    }

    func shows(_ routineID: UUID) -> Bool {
        switch self {
        case .normal: return true
        case .fullRest: return false
        case .keep(let kept): return kept.contains(routineID)
        }
    }

    /// 보여 줄 체크만 남긴다. 남는 항목이 없는 그룹은 뺀다.
    func visible(_ sections: [CheckSection]) -> [CheckSection] {
        guard isVacation else { return sections }
        return sections.compactMap { section in
            let checks = section.checks.filter { shows($0.id) }
            return checks.isEmpty ? nil : CheckSection(group: section.group, checks: checks)
        }
    }

    /// 휴가 기간 한 줄에 붙이는 짧은 설명.
    static func modeLabel(_ period: VacationPeriod) -> String {
        period.keepsRoutines ? "루틴 \(period.keptRoutineIDs.count)개 유지" : "전체 휴식"
    }
}
