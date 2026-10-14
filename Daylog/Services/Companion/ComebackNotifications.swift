import Foundation
import Observation
import UserNotifications

/// 새싹이 복귀 알림의 단계: 마지막으로 루틴을 완료한 날부터 며칠째인가.
enum ComebackStage: Int, CaseIterable, Sendable {
    case day3 = 3, day7 = 7, day14 = 14, day30 = 30

    var title: String {
        switch self {
        case .day3: return "🌱 새싹이가 기다리고 있어요"
        case .day7: return "🌱 오랜만이에요!"
        case .day14: return "🍃 천천히 돌아와도 괜찮아요"
        case .day30: return "🌸 언제든 다시 시작할 수 있어요"
        }
    }

    var body: String {
        switch self {
        case .day3: return "오늘은 작은 습관 하나부터 시작해 볼까요?"
        case .day7: return "다시 시작하기 좋은 날이에요."
        case .day14: return "오늘 하나만 실천해 봐요."
        case .day30: return "새싹이는 여기서 기다리고 있을게요."
        }
    }
}

/// 예약할 복귀 알림 하나. 단계마다 식별자가 하나라 같은 단계가 두 번 예약되지 않는다(다시 예약하면 바뀐다).
struct PlannedComeback: Equatable, Identifiable, Sendable {
    let stage: ComebackStage
    let day: Day
    let hour: Int
    let minute: Int

    static let idPrefix = "comeback."
    static let kindKey = "kind"
    static let kind = "comeback"

    var id: String { "\(Self.idPrefix)\(stage.rawValue)" }
    /// 날짜나 시각이 바뀌었는지 비교하는 값.
    var signature: String { "\(day.key) \(hour):\(minute)" }

    /// 시간대를 적지 않아 울릴 때의 기기 시간대로 해석된다(루틴 알림과 같다).
    var dateComponents: DateComponents {
        DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute)
    }
}

/// 복귀 알림 계산에 필요한 값. 모두 기존 기록과 설정에서 나온다.
struct ComebackInput {
    /// 마지막으로 루틴을 하나라도 완료한 날(통계의 날짜별 결과 기준). 한 번도 없으면 nil.
    var lastCompletion: Day?
    var today: Day
    var hasActiveRoutines: Bool
    /// 휴가인 날.
    var isVacation: (Day) -> Bool
    /// 루틴이 예정된 날. 알림은 이런 날에만 보낸다(루틴이 없는 날에 "오늘 하나 실천해 봐요"라고 하지 않는다).
    var isScheduled: (Day) -> Bool
    /// 이 기기의 기록이 지금 믿을 만한가(iCloud에서 받아 오기를 마쳤는가). 아니면 예약하지 않는다.
    var dataIsCurrent: Bool
}

/// 언제 어떤 복귀 알림을 보낼지 정한다(순수 함수).
///
/// - 마지막 완료일부터 달력 날짜로 세어 3·7·14·30일째에 한 번씩. 30일째 뒤로는 보내지 않는다.
/// - 휴가인 날은 쉰 날로 세지 않는다: 휴가가 끝난 다음 날부터 다시 센다(휴가가 끝나자마자 보내지 않는다).
/// - 그날 루틴이 예정되어 있지 않으면 보내지 않고, 다음에 루틴이 있는 날로 미룬다. 미루는 사이 다음 단계가 되면 다음 단계만 보낸다.
/// - 이미 지난 시각은 예약하지 않는다. 다시 완료하면 그날부터 새로 센다.
enum ComebackPlanner {
    /// 30일째 알림을 루틴이 있는 날까지 미룰 수 있는 기간(일).
    static let carryLimit = 7

