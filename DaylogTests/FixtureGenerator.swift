import Foundation
import SQLite3
import SwiftData
import Testing
@testable import Daylog

/// 마이그레이션 검증용 저장소를 만드는 도구. 평소 테스트 실행에서는 건너뛴다.
///
/// 저장소 형식이 바뀌기 "전" 코드로 실행해서 `Fixtures/`에 고정해 둔다. 이후 버전의 테스트가
/// 이 파일을 열어 기록이 그대로 넘어오는지 확인한다.
///
/// 팀 서명된 앱의 컨테이너는 다른 프로세스가 읽을 수 없어서, 만든 저장소와 기대값을 base64로 출력한다.
///
///     TEST_RUNNER_DAYLOG_FIXTURE=1 xcodebuild ... test -only-testing:DaylogTests/FixtureGenerator > log
///     (log의 DAYLOG_FIXTURE_STORE / DAYLOG_FIXTURE_JSON 줄을 순서대로 이어 붙여 디코드한다)
@MainActor
struct FixtureGenerator {
    private nonisolated static let isRequested = ProcessInfo.processInfo.environment["DAYLOG_FIXTURE"] != nil

    @Test(.enabled(if: FixtureGenerator.isRequested))
    func writeFixture() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DaylogFixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("fixture.store")
        let today = day("2026-10-10")

        let expected = try populate(storeURL: storeURL, today: today)

        // 컨테이너가 해제된 뒤 WAL 내용을 본 파일로 합쳐 파일 하나로 만든다.
        var handle: OpaquePointer?
        #expect(sqlite3_open_v2(storeURL.path, &handle, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK)
        sqlite3_exec(handle, "PRAGMA wal_checkpoint(TRUNCATE)", nil, nil, nil)
        sqlite3_close(handle)

        emit("DAYLOG_FIXTURE_STORE", try Data(contentsOf: storeURL))
        emit("DAYLOG_FIXTURE_JSON", try JSONEncoder.fixture.encode(expected))
        #expect(expected.records.count > 15)
    }

    private func emit(_ tag: String, _ data: Data) {
        let encoded = data.base64EncodedString()
        var index = 0
        var offset = encoded.startIndex
        while offset < encoded.endIndex {
            let end = encoded.index(offset, offsetBy: 2000, limitedBy: encoded.endIndex) ?? encoded.endIndex
            print("\(tag) \(String(format: "%05d", index)) \(encoded[offset..<end])")
            offset = end
            index += 1
        }
        fflush(stdout)
    }

    private func populate(storeURL: URL, today: Day) throws -> FixtureSnapshot {
        let start = today.adding(days: -20)
        let container = try DaylogStore.makeContainer(.file(storeURL))
        let context = container.mainContext
        let routines = RoutineService(context: context)
        let records = DayRecordService(context: context)
        let edits = FieldEditService(context: context, deviceID: "fixture-mac-mini")

        try routines.add(title: "현관 출발", note: "기상 후 바로 나가기", timeLabel: "07:00", today: start)
        let run = try routines.add(title: "운동", note: "러닝 30분", timeLabel: "07:30", today: start)
        let read = try routines.add(title: "독서", today: start)
        let words = try routines.add(title: "영어 단어", weekdays: Weekdays.workdays, today: start)
        try routines.add(title: "주간 회고", weekdays: [7], today: start)
        let walk = try routines.add(title: "산책", today: start)

        // 완료 개수 패턴. nil은 앱을 열지 않은 날(미기록).
        let pattern: [Int?] = [4, 3, nil, 5, 2, 4, 4, nil, 3, 5]
        for (offset, day) in Day.range(from: start, to: today.adding(days: -1)).enumerated() {
            if offset == 8 {
                try routines.update(run, title: "운동 (러닝)", timeLabel: "07:40", today: day)
            }
            if offset == 12 {
                try routines.setArchived(words, true, today: day)
            }
            if offset == 15 {
                try routines.update(read, weekdays: [1, 3, 5, 6, 7], today: day)
            }
            guard let done = pattern[offset % pattern.count] else { continue }
            let record = try records.fetchOrCreate(day: day, today: day)
            for check in record.checkList.sorted(by: { $0.order < $1.order }).prefix(done) {
                try records.setDone(check, true)
            }
            if offset % 2 == 0 {
                records.setText("현미밥, 계란 \(offset)", at: \.lunch, of: record)
                records.setText("내일 할 일 \(offset)", at: \.tomorrowTask, of: record)
                try edits.recordEdit(dateKey: day.key, field: .lunch, value: record.lunch, now: day.anchorDate)
            }
            record.activityAt = day.anchorDate
        }
        // 열어 보기만 한 과거 날짜(자동 생성, 미기록).
        _ = try records.fetchOrCreate(day: start.adding(days: 2), today: today)

        let record = try records.fetchOrCreate(day: today, today: today)
        for check in record.checkList.sorted(by: { $0.order < $1.order }).prefix(2) {
            try records.setDone(check, true)
        }
        records.setText("그릭요거트, 블루베리", at: \.breakfast, of: record)
        records.setText("일반식\n닭가슴살 추가", at: \.lunch, of: record)
        records.setText("계란 2개", at: \.dinner, of: record)
        records.setText("바나나", at: \.snack, of: record)
        records.setText("물 2L 마심.", at: \.mealMemo, of: record)
        records.setText("기획서 정리", at: \.tomorrowTask, of: record)
        for field in DayTextField.allCases {
            try edits.recordEdit(dateKey: today.key, field: field, value: record[keyPath: field.keyPath])
        }
        try context.save()

        // 오늘 완료하지 않은 채 보관한 루틴: 오늘 목록에서는 숨김으로 남는다.
        try routines.setArchived(walk, true, today: today)

        // v1.3: 그룹을 만들고, 이름·색을 바꾸고, 항목을 옮기고, 그룹 하나는 보관한다.
        let morning = try routines.addGroup(title: "아침", colorKey: "orange")
        let evening = try routines.addGroup(title: "저녁 루틴", colorKey: "purple")
        let stretch = try routines.add(title: "스트레칭", timeLabel: "07:10", group: morning, today: today.adding(days: -6))
        try routines.add(title: "일기", timeLabel: "21:00", group: evening, today: today.adding(days: -6))
        try routines.updateGroup(morning, title: "아침 루틴", colorKey: "coral", today: today.adding(days: -4))
        try routines.move(run, to: morning, today: today.adding(days: -2))
        try routines.setGroupArchived(evening, true, today: today.adding(days: -1))
        _ = stretch

        // 다른 기기에서 들어온 같은 날짜의 기록(중복)과 편집 기록. 병합까지 끝난 상태로 고정한다.
        let duplicateDay = today.adding(days: -3)
        let duplicate = DayRecord(day: duplicateDay, now: Date(timeIntervalSince1970: 4_102_444_800))
        duplicate.dinner = "다른 Mac에서 쓴 저녁"
        duplicate.activityAt = duplicateDay.anchorDate
        context.insert(duplicate)
        let other = FieldEdit(dateKey: today.key, field: DayTextField.snack.rawValue, deviceID: "fixture-macbook")
        other.value = "견과류"
        other.editedAt = today.anchorDate
        context.insert(other)
        try context.save()
        try SyncReconciler(context: context, deviceID: "fixture-mac-mini").reconcile(today: today)
        try SettingsService(context: context).setThreshold(70)

        return try FixtureSnapshot.capture(context: context, today: today)
    }
}

