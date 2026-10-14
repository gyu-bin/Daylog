import Foundation
import SwiftData

/// "다시 시작하기" 안내를 띄울 근거: 루틴이 예정돼 있었는데 아무것도 하지 않은 날이 며칠 이어졌는가.
///
/// 앱을 열었는지는 알 수 없고 추측하지도 않는다. 기록에 남은 것만 본다: 예정된 루틴이 있던 날에 완료도 건너뛰기도 없었다.
struct RestartPrompt: Equatable, Sendable {
    /// 어제부터 거슬러 올라가며 이어진, 아무것도 하지 않은 예정일 수.
    var missedDays: Int
    /// 그 앞에서 마지막으로 완료했거나 건너뛴 날. 조회한 기간(최근 30일) 안에 없으면 nil.
    var lastActiveDay: Day?
}

/// 규칙. 날짜별 판정은 통계와 같은 `DayOutcome`을 쓴다(휴가·쉬는 날·루틴 변경 이력이 이미 반영돼 있다).
enum RestartPromptPolicy {
    /// 이만큼 이어져야 안내한다.
    static let minimumMissedDays = 3

    /// 루틴이 예정돼 있던 날인가(휴가·쉬는 날·시작 전·미래가 아님).
    static func isScheduled(_ outcome: DayOutcome) -> Bool {
        switch outcome.status {
        case .recorded, .unrecorded: return outcome.total > 0
        case .vacation, .rest, .preStart, .future: return false
        }
    }

    /// 그날 무언가를 했는가: 하나라도 완료했거나, 건너뛰기로 표시했다.
    /// 건너뛴 날은 쉬기로 정한 날이지 손을 놓은 날이 아니다.
    static func isActive(_ outcome: DayOutcome) -> Bool {
        isScheduled(outcome) && (outcome.done > 0 || outcome.skipped > 0)
    }

    /// - Parameters:
    ///   - outcomes: 오늘을 포함한 최근 날짜들의 결과(`DashboardStats.trend`).
    ///   - dismissedDay: 사용자가 안내를 닫은 날. 그 뒤로 다시 무언가를 하기 전까지는 같은 기간으로 보고 띄우지 않는다.
    static func evaluate(outcomes: [DayOutcome], today: Day, dismissedDay: Day?) -> RestartPrompt? {
        if let todayOutcome = outcomes.first(where: { $0.day == today }) {
            // 휴가 중이거나, 오늘 이미 완료했거나 건너뛰기로 정했으면 안내하지 않는다.
            if todayOutcome.status == .vacation || isActive(todayOutcome) { return nil }
        }
        var missed = 0
        var lastActive: Day?
        for outcome in outcomes.filter({ $0.day < today }).sorted(by: { $0.day > $1.day }) {
            // 첫 루틴을 만들기 전의 날은 볼 것이 없다.
            if outcome.status == .preStart { break }
            guard isScheduled(outcome) else { continue }
            if isActive(outcome) {
                lastActive = outcome.day
                break
            }
            missed += 1
        }
        guard missed >= minimumMissedDays else { return nil }
        if let dismissedDay {
            // 닫은 뒤로 한 번도 하지 않았으면 같은 기간이다(마지막으로 한 날이 닫은 날보다 앞이거나, 기간 안에 없다).
            guard let lastActive, lastActive >= dismissedDay else { return nil }
        }
        return RestartPrompt(missedDays: missed, lastActiveDay: lastActive)
    }
}

extension AppStore {
    /// 지금 "다시 시작하기"를 띄울지. 전에 루틴을 완료한 적이 있는 사람에게만 띄운다(새로 시작한 사람은 대상이 아니다).
    func restartPrompt(dismissedDay: Day?) -> RestartPrompt? {
        guard stats.hasStarted,
              let prompt = RestartPromptPolicy.evaluate(outcomes: stats.trend, today: today, dismissedDay: dismissedDay)
        else { return nil }
        // 조회한 기간 안에 완료한 날이 있으면 바로 알 수 있다. 없으면(오래 쉰 경우) 저장소에서 한 번 확인한다.
        if stats.trend.contains(where: { $0.done > 0 }) { return prompt }
        var descriptor = FetchDescriptor<DayCheck>(predicate: #Predicate { $0.isDone })
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0 ? prompt : nil
    }
}
