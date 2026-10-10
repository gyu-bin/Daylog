import Foundation

extension RoutineService {
    // MARK: - 입력 검증

    static func validatedTitle(_ raw: String) throws -> String {
        let title = trimmed(raw)
        guard !title.isEmpty else { throw DaylogError.emptyTitle }
        return String(title.prefix(maxTitleLength))
    }

    static func validatedGroupTitle(_ raw: String) throws -> String {
        let title = trimmed(raw)
        guard !title.isEmpty else { throw DaylogError.emptyTitle }
        return String(title.prefix(maxGroupTitleLength))
    }

    static func validatedWeekdays(_ raw: [Int]) throws -> [Int] {
        let weekdays = Array(Set(raw.filter { (1...7).contains($0) })).sorted()
        guard !weekdays.isEmpty else { throw DaylogError.noWeekdays }
        return weekdays
    }

    static func validatedTimeLabel(_ raw: String) -> String {
        String(trimmed(raw).prefix(maxTimeLabelLength))
    }

    static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
