import Foundation
import SwiftData

/// 하루치 식사 기록의 값 복사본. 통계 화면의 식사 기록 탭이 쓴다.
struct MealDay: Equatable, Identifiable, Sendable {
    let day: Day
    let breakfast: String
    let lunch: String
    let dinner: String
    let snack: String
    let memo: String

    var id: Day { day }

    /// 아침·점심·저녁·간식 중 하나라도 실제 내용이 있다. 메모만 있는 날은 "식사 기록일"로 세지 않는다.
    var hasMeal: Bool {
        [breakfast, lunch, dinner, snack].contains { !MealDay.isBlank($0) }
    }

    /// 목록에 보일 내용이 하나라도 있다(메모 포함).
    var hasAnyText: Bool {
        hasMeal || !MealDay.isBlank(memo)
    }

    /// 대소문자·한글 조합 방식 차이를 무시하고 찾는다.
    func matches(_ query: String) -> Bool {
        [breakfast, lunch, dinner, snack, memo].contains { $0.localizedStandardContains(query) }
    }

    static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum MealPeriod: String, CaseIterable, Identifiable, Sendable {
    case week, month, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "최근 7일"
        case .month: return "최근 30일"
        case .all: return "전체"
        }
    }

    /// 오늘을 포함한 일수. 전체는 nil.
    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .all: return nil
        }
    }

    func firstDay(today: Day) -> Day? {
        days.map { today.adding(days: -($0 - 1)) }
    }
}

struct MealSummary: Equatable, Sendable {
    /// 선택한 기간에 식사 내용이 있는 날 수.
    var recordedDays = 0
    /// 이번 달(앱을 쓰기 시작한 날 이후)에 식사 내용이 있는 날 수.
    var monthRecordedDays = 0
    /// 이번 달 1일과 앱을 쓰기 시작한 날 중 늦은 날부터 오늘까지의 일수.
    var monthElapsedDays = 0

    /// 아직 쓰기 시작하지 않았으면 nil.
    var monthPercent: Int? {
        Achievement.percent(done: monthRecordedDays, total: monthElapsedDays)
    }
}

struct MealPage: Equatable, Sendable {
    var days: [MealDay]
    /// 다음 페이지를 요청할 때 넘길 위치. 더 없으면 nil.
    var nextOffset: Int?
}

/// 과거 식사 기록의 조회·검색. 새 데이터를 만들지 않고 `DayRecord`를 그대로 읽는다.
///
/// 날짜 범위로만 저장소를 조회하고, 한 번에 정해진 양만 읽어 가며 내용이 있는(그리고 검색어에 맞는) 날을 모은다.
/// 그래서 몇 년치 기록이 있어도 한 번의 호출이 읽는 양이 제한된다.
/// 같은 날짜의 기록이 둘 이상이면(동기화 중복) 대표 기록 하나만 본다.
@MainActor
struct MealHistoryService {
    /// 한 번에 돌려주는 날 수.
    static let pageSize = 60
    /// 한 번의 호출에서 저장소로부터 읽는 기록 수의 상한.
    static let scanLimit = 1_500
    private static let batchSize = 300

    let context: ModelContext

    /// 날짜 내림차순의 한 페이지. 식사 4칸과 메모가 모두 빈 날은 나오지 않는다.
    func page(period: MealPeriod, query: String, today: Day, offset: Int = 0) throws -> MealPage {
        let lower = period.firstDay(today: today)?.key ?? ""
        let upper = today.key
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)

        var days: [MealDay] = []
        var seen: Set<Day> = []
        var position = offset
        var exhausted = false

