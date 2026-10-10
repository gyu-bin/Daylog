import Foundation
import SwiftData
import Testing
@testable import Daylog

/// 마이그레이션 검증용 저장소를 만드는 도구. 평소 테스트 실행에서는 건너뛴다.
///
/// 저장소 형식이 바뀌기 "전" 코드로 실행해서 `Fixtures/`에 고정해 둔다. 이후 버전의 테스트가
/// 이 파일을 열어 기록이 그대로 넘어오는지 확인한다.
///
///     TEST_RUNNER_DAYLOG_FIXTURE_DIR=<앱 컨테이너 안의 쓰기 가능한 폴더> xcodebuild ... \
///         test -only-testing:DaylogTests/FixtureGenerator
@MainActor
struct FixtureGenerator {
    private nonisolated static let outputDirectory = ProcessInfo.processInfo.environment["DAYLOG_FIXTURE_DIR"]

    @Test(.enabled(if: FixtureGenerator.outputDirectory != nil))
    func writeFixture() throws {
        let directory = URL(fileURLWithPath: try #require(Self.outputDirectory), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appendingPathComponent("fixture.store")
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
        }

        let today = day("2026-10-10")
        let start = today.adding(days: -20)
        let container = try DaylogStore.makeContainer(.file(storeURL))
        let context = container.mainContext
        let routines = RoutineService(context: context)
        let records = DayRecordService(context: context)

        let leave = try routines.add(title: "현관 출발", note: "기상 후 바로 나가기", timeLabel: "07:00", today: start)
        let run = try routines.add(title: "운동", note: "러닝 30분", timeLabel: "07:30", today: start)
        let read = try routines.add(title: "독서", today: start)
        let words = try routines.add(title: "영어 단어", weekdays: Weekdays.workdays, today: start)
        let review = try routines.add(title: "주간 회고", weekdays: [7], today: start)
        _ = (leave, read, review)

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
        try context.save()
        try SettingsService(context: context).setThreshold(70)

        let expected = try FixtureSnapshot.capture(context: context, today: today)
        let data = try JSONEncoder.fixture.encode(expected)
        try data.write(to: directory.appendingPathComponent("fixture.expected.json"))
        #expect(expected.records.count > 15)
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
        let records = try context.fetch(FetchDescriptor<DayRecord>(sortBy: [SortDescriptor(\.dateKey)])).map { record in
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
            )
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

extension JSONEncoder {
    static var fixture: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
