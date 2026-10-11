import Combine
import CoreData
import Foundation
import UserNotifications
#if os(iOS)
import WidgetKit
#endif

/// 창이 없어도 살아 있어야 하는 일들: 날짜 변경·외부 변경 받기, 알림 예약, 위젯 데이터, 알림 버튼 처리.
/// macOS에서는 창을 닫아도 메뉴 막대가 남으므로, 이 일들을 화면(RootView)이 아니라 여기서 맡는다.
@MainActor
final class AppRuntime: NSObject {
    static private(set) var shared: AppRuntime?

    let store: AppStore
    let notifications: RoutineNotifications
    private let bridge: WidgetBridge?
    private var cancellables = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?
    private var isRefreshing = false
    private var needsRefresh = false

    init(
        store: AppStore, notifications: RoutineNotifications,
        bridge: WidgetBridge? = .shared, defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.notifications = notifications
        self.bridge = bridge
    }

    /// 앱이 시작할 때 한 번. `installDelegate`가 참이면 알림 버튼을 이 객체가 받는다
    /// (앱이 꺼진 상태에서 눌린 버튼도 받으려면 실행이 끝나기 전에 걸어야 한다).
    func start(installDelegate: Bool) {
        Self.shared = self
        if installDelegate {
            UNUserNotificationCenter.current().delegate = self
        }
        store.onReload = { [weak self] in self?.scheduleRefresh() }

        let center = NotificationCenter.default
        // 자정, 앱 활성화, 잠자기 해제, 시계·시간대 변경.
        Publishers.MergeMany([
            center.publisher(for: .NSCalendarDayChanged).eraseToAnyPublisher(),
            center.publisher(for: .NSSystemTimeZoneDidChange).eraseToAnyPublisher(),
            center.publisher(for: .NSSystemClockDidChange).eraseToAnyPublisher(),
            center.publisher(for: Platform.didBecomeActive).eraseToAnyPublisher(),
            Platform.timeMayHaveJumped.eraseToAnyPublisher(),
        ])
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            MainActor.assumeIsolated {
                self?.store.refreshToday()
                // 날짜가 그대로여도 시간대가 바뀌었으면 알림이 울릴 시각이 달라진다.
                self?.scheduleRefresh()
            }
        }
        .store(in: &cancellables)

        // 다른 기기의 변경이 iCloud를 통해 저장소에 들어왔을 수 있는 시점: 저장소 변경 알림과 앱 활성화.
        // 자체 폴링은 하지 않는다. 가져오기 자체는 시스템이 알아서 한다.
        Publishers.Merge(
            center.publisher(for: .NSPersistentStoreRemoteChange),
            center.publisher(for: Platform.didBecomeActive)
        )
        .debounce(for: .milliseconds(700), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            MainActor.assumeIsolated {
                self?.drainWidgetChecks()
                self?.store.handleExternalChanges()
            }
        }
        .store(in: &cancellables)

        Publishers.Merge(
            center.publisher(for: Platform.willResignActive),
            center.publisher(for: Platform.willTerminate)
        )
        .sink { [weak self] _ in
            MainActor.assumeIsolated { self?.store.flush() }
        }
        .store(in: &cancellables)

        drainWidgetChecks()
        scheduleRefresh()
    }

    // MARK: - 알림 예약과 위젯 데이터

    /// 변경이 몰려 올 때(글자 입력, 가져오기) 한 번만 맞추도록 잠깐 모은다.
    func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.refreshNow()
        }
    }

    func refreshNow() async {
        needsRefresh = true
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        repeat {
            needsRefresh = false
            let days = store.upcomingDays(count: RoutineNotificationPlanner.horizonDays)
            store.perform { try publishWidgetSnapshot(days) }
            await notifications.reschedule(days: days)
        } while needsRefresh
    }

    private func publishWidgetSnapshot(_ days: [PlannedDay]) throws {
        guard let bridge else { return }
        let snapshot = WidgetSnapshot.make(days: days, hasRoutines: !store.activeRoutines.isEmpty)
        // 내용이 바뀌었을 때만 위젯을 새로 그리게 한다. 시스템은 새로 고침 횟수를 제한한다.
        if try bridge.writeSnapshot(snapshot) {
            reloadWidgets()
        }
    }

    /// A journal entry is acknowledged only after its database save AND confirmed snapshot publication.
    /// A crash at any earlier point leaves a replayable explicit target; a failure cannot discard later requests.
    @discardableResult
    func drainWidgetChecks(apply: ((PendingCheck) throws -> Void)? = nil) -> Bool {
        guard let bridge else { return false }
        return store.perform {
            let pending = try bridge.pendingChecks()
            guard !pending.isEmpty else { return }
            var confirmed: [PendingCheck] = []
            var failure: Error?
            for check in pending {
                do {
                    if let apply { try apply(check) } else { try store.applyWidgetCheck(check) }
                    confirmed.append(check)
                } catch {
                    failure = error
                    break
                }
            }
            store.reloadStats()
            try publishWidgetSnapshot(store.upcomingDays(count: WidgetSnapshot.dayCount))
            try bridge.acknowledge(confirmed)
            reloadWidgets()
            if let failure { throw failure }
        }
    }

    /// Called by the app-process intent, after its target has been durably journaled.
    func commitWidgetChecks() async -> Bool {
        store.refreshToday()
        store.handleExternalChanges()
        let succeeded = drainWidgetChecks()
        await refreshNow()
        return succeeded
    }

    private func reloadWidgets() {
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - 알림 버튼과 링크

    /// 알림의 [완료]·[나중에], 또는 알림 자체를 눌렀을 때.
    func handleNotification(action: String, routineID: UUID?, dateKey: String?) {
        store.refreshToday()
        let day = dateKey.flatMap(Day.init(key:))
        switch action {
        case RoutineNotificationAction.complete:
            // 그 알림이 가리키는 날짜의 그 루틴을 완료로. 이미 완료했으면 아무것도 바뀌지 않는다.
            guard let routineID, let day else { return }
            store.setDone(routineID: routineID, on: day, true)
        case RoutineNotificationAction.later:
            // 알림만 닫는다. 미루기 알림을 새로 만들지 않는다.
            break
        case UNNotificationDefaultActionIdentifier:
            store.open(day.flatMap { $0 <= store.today ? $0 : nil } ?? store.today)
        default:
            break
        }
    }

    /// 위젯을 눌러 들어온 링크(`daylog://today`). 오늘의 화면을 연다.
    func open(_ url: URL) {
        guard url.scheme == "daylog" else { return }
        drainWidgetChecks()
        store.refreshToday()
        store.open(store.today)
    }
}

extension AppRuntime: UNUserNotificationCenterDelegate {
    /// 앱을 보고 있을 때도 알림을 보여 준다.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let routineID = (info[RoutineNotificationAction.routineIDKey] as? String).flatMap(UUID.init(uuidString:))
        let dateKey = info[RoutineNotificationAction.dateKeyKey] as? String
        let action = response.actionIdentifier
        await MainActor.run {
            handleNotification(action: action, routineID: routineID, dateKey: dateKey)
        }
    }
}