    static func plan(_ input: ComebackInput, now: Date, calendar: Calendar = .current, minutes: Int) -> [PlannedComeback] {
        guard input.dataIsCurrent, input.hasActiveRoutines, var anchor = input.lastCompletion else { return [] }
        let hour = minutes / 60, minute = minutes % 60
        let last = ComebackStage.day30.rawValue + carryLimit
        var pending: ComebackStage?
        var result: [PlannedComeback] = []
        var day = anchor.adding(days: 1)
        // 휴가가 길게 이어져도 끝나도록 오늘부터 1년까지만 본다.
        let limit = input.today.adding(days: 366)
        while day <= limit {
            defer { day = day.adding(days: 1) }
            if input.isVacation(day) {
                // 휴가는 쉰 날이 아니다. 끝난 뒤부터 다시 센다.
                anchor = day
                pending = nil
                continue
            }
            let elapsed = anchor.days(until: day)
            if elapsed > last { break }
            // 새 단계가 되면 아직 보내지 못한 앞 단계 대신 새 단계를 보낸다.
            if let stage = ComebackStage(rawValue: elapsed) { pending = stage }
            guard let stage = pending, input.isScheduled(day) else { continue }
            pending = nil
            let planned = PlannedComeback(stage: stage, day: day, hour: hour, minute: minute)
            guard let fireDate = calendar.date(from: planned.dateComponents), fireDate > now else { continue }
            result.append(planned)
            if stage == .day30 { break }
        }
        return result
    }

    /// 이 기기의 기록이 지금 믿을 만한가. 오래된 로컬 기록만 보고 예약하지 않으려고 둔다.
    /// iCloud를 쓰는데 이번 실행에서 아직 받아 오기를 마치지 않았거나, 받는 중이거나, 계정 상태를 모르면 믿지 않는다.
    static func isDataCurrent(
        syncEnabled: Bool, account: CloudSyncMonitor.Account, lastImportAt: Date?, isImporting: Bool, firstSyncActive: Bool
    ) -> Bool {
        if firstSyncActive { return false }
        guard syncEnabled else { return true }
        switch account {
        case .noAccount, .restricted, .notConfigured:
            // 이 기기에만 기록하는 상태: 받아 올 다른 기록이 없다.
            return true
        case .checking, .temporarilyUnavailable, .unknown:
            return false
        case .available:
            return lastImportAt != nil && !isImporting
        }
    }
}

/// 복귀 알림을 예약하는 알림 센터. 루틴 알림과 같은 센터를 쓰되 `comeback.` 식별자만 다룬다.
@MainActor
protocol ComebackNotificationClient: AnyObject {
    func permission() async -> NotificationPermission
    func requestPermission() async -> NotificationPermission
    /// 예약되어 있는 복귀 알림: 식별자 → 내용 비교값.
    func pendingComebacks() async -> [String: String]
    func addComeback(_ comeback: PlannedComeback) async throws
    func removePending(ids: [String])
}

extension SystemNotificationClient: ComebackNotificationClient {
    func pendingComebacks() async -> [String: String] {
        var result: [String: String] = [:]
        for request in await UNUserNotificationCenter.current().pendingNotificationRequests()
        where request.identifier.hasPrefix(PlannedComeback.idPrefix) {
            result[request.identifier] = request.content.userInfo[RoutineNotificationAction.signatureKey] as? String ?? ""
        }
        return result
    }

    func addComeback(_ comeback: PlannedComeback) async throws {
        let content = UNMutableNotificationContent()
        content.title = comeback.stage.title
        content.body = comeback.stage.body
        content.sound = .default
        content.threadIdentifier = PlannedComeback.kind
        // 버튼 없이 누르기만 한다. 누르면 오늘 화면이 열린다(루틴·날짜 정보가 없는 알림의 기본 동작).
        content.userInfo = [
            PlannedComeback.kindKey: PlannedComeback.kind,
            RoutineNotificationAction.signatureKey: comeback.signature,
        ]
        let trigger = UNCalendarNotificationTrigger(dateMatching: comeback.dateComponents, repeats: false)
        try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: comeback.id, content: content, trigger: trigger))
    }
}

extension DisabledNotificationClient: ComebackNotificationClient {
    func pendingComebacks() async -> [String: String] { [:] }
    func addComeback(_ comeback: PlannedComeback) async throws {}
}

