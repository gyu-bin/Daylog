import Foundation

/// 첫 실행 때 보여 주는 일반적인 예시. 개인 데이터가 아니다.
enum RoutineSuggestions {
    static let all = ["운동", "독서", "명상", "물 2L", "일기", "일찍 자기", "산책"]

    static func available(existingTitles: [String]) -> [String] {
        let existing = Set(existingTitles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        return all.filter { !existing.contains($0) }
    }
}
