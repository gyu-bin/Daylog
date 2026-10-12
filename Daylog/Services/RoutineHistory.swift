import Foundation
import SwiftData

/// 루틴 한 번의 수행 상태. 달성률 계산과 달리 "하지 않은 것"을 이유별로 나눠 보여 준다.
enum RoutineMarkState: Equatable, Sendable {
    case done
    /// 사용자가 쉬기로 했다. 달성률에서는 미달성이다.
    case skipped
    /// 지난 날짜인데 체크하지 않았다. 실패로 단정하지 않고 "기록 없음"으로 둔다.
    case missed
    /// 오늘이고 아직 체크하지 않았다.
    case pending
    /// 휴가인 날. 체크했더라도 통계에서 빠지므로 따로 표시한다.
    case vacation

    var label: String {
        switch self {
        case .done: return "완료"
        case .skipped: return "건너뛰기"
        case .missed: return "기록 없음"
        case .pending: return "진행 중"
        case .vacation: return "휴가"
        }
    }
}

struct RoutineMark: Equatable, Identifiable, Sendable {
    let day: Day
    let state: RoutineMarkState

    var id: Day { day }
}

/// 루틴 하나의 최근 수행 기록. 그 루틴이 예정된 날만 한 번으로 센다(예정이 없던 날은 들어가지 않는다).
struct RoutineHistory: Equatable, Identifiable, Sendable {
    /// 한 줄에 보여 주는 최대 횟수. 좁은 화면은 `compactCount`만큼만 쓴다.
    static let wideCount = 14
    static let compactCount = 7
    /// 얼마나 거슬러 올라가 찾는가(오늘 포함). 주 1회 루틴도 `wideCount`번을 채울 수 있는 길이다.
    static let lookbackDays = 120

    struct Summary: Equatable, Sendable {
        var done = 0
        var skipped = 0
        var missed = 0
        var pending = 0
        var vacation = 0

        init(_ marks: [RoutineMark]) {
            for mark in marks {
                switch mark.state {
                case .done: done += 1
                case .skipped: skipped += 1
                case .missed: missed += 1
                case .pending: pending += 1
                case .vacation: vacation += 1
                }
            }
        }

        /// "완료 9 · 건너뛰기 2 · 기록 없음 3". 진행 중과 휴가는 있을 때만 붙인다.
        var text: String {
            var parts = ["완료 \(done)", "건너뛰기 \(skipped)", "기록 없음 \(missed)"]
            if pending > 0 { parts.append("진행 중 \(pending)") }
            if vacation > 0 { parts.append("휴가 \(vacation)") }
            return parts.joined(separator: " · ")
        }
    }

    let routineID: UUID
    let title: String
    let colorKey: String
    let groupTitle: String
    /// 날짜 오름차순. 가장 최근 것이 맨 뒤.
    let marks: [RoutineMark]

    var id: UUID { routineID }

    /// 가장 최근 `count`번.
    func recent(_ count: Int) -> [RoutineMark] {
        Array(marks.suffix(count))
    }
}

extension StatsSource {
    /// 루틴별 수행 상태. 날짜 오름차순이고, 그 루틴이 예정된 날만 들어간다.
    /// 판정 순서는 통계와 같다: 휴가가 먼저, 그다음 저장된 스냅샷, 열지 않은 날은 당시의 루틴 이력.
    func routineMarks(on days: [Day], today: Day) -> [UUID: [RoutineMark]] {
        var marks: [UUID: [RoutineMark]] = [:]
        for day in days.sorted() {
            guard day <= today, let firstDay, day >= firstDay else { continue }
            let unchecked: RoutineMarkState = day == today ? .pending : .missed
            if let record = records[day] {
                for check in record.checks {
                    let state: RoutineMarkState = isVacation(day) ? .vacation
                        : check.isDone ? .done
                        : record.skipped.contains(check.routineID) ? .skipped
                        : unchecked
                    marks[check.routineID, default: []].append(RoutineMark(day: day, state: state))
                }
            } else {
                for snapshot in resolver.scheduled(on: day) {
                    marks[snapshot.routineID, default: []].append(
                        RoutineMark(day: day, state: isVacation(day) ? .vacation : unchecked)
                    )
                }
            }
        }
        return marks
    }
}

extension StatsService {
    /// 지금 쓰는 루틴들의 최근 수행 기록. 루틴 목록과 같은 순서다.
    /// 보관·삭제한 루틴은 넣지 않는다(지난 달성률은 항목별 달성률 표에 계속 나온다).
    func routineHistories(today: Day, count: Int = RoutineHistory.wideCount) throws -> [RoutineHistory] {
        guard let firstDay = try SettingsService(context: context).existingSettings()?.firstRoutineDay,
              firstDay <= today else { return [] }
        let start = max(firstDay, today.adding(days: -(RoutineHistory.lookbackDays - 1)))
        let marks = try loadSource(from: start, to: today).routineMarks(on: Day.range(from: start, to: today), today: today)
        let service = RoutineService(context: context)
        let groups = Dictionary(uniqueKeysWithValues: try service.groups(includingRemoved: true).map { ($0.id, $0) })
        return try service.routines().compactMap { routine in
            guard !routine.isArchived, let all = marks[routine.id], !all.isEmpty else { return nil }
            let group = groups[routine.effectiveGroupID]
            return RoutineHistory(
                routineID: routine.id, title: routine.title,
                colorKey: group?.colorKey ?? RoutineGroup.defaultColorKey,
                groupTitle: group?.title ?? RoutineGroup.defaultTitle,
                marks: Array(all.suffix(count))
            )
        }
    }
}
