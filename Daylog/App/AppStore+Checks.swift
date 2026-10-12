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
        let status: DayStatus
        if isVacation(on: selectedDay) {
            status = .vacation
        } else if selectedDay > today {
            status = .future
        } else if stats.firstDay.map({ selectedDay < $0 }) ?? true {
            status = .preStart
        } else if total == 0 {
            status = .rest
        } else {
            status = record?.isRecorded == true ? .recorded : .unrecorded
        }
        return DayOutcome(day: selectedDay, status: status, done: done, total: total)
    }

    /// 저장된 값을 기준으로 뒤집는다. 화면이 들고 있던 값에 기대지 않는다.
    func toggleDone(routineID: UUID) {
        guard let check = checks.first(where: { $0.routineID == routineID }) else { return }
        setDone(routineID: routineID, !check.isDone)
    }

    /// 보고 있는 날짜의 완료 여부를 저장한다.
    func setDone(routineID: UUID, _ isDone: Bool) {
        setDone(routineID: routineID, on: selectedDay, isDone)
    }

    /// 그 날짜의 완료 여부를 저장하고 화면의 값과 통계를 다시 계산한다. 보고 있는 날짜가 아니어도 된다
    /// (메뉴 막대, 알림의 [완료], 위젯). 이미 그 값이거나 저장에 실패해도 화면의 값은 저장된 값으로 맞춰진다.
    /// 건너뛴 항목을 체크하면 완료가 되고, 해제하면 미완료가 된다.
    func setDone(routineID: UUID, on day: Day, _ isDone: Bool, at now: Date = .now) {
        setStatus(routineID: routineID, on: day, isDone ? .done : .pending, at: now)
    }

    /// 보고 있는 날짜의 루틴을 건너뛰거나, 건너뛰기를 취소한다.
    func setSkipped(routineID: UUID, _ isSkipped: Bool) {
        setSkipped(routineID: routineID, on: selectedDay, isSkipped)
    }

    /// 건너뛰기: 그날 그 루틴을 쉬기로 한다. 완료한 항목을 건너뛰면 완료 대신 건너뛰기가 된다(하루에 상태는 하나다).
    /// 취소: 건너뛴 항목만 미완료로 돌린다. 그 사이 다른 곳에서 완료했다면 완료를 그대로 둔다.
    func setSkipped(routineID: UUID, on day: Day, _ isSkipped: Bool, at now: Date = .now) {
        setStatus(routineID: routineID, on: day, isSkipped ? .skipped : .pending, onlyFrom: isSkipped ? nil : .skipped, at: now)
    }

    /// 상태 전환의 한 곳. 사용자가 고른 전환만 여기로 오고, 동기화·일정 변경·휴가는 상태를 바꾸지 않는다.
    /// - Parameter expected: 지금 이 상태일 때만 바꾼다. nil이면 어느 상태에서든 바꾼다.
    func setStatus(
        routineID: UUID, on day: Day, _ status: CheckStatus, onlyFrom expected: CheckStatus? = nil, at now: Date = .now
    ) {
        guard day <= today else { return }
        perform {
            let record = try day == selectedDay && self.record != nil
                ? self.record
                : DayRecordService(context: context).fetchOrCreate(day: day, today: today)
            guard let record, let check = record.checkList.first(where: { $0.routineID == routineID }) else { return }
            let edits = FieldEditService(context: context, deviceID: deviceID)
            let current = try edits.status(of: check, dateKey: record.dateKey)
            guard current != status, expected == nil || expected == current else { return }
            // 이 기기가 이 값을 정했다는 기록을 함께 남긴다(다른 기기의 늦은 변경과 순서를 가리기 위해).
            try edits.recordCheck(dateKey: record.dateKey, routineID: routineID, status: status, now: now)
            try DayRecordService(context: context).setStatus(check, status, now: now)
        }
        reloadStats()
    }

    /// 그 날짜에 건너뛴 루틴. 읽지 못하면 건너뛴 것이 없는 것으로 본다(체크 목록은 그대로 보여 준다).
    func skippedRoutines(on day: Day) -> Set<UUID> {
        var skipped: Set<UUID> = []
        perform { skipped = try FieldEditService(context: context, deviceID: deviceID).skippedRoutines(dateKey: day.key) }
        return skipped
    }

    /// 보고 있는 날짜의 체크를 그날의 그룹별로 묶은 값 사본. 그룹 순서 → 항목 순서.
    /// 휴가인 날은 그날의 정책대로 보여 줄 것만 남긴다(저장된 체크는 그대로다).
    func makeCheckSections() -> [CheckSection] {
        routinePolicy(on: selectedDay).visible(Self.sections(of: checks, skipped: skippedRoutines(on: selectedDay)))
    }

    /// 실제 오늘의 체크. 다른 날짜를 보고 있을 때 쓴다(오늘을 보고 있으면 `checkSections`와 같다).
    func makeTodaySections() -> [CheckSection] {
        var result: [CheckSection] = []
        let skipped = skippedRoutines(on: today)
        perform {
            result = Self.sections(
                of: try DayRecordService(context: context).fetchOrCreate(day: today, today: today).checkList, skipped: skipped
            )
        }
        return routinePolicy(on: today).visible(result)
    }

    /// - Parameter skipped: 그날 건너뛴 루틴. 완료한 항목은 여기 들어 있어도 완료로 본다.
    static func sections(of checks: [DayCheck], skipped: Set<UUID> = []) -> [CheckSection] {
        var sections: [CheckSection] = []
        for check in checks {
            let value = CheckValue(
                id: check.routineID, title: check.title, timeLabel: check.timeLabel, note: check.note, isDone: check.isDone,
                isSkipped: !check.isDone && skipped.contains(check.routineID)
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
    /// 사용자가 그날 쉬기로 한 항목. 완료한 항목에는 켜지지 않는다.
    var isSkipped: Bool = false

    var status: CheckStatus { isDone ? .done : isSkipped ? .skipped : .pending }
    /// 완료했거나 건너뛰어서 오늘 더 챙길 것이 없다(다음 루틴·알림에서 뺀다).
    var isSettled: Bool { isDone || isSkipped }
}

/// 하루의 체크 목록에서 한 그룹에 해당하는 부분. 그룹 모습은 그날의 스냅샷이다.
struct CheckSection: Identifiable, Equatable {
    let group: GroupSnapshot
    var checks: [CheckValue]

    var id: UUID { group.id }
    var done: Int { checks.filter(\.isDone).count }
    var skipped: Int { checks.filter(\.isSkipped).count }
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

    /// 고르는 규칙은 `NextRoutine`(위젯과 공유)에 있다.
    static func pick(from sections: [CheckSection], nowMinutes: Int) -> NextCheck? {
        let all = sections.flatMap { section in section.checks.map { (check: $0, group: section.group) } }
        guard let pick = NextRoutine.pick(
            timeLabels: all.map(\.check.timeLabel), isDone: all.map(\.check.isSettled), nowMinutes: nowMinutes
        ) else { return nil }
        return NextCheck(check: all[pick.index].check, group: all[pick.index].group, minutes: pick.minutes, isOverdue: pick.isOverdue)
    }
}
