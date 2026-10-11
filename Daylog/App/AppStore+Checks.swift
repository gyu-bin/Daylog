import Foundation

/// 보고 있는 날짜의 체크: 화면이 읽는 값 사본과 완료/해제.
extension AppStore {
    /// 보고 있는 날짜의 체크(모델 객체). 값을 바꿀 때만 쓰고, 화면은 `checkSections`를 읽는다.
    var checks: [DayCheck] {
        record?.checkList ?? []
    }

    /// 보고 있는 날짜의 달성 결과. 오늘이면 통계와 같은 값이다.
    var selectedOutcome: DayOutcome {
        let total = checkSections.reduce(0) { $0 + $1.total }
        let done = checkSections.reduce(0) { $0 + $1.done }
        return DayOutcome(day: selectedDay, status: total == 0 ? .rest : .recorded, done: done, total: total)
    }

    /// 저장된 값을 기준으로 뒤집는다. 화면이 들고 있던 값에 기대지 않는다.
    func toggleDone(routineID: UUID) {
        guard let check = checks.first(where: { $0.routineID == routineID }) else { return }
        setDone(routineID: routineID, !check.isDone)
    }

    /// 완료 여부를 저장하고 화면의 값과 통계를 다시 계산한다.
    /// 이미 그 값이거나 저장에 실패해도 화면의 값은 저장된 값으로 맞춰진다.
    func setDone(routineID: UUID, _ isDone: Bool) {
        if let check = checks.first(where: { $0.routineID == routineID }), check.isDone != isDone {
            perform {
                // 이 기기가 이 값을 정했다는 기록을 함께 남긴다(다른 Mac의 늦은 변경과 순서를 가리기 위해).
                try FieldEditService(context: context, deviceID: deviceID)
                    .recordCheck(dateKey: check.record?.dateKey ?? selectedDay.key, routineID: routineID, isDone: isDone)
                try DayRecordService(context: context).setDone(check, isDone)
            }
        }
        reloadStats()
    }

    /// 보고 있는 날짜의 체크를 그날의 그룹별로 묶은 값 사본. 그룹 순서 → 항목 순서.
    func makeCheckSections() -> [CheckSection] {
        var sections: [CheckSection] = []
        for check in checks {
            let value = CheckValue(
                id: check.routineID, title: check.title, timeLabel: check.timeLabel, note: check.note, isDone: check.isDone
            )
            if let index = sections.firstIndex(where: { $0.group.id == check.group.id }) {
                sections[index].checks.append(value)
            } else {
                sections.append(CheckSection(group: check.group, checks: [value]))
            }
        }
        return sections
    }
}

/// 뷰가 모델 객체를 붙잡지 않도록 값으로 넘기는 체크 한 줄.
struct CheckValue: Identifiable, Equatable {
    let id: UUID
    let title: String
    let timeLabel: String
    let note: String
    let isDone: Bool
}

/// 하루의 체크 목록에서 한 그룹에 해당하는 부분. 그룹 모습은 그날의 스냅샷이다.
struct CheckSection: Identifiable, Equatable {
    let group: GroupSnapshot
    var checks: [CheckValue]

    var id: UUID { group.id }
    var done: Int { checks.filter(\.isDone).count }
    var total: Int { checks.count }
    var ratio: Double? { Achievement.ratio(done: done, total: total) }
    var percent: Int? { Achievement.percent(done: done, total: total) }
}

/// 오늘 화면에 띄울 "다음 루틴": 시간이 정해진, 아직 하지 않은 항목 가운데 하나.
struct NextCheck: Equatable {
    let check: CheckValue
    let group: GroupSnapshot
    let minutes: Int
    /// 예정 시간이 이미 지났다.
    let isOverdue: Bool

    /// 지금 이후로 가장 이른 것. 남은 것이 모두 지난 시간이면 그중 가장 이른 것(밀린 것부터).
    /// 시간이 없거나 시각으로 읽히지 않는 항목은 고르지 않는다.
    static func pick(from sections: [CheckSection], nowMinutes: Int) -> NextCheck? {
        let pending = sections.flatMap { section in
            section.checks.compactMap { check -> NextCheck? in
                guard !check.isDone, let minutes = TimeLabel.minutes(check.timeLabel) else { return nil }
                return NextCheck(check: check, group: section.group, minutes: minutes, isOverdue: minutes < nowMinutes)
            }
        }
        // 같은 시각이면 목록 순서를 따른다(정렬이 순서를 보존하지 않으므로 순번을 함께 본다).
        let ordered = pending.enumerated().sorted { ($0.element.minutes, $0.offset) < ($1.element.minutes, $1.offset) }.map(\.element)
        return ordered.first { !$0.isOverdue } ?? ordered.first
    }
}