/// 복귀 알림의 설정과 예약. 설정은 이 기기에만 저장하고(UserDefaults) 동기화하지 않는다.
/// 그래서 여러 기기를 쓰면 알림을 받을 기기 하나에서만 켤 수 있다(기본은 꺼짐).
@MainActor
@Observable
final class ComebackNotifications {
    static let enabledKey = "comebackNotificationsEnabled"
    static let minutesKey = "comebackNotificationMinutes"
    /// 기본 알림 시각: 저녁 7시.
    static let defaultMinutes = 19 * 60

    private(set) var permission: NotificationPermission = .unknown
    private(set) var isEnabled: Bool
    /// 알림 시각(자정부터의 분).
    private(set) var minutes: Int
    /// 마지막으로 맞춘 뒤 예약되어 있는 복귀 알림(울릴 순서대로).
    private(set) var scheduled: [PlannedComeback] = []
    /// iCloud 기록을 아직 받아 오지 못해 예약을 미루고 있다.
    private(set) var isWaitingForSync = false

    @ObservationIgnored private let client: ComebackNotificationClient
    @ObservationIgnored private let defaults: UserDefaults

    init(client: ComebackNotificationClient, defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        let saved = defaults.object(forKey: Self.minutesKey) as? Int
        minutes = saved.map { min(max($0, 0), 24 * 60 - 1) } ?? Self.defaultMinutes
    }

    /// 켜져 있고 권한도 있어야 실제로 울린다.
    var isActive: Bool { isEnabled && permission == .authorized }

    func refreshPermission() async {
        let updated = await client.permission()
        if updated != permission { permission = updated }
    }

    /// 켤 때 처음이면 시스템 권한을 묻는다(루틴 알림과 같은 흐름). 끄면 다음 맞추기에서 예약이 모두 지워진다.
    func setEnabled(_ enabled: Bool) async {
        if enabled { permission = await client.requestPermission() }
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
    }

    func setMinutes(_ value: Int) {
        minutes = min(max(value, 0), 24 * 60 - 1)
        defaults.set(minutes, forKey: Self.minutesKey)
    }

    /// 예약을 지금의 기록·설정에 맞춘다. 몇 번을 불러도 결과가 같다(같은 단계는 하나만, 루틴 알림은 건드리지 않는다).
    func reschedule(_ input: ComebackInput, now: Date = .now, calendar: Calendar = .current) async {
        await refreshPermission()
        isWaitingForSync = isActive && !input.dataIsCurrent
        let plan = isActive ? ComebackPlanner.plan(input, now: now, calendar: calendar, minutes: minutes) : []
        let pending = await client.pendingComebacks()
        let wanted = Set(plan.map(\.id))
        client.removePending(ids: pending.keys.filter { !wanted.contains($0) }.sorted())
        for comeback in plan where pending[comeback.id] != comeback.signature {
            try? await client.addComeback(comeback)
        }
        let confirmed = await client.pendingComebacks()
        scheduled = plan.filter { confirmed[$0.id] == $0.signature }
    }
}

extension AppStore {
    /// 복귀 알림 계산의 입력. 마지막 완료일은 통계가 이미 계산한 값이고, 앞으로의 예정은 알림 예약이 쓰는 것과 같은 `days`다.
    func comebackInput(days: [PlannedDay], dataIsCurrent: Bool) -> ComebackInput {
        let upcoming = Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        let past = Dictionary(stats.trend.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        let periods = vacationPeriods
        return ComebackInput(
            lastCompletion: stats.lastPracticedDay,
            today: today,
            hasActiveRoutines: !activeRoutines.isEmpty,
            isVacation: { day in periods.contains { $0.contains(day) } },
            isScheduled: { day in
                if let planned = upcoming[day] { return planned.sections.contains { !$0.checks.isEmpty } }
                // 지난 날짜는 통계의 판정을 쓴다. 기록 범위 밖의 아주 오래된 날짜는 예정된 것으로 본다(지난 시각이라 예약되지 않는다).
                if let outcome = past[day] { return WeeklyGrowthCalculator.isEligible(outcome) }
                return true
            },
            dataIsCurrent: dataIsCurrent
        )
    }
}