/// 저장소 내용과 통계를 값으로 떠 둔 것. 마이그레이션 전후를 비교한다.
struct FixtureSnapshot: Codable, Equatable {
    struct Routine: Codable, Equatable {
        var id: UUID
        var title: String
        var note: String
        var timeLabel: String
        var weekdays: [Int]
        var order: Int
        var isArchived: Bool
    }

    struct Revision: Codable, Equatable {
        var routineID: UUID
        var effectiveFromKey: String
        var title: String
        var timeLabel: String
        var weekdays: [Int]
        var isArchived: Bool
        var order: Int
    }

    struct Check: Codable, Equatable {
        var routineID: UUID
        var title: String
        var timeLabel: String
        var note: String
        var order: Int
        var isDone: Bool
    }

    struct Record: Codable, Equatable {
        var dateKey: String
        var isRecorded: Bool
        var breakfast: String
        var lunch: String
        var dinner: String
        var snack: String
        var mealMemo: String
        var tomorrowTask: String
        var checks: [Check]
    }

    struct Stats: Codable, Equatable {
        var threshold: Int
        var firstDayKey: String?
        var todayDone: Int
        var todayTotal: Int
        var weekPercents: [Int?]
        var weeklyAverage: Int?
        var currentStreak: Int
        var longestStreak: Int
        var trendPercents: [Int?]
        var routineRates: [String]
    }

    var routines: [Routine]
    var revisions: [Revision]
    var records: [Record]
    var settingsCount: Int
    var stats: Stats
    /// "날짜|칸|기기|값". v1.2 형식부터 있다.
    var fieldEdits: [String]?
    /// v1.3 형식부터 있다: 그룹, 항목의 소속, 체크·이력의 그룹 스냅샷, 그룹별 달성률.
    var groups: [String]?
    var routineGroups: [String]?
    var checkGroups: [String]?
    var revisionGroups: [String]?
    var groupRates: [String]?

