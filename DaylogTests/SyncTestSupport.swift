import Foundation
import SwiftData
import Testing
@testable import Daylog

// 동기화 테스트 공용 도구: 다른 기기에서 들어온 데이터를 한 저장소 안에서 재현한다.

/// 다른 기기에서 동기화로 들어온 것처럼 같은 날짜의 기록을 하나 더 넣는다.
@MainActor
@discardableResult
func insertRemoteRecord(
    _ env: TestEnv,
    day: Day,
    createdAt: Date,
    syncID: UUID = UUID(),
    done: Set<UUID> = [],
    routines: [RoutineItem]
) -> DayRecord {
    let record = DayRecord(day: day, now: createdAt)
    record.syncID = syncID
    env.context.insert(record)
    for routine in routines {
        let check = DayCheck(routine: routine)
        check.isDone = done.contains(routine.id)
        record.attach(check)
    }
    if !done.isEmpty { record.activityAt = createdAt }
    return record
}

let thisMac = "mac-mini"
let otherMac = "macbook"

@MainActor
func reconcile(_ env: TestEnv, today: Day = saturday, as device: String = thisMac) throws -> SyncReconciler.Report {
    try SyncReconciler(context: env.context, deviceID: device).reconcile(today: today)
}

/// 앱에서 사용자가 칸을 고친 것과 같은 효과: 값을 쓰고, 그 기기의 편집 기록을 남긴다.
@MainActor
func type(
    _ env: TestEnv, _ value: String, in field: DayTextField, of record: DayRecord,
    on device: String = thisMac, at time: Date = .now
) throws {
    record[keyPath: field.keyPath] = value
    record.activityAt = time
    try FieldEditService(context: env.context, deviceID: device)
        .recordEdit(dateKey: record.dateKey, field: field, value: value, now: time)
}

let earlier = Date(timeIntervalSince1970: 1_000)
let later = Date(timeIntervalSince1970: 2_000_000_000_000)