        while days.count < Self.pageSize, position - offset < Self.scanLimit, !exhausted {
            var descriptor = FetchDescriptor<DayRecord>(
                predicate: #Predicate { $0.dateKey >= lower && $0.dateKey <= upper },
                sortBy: [SortDescriptor(\.dateKey, order: .reverse)]
            )
            descriptor.fetchLimit = Self.batchSize
            descriptor.fetchOffset = position
            let batch = try context.fetch(descriptor)
            position += batch.count
            exhausted = batch.count < Self.batchSize

            for record in try representatives(forKeys: Set(batch.map(\.dateKey))) {
                let day = Self.mealDay(record)
                guard day.hasAnyText, query.isEmpty || day.matches(query), seen.insert(day.day).inserted else { continue }
                days.append(day)
            }
        }
        return MealPage(days: days.sorted { $0.day > $1.day }, nextOffset: exhausted ? nil : position)
    }

    func summary(period: MealPeriod, today: Day) throws -> MealSummary {
        var summary = MealSummary()
        summary.recordedDays = try mealDayCount(from: period.firstDay(today: today), to: today)

        guard let firstUse = try firstUseDay(), firstUse <= today else { return summary }
        let monthStart = max(today.firstOfMonth, firstUse)
        summary.monthElapsedDays = monthStart.days(until: today) + 1
        summary.monthRecordedDays = try mealDayCount(from: monthStart, to: today)
        return summary
    }

    /// `month`(그 달의 아무 날)에 식사 4칸 중 하나라도 적은 날짜들. 미래는 제외.
    func mealDays(inMonth month: Day, today: Day) throws -> Set<Day> {
        let first = month.firstOfMonth
        let last = min(first.adding(days: first.daysInMonth - 1), today)
        guard first <= last else { return [] }
        let lower = first.key
        let upper = last.key
        let records = try context.fetch(FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.dateKey >= lower && $0.dateKey <= upper }
        ))
        return Set(
            Dictionary(grouping: records, by: \.dateKey)
                .values
                .compactMap { $0.min(by: DayRecordService.precedes) }
                .map(Self.mealDay)
                .filter(\.hasMeal)
                .map(\.day)
        )
    }

    /// 앱을 쓰기 시작한 날: 첫 루틴을 만든 날과, 무엇이든 처음 입력한 날 중 이른 쪽.
    /// 그 이전 날짜는 기록률의 분모에 넣지 않는다.
    func firstUseDay() throws -> Day? {
        var descriptor = FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.activityAt != nil },
            sortBy: [SortDescriptor(\.dateKey)]
        )
        descriptor.fetchLimit = 1
        let firstRecorded = try context.fetch(descriptor).first.flatMap { Day(key: $0.dateKey) }
        let firstRoutine = try SettingsService(context: context).existingSettings()?.firstRoutineDay
        return [firstRecorded, firstRoutine].compactMap { $0 }.min()
    }

    /// 식사 4칸 중 하나라도 내용이 있는 날 수. 같은 날짜의 중복 기록은 한 번만 센다.
    private func mealDayCount(from: Day?, to: Day) throws -> Int {
        let lower = from?.key ?? ""
        let upper = to.key
        let candidates = try context.fetch(FetchDescriptor<DayRecord>(
            predicate: #Predicate { $0.dateKey >= lower && $0.dateKey <= upper }
        ))
        return Dictionary(grouping: candidates, by: \.dateKey)
            .values
            .compactMap { $0.min(by: DayRecordService.precedes) }
            .filter { Self.mealDay($0).hasMeal }
            .count
    }

    /// 주어진 날짜들의 대표 기록.
    private func representatives(forKeys keys: Set<String>) throws -> [DayRecord] {
        guard !keys.isEmpty else { return [] }
        let list = Array(keys)
        let physical = try context.fetch(FetchDescriptor<DayRecord>(predicate: #Predicate { list.contains($0.dateKey) }))
        return Dictionary(grouping: physical, by: \.dateKey).values.compactMap { $0.min(by: DayRecordService.precedes) }
    }

    private static func mealDay(_ record: DayRecord) -> MealDay {
        MealDay(
            day: Day(key: record.dateKey) ?? Day(anchorDate: record.date),
            breakfast: record.breakfast, lunch: record.lunch, dinner: record.dinner,
            snack: record.snack, memo: record.mealMemo
        )
    }
}
