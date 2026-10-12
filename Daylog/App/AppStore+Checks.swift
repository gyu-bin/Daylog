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
    func setDone(routineID: UUID, on day: Day, _ isDone: Bool, at now: Date = .now) {
        guard day <= today else { return }
        perform {
            let record = try day == selectedDay && self.record != nil
                ? self.record
                : DayRecordService(context: context).fetchOrCreate(day: day, today: today)
            guard let record, let check = record.checkList.first(where: { $0.routineID == routineID }),
                  check.isDone != isDone else { return }
            // 이 기기가 이 값을 정했다는 기록을 함께 남긴다(다른 기기의 늦은 변경과 순서를 가리기 위해).
            try FieldEditService(context: context, deviceID: deviceID)
                .recordCheck(dateKey: record.dateKey, routineID: routineID, isDone: isDone, now: now)
            try DayRecordService(context: context).setDone(check, isDone, now: now)
        }
        reloadStats()
    }

    /// 보고 있는 날짜의 체크를 그날의 그룹별로 묶은 값 사본. 그룹 순서 → 항목 순서.
    /// 휴가인 날은 그날의 정책대로 보여 줄 것만 남긴다(저장된 체크는 그대로다).
    func makeCheckSections() -> [CheckSection] {
        routinePolicy(on: selectedDay).visible(Self.sections(of: checks))
    }

    /// 실제 오늘의 체크. 다른 날짜를 보고 있을 때 쓴다(오늘을 보고 있으면 `checkSections`와 같다).
    func makeTodaySections() -> [CheckSection] {
        var result: [CheckSection] = []
        perform {
            result = Self.sections(of: try DayRecordService(context: context).fetchOrCreate(day: today, today: today).checkList)
        }
        return routinePolicy(on: today).visible(result)
    }

    static func sections(of checks: [DayCheck]) -> [CheckSection] {
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

    /// 고르는 규칙은 `NextRoutine`(위젯과 공유)에 있다.
    static func pick(from sections: [CheckSection], nowMinutes: Int) -> NextCheck? {
        let all = sections.flatMap { section in section.checks.map { (check: $0, group: section.group) } }
        guard let pick = NextRoutine.pick(
            timeLabels: all.map(\.check.timeLabel), isDone: all.map(\.check.isDone), nowMinutes: nowMinutes
        ) else { return nil }
        return NextCheck(check: all[pick.index].check, group: all[pick.index].group, minutes: pick.minutes, isOverdue: pick.isOverdue)
    }
}