    @MainActor
    static func capture(context: ModelContext, today: Day) throws -> FixtureSnapshot {
        let routines = try context.fetch(FetchDescriptor<RoutineItem>(sortBy: [SortDescriptor(\.order)])).map {
            Routine(id: $0.id, title: $0.title, note: $0.note, timeLabel: $0.timeLabel,
                    weekdays: $0.weekdays, order: $0.order, isArchived: $0.isArchived)
        }
        let revisions = try context.fetch(FetchDescriptor<RoutineRevision>()).map {
            Revision(routineID: $0.routineID, effectiveFromKey: $0.effectiveFromKey, title: $0.title,
                     timeLabel: $0.timeLabel, weekdays: Weekdays.days(mask: $0.weekdayMask),
                     isArchived: $0.isArchived, order: $0.order)
        }.sorted { ($0.routineID.uuidString, $0.effectiveFromKey) < ($1.routineID.uuidString, $1.effectiveFromKey) }
        let records = try context.fetch(
            FetchDescriptor<DayRecord>(sortBy: [SortDescriptor(\.dateKey), SortDescriptor(\.createdAt)])
        ).map { record in
            Record(
                dateKey: record.dateKey, isRecorded: record.isRecorded,
                breakfast: record.breakfast, lunch: record.lunch, dinner: record.dinner,
                snack: record.snack, mealMemo: record.mealMemo, tomorrowTask: record.tomorrowTask,
                checks: FixtureSnapshot.checks(of: record)
            )
        }
        let stats = try StatsService(context: context).dashboard(today: today)
        return FixtureSnapshot(
            routines: routines,
            revisions: revisions,
            records: records,
            settingsCount: try context.fetchCount(FetchDescriptor<AppSettings>()),
            stats: Stats(
                threshold: stats.threshold,
                firstDayKey: stats.firstDay?.key,
                todayDone: stats.today.done,
                todayTotal: stats.today.total,
                weekPercents: stats.week.map(\.percent),
                weeklyAverage: stats.weeklyAverage,
                currentStreak: stats.currentStreak,
                longestStreak: stats.longestStreak,
                trendPercents: stats.trend.map(\.percent),
                routineRates: stats.routineRates.map { "\($0.title)|\($0.done)/\($0.scheduled)|\($0.isArchived)" }
            ),
            fieldEdits: try context.fetch(FetchDescriptor<FieldEdit>())
                .map { "\($0.dateKey)|\($0.field)|\($0.deviceID)|\($0.value)" }
                .sorted(),
            groups: try context.fetch(FetchDescriptor<RoutineGroup>())
                .map { "\($0.id)|\($0.title)|\($0.colorKey)|\($0.order)|\($0.isArchived)" }
                .sorted(),
            routineGroups: try context.fetch(FetchDescriptor<RoutineItem>())
                .map { "\($0.id)|\($0.groupID?.uuidString ?? "nil")|\($0.order)" }
                .sorted(),
            checkGroups: try context.fetch(FetchDescriptor<DayCheck>())
                .map { "\($0.record?.dateKey ?? "-")|\($0.routineID)|\($0.groupID?.uuidString ?? "nil")|\($0.groupTitle)|\($0.groupColorKey)|\($0.groupOrder)|\($0.isHidden)" }
                .sorted(),
            revisionGroups: try context.fetch(FetchDescriptor<RoutineRevision>())
                .map { "\($0.routineID)|\($0.effectiveFromKey)|\($0.groupID?.uuidString ?? "nil")|\($0.groupTitle)|\($0.groupColorKey)|\($0.groupOrder)|\($0.isArchived)" }
                .sorted(),
            groupRates: stats.groupRates.map { "\($0.groupID)|\($0.title)|\($0.colorKey)|\($0.done)/\($0.scheduled)" }
        )
    }

    @MainActor
    private static func checks(of record: DayRecord) -> [Check] {
        record.checkList
            .map {
                Check(routineID: $0.routineID, title: $0.title, timeLabel: $0.timeLabel,
                      note: $0.note, order: $0.order, isDone: $0.isDone)
            }
            .sorted { ($0.order, $0.routineID.uuidString) < ($1.order, $1.routineID.uuidString) }
    }
}

extension FixtureSnapshot {
    /// 그룹이 없던 형식의 기대값과 비교할 때 쓴다.
    mutating func clearGroupInfo() {
        groups = nil
        routineGroups = nil
        checkGroups = nil
        revisionGroups = nil
        groupRates = nil
    }
}

extension JSONEncoder {
    static var fixture: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
