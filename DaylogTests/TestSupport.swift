import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 테스트마다 독립된 in-memory 저장소. 실제 사용자 저장소는 건드리지 않는다.
@MainActor
struct TestEnv {
    let container: ModelContainer

    init() throws {
        container = try DaylogStore.makeContainer(.inMemory)
    }

    var context: ModelContext { container.mainContext }
    var records: DayRecordService { DayRecordService(context: context) }
    var routines: RoutineService { RoutineService(context: context) }
    var stats: StatsService { StatsService(context: context) }
    var settings: SettingsService { SettingsService(context: context) }

    /// 앱을 다시 실행했을 때처럼, 저장된 내용만 보이는 새 컨텍스트.
    func freshContext() -> ModelContext {
        ModelContext(container)
    }

    /// `day`가 오늘인 것처럼 기록을 열고 앞에서부터 `done`개를 완료한다. 0개여도 기록한 날로 남긴다.
    @discardableResult
    func log(_ day: Day, done: Int) throws -> DayRecord {
        let record = try records.fetchOrCreate(day: day, today: day)
        let checks = record.checkList.sorted { $0.order < $1.order }
        for check in checks.prefix(done) {
            try records.setDone(check, true)
        }
        record.activityAt = .now
        try context.save()
        return record
    }

    @discardableResult
    func addRoutines(_ count: Int, weekdays: [Int] = Weekdays.all, today: Day) throws -> [RoutineItem] {
        try (1...count).map { try routines.add(title: "루틴 \($0)", weekdays: weekdays, today: today) }
    }
}

func day(_ key: String) -> Day {
    guard let day = Day(key: key) else {
        fatalError("잘못된 테스트 날짜: \(key)")
    }
    return day
}

/// 테스트에서 "오늘"을 바꾸기 위한 시계.
final class TestClock {
    var today: Day
    init(_ today: Day) { self.today = today }
}

// 2026-10-05 = 월요일, 2026-10-10 = 토요일, 2026-10-11 = 일요일
let monday = day("2026-10-05")
let saturday = day("2026-10-10")
let sunday = day("2026-10-11")
