import Foundation
import Observation
import SwiftData

/// 화면 상태와 모든 사용자 동작의 진입점. 뷰는 서비스나 `ModelContext`를 직접 다루지 않는다.
@MainActor
@Observable
final class AppStore {
    var section: Section = .dashboard
    var errorMessage: String?
    // 통계 화면의 탭·필터·검색어. 다른 메뉴에 다녀와도 그대로 남는다.
    var mealPeriod: MealPeriod = .month
    var mealQuery = ""
    var statsPeriod: StatsPeriod = .month

    /// 실제 오늘. 통계의 기준 날짜다.
    private(set) var today: Day
    /// 대시보드에서 보고 있는 날짜.
    private(set) var selectedDay: Day
    private(set) var record: DayRecord?
    /// 화면이 읽는 체크 목록(그룹별). 모델 객체가 아니라 값의 사본이다.
    /// SwiftData는 저장·조회 뒤에 같은 체크를 다른 객체로 다시 만들 수 있어서, 화면이 모델 객체를 직접 관찰하면
    /// 값을 바꿔도 알림이 가지 않는다. 그래서 값이 바뀔 수 있는 모든 지점에서 `refreshChecks()`로 다시 만든다.
    private(set) var checkSections: [CheckSection] = []
    /// 실제 오늘의 체크 목록. 보고 있는 날짜와 상관없이 메뉴 막대·위젯·알림이 이 값을 쓴다.
    private(set) var todaySections: [CheckSection] = []
    /// 보관된 루틴을 포함한 전체 루틴. 표시 순서대로.
    private(set) var routines: [RoutineItem] = []
    /// 보관된 그룹을 포함한 전체 그룹. 표시 순서대로.
    private(set) var groups: [RoutineGroup] = []
    /// 저장된 내용이 바뀔 때마다 올라간다. 식사 기록 탭처럼 따로 조회하는 화면이 이 값을 보고 다시 읽는다.
    private(set) var dataVersion = 0
    private(set) var vacationPeriods: [VacationPeriod] = []
    /// 같은 iCloud 계정으로 Daylog를 쓰는 기기들(이 기기 포함).
    var devices: [DeviceInfo] = []
    /// 이 기기의 정보를 기기 목록에 적을지. 실제 앱이 시작할 때 켠다.
    var tracksDevice = false
    /// 마지막으로 항목을 추가한 그룹. ⌘N과 추천 칩이 이 그룹을 대상으로 한다.
    var lastUsedGroupID: UUID?
    private(set) var stats: DashboardStats
    /// 캘린더가 보여 주는 달의 1일.
    private(set) var calendarMonth: Day
    private(set) var monthOutcomes: [Day: DayOutcome] = [:]
    /// 값이 바뀌면 빠른 추가 입력창이 포커스를 가져간다.
    private(set) var quickAddFocusToken = 0
    /// 설정의 [대시보드 구성 편집]이 켠다. 대시보드가 나타날 때 편집 모드로 들어가고 끈다.
    var wantsDashboardEditing = false
    /// 동기화 중 서로 다른 내용을 함께 보존한 내역. 최근 것이 앞.
    private(set) var syncNotices: [String] = []
    private static let keptSyncNotices = 5

    /// 컨테이너가 해제되면 컨텍스트의 모델 객체가 모두 무효화되므로 직접 붙잡아 둔다.
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored let context: ModelContext
    @ObservationIgnored private let clock: () -> Day
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private var editingSources: Set<String> = []
    /// 이 기기의 식별자. 같은 칸을 두 기기가 동시에 고쳤는지 가려내는 편집 기록에 쓴다.
    @ObservationIgnored let deviceID: String
    /// 고친 뒤 아직 편집 기록으로 남기지 않은 칸.
    @ObservationIgnored private var unrecordedEdits: [String: Set<DayTextField>] = [:]
    /// 저장된 내용이 바뀌어 화면 값을 다시 계산한 뒤에 불린다. 알림 예약과 위젯이 여기에 맞춰 따라온다.
    @ObservationIgnored var onReload: (() -> Void)?

    init(
        container: ModelContainer,
        deviceID: String = UUID().uuidString,
        clock: @escaping () -> Day = { Day.today() }
    ) {
        self.container = container
        self.deviceID = deviceID
        self.context = container.mainContext
        self.clock = clock
        let today = clock()
        self.today = today
        self.selectedDay = today
        self.calendarMonth = today.firstOfMonth
        self.stats = .empty(today: today)
    }

    // MARK: - 시작과 날짜 갱신

    func start() {
        reconcile()
        perform {
            record = try DayRecordService(context: context).fetchOrCreate(day: today, today: today)
        }
        reload()
        touchDevice()
    }

    /// 다른 기기의 변경이 저장소에 들어왔을 때(그리고 앱이 다시 활성화될 때) 호출한다.
    /// 중복을 합치고, 보고 있는 날짜의 대표 기록을 다시 고른 뒤 화면의 값을 새로 계산한다.
    func handleExternalChanges() {
        reconcile()
        perform {
            // 더 먼저 만들어진 기록이 다른 기기에서 들어오면 대표가 바뀐다. 입력하던 내용은 병합으로 대표에 옮겨져 있다.
            if let representative = try DayRecordService(context: context).record(on: selectedDay),
               representative !== record {
                record = representative
            }
        }
        reload()
        // 다른 기기의 정보가 들어왔을 수 있고, 이 기기의 마지막 활동도 가끔 다시 적는다.
        touchDevice()
    }

    private func reconcile() {
        perform {
            try recordPendingEdits()
            let report = try SyncReconciler(context: context, deviceID: deviceID).reconcile(today: today)
            if !report.notices.isEmpty {
                syncNotices = Array((report.notices + syncNotices).prefix(Self.keptSyncNotices))
            }
        }
    }

    /// 자정, 앱 활성화, 잠자기 해제, 시간대 변경 때 호출한다.
    func refreshToday() {
        let newToday = clock()
        guard newToday != today else { return }
        flush()

        let wasViewingToday = isViewingToday
        today = newToday

        // 텍스트를 입력하던 중이면 그 칸이 비워지지 않도록 보던 날짜에 머문다.
        let shouldFollow = wasViewingToday && editingSources.isEmpty
        if shouldFollow || selectedDay > newToday {
            show(newToday)
        }
        reload()
    }

    // MARK: - 날짜 이동

    func select(_ day: Day) {
        guard day <= today, day != selectedDay else { return }
        flush()
        show(day)
    }

    /// 다른 화면에서 날짜를 골라 대시보드로 이동한다.
    func open(_ day: Day) {
        select(day)
        section = .dashboard
    }

    func goToPreviousDay() { select(selectedDay.adding(days: -1)) }
    func goToNextDay() { select(selectedDay.adding(days: 1)) }
    func goToToday() { select(today) }

    func showPreviousMonth() {
        calendarMonth = calendarMonth.addingMonths(-1)
        reloadMonth()
    }

    func showNextMonth(allowFuture: Bool = false) {
        guard allowFuture || canShowNextMonth else { return }
        calendarMonth = calendarMonth.addingMonths(1)
        reloadMonth()
    }

    private func show(_ day: Day) {
        perform {
            record = try DayRecordService(context: context).fetchOrCreate(day: day, today: today)
            selectedDay = day
            if calendarMonth != day.firstOfMonth {
                calendarMonth = day.firstOfMonth
                reloadMonth()
            }
        }
        refreshChecks()
    }

    // MARK: - 하루 기록

    /// 입력은 모델에 즉시 반영하고, 디스크 저장은 잠깐 모아서 한다.
    func setText(_ value: String, at keyPath: ReferenceWritableKeyPath<DayRecord, String>) {
        // 입력 칸은 포커스를 잃을 때 같은 값을 다시 써 보내기도 한다. 그건 편집이 아니다.
        guard let record, record[keyPath: keyPath] != value else { return }
        DayRecordService(context: context).setText(value, at: keyPath, of: record)
        if let field = DayTextField(keyPath: keyPath) {
            unrecordedEdits[record.dateKey, default: []].insert(field)
        }
        scheduleSave()
    }

    /// 저장 직전에, 고친 칸마다 "이 기기가 이 값을 썼다"는 편집 기록을 남긴다(글자마다가 아니라 저장마다 한 번).
    func recordPendingEdits() throws {
        guard !unrecordedEdits.isEmpty else { return }
        let service = FieldEditService(context: context, deviceID: deviceID)
        let records = DayRecordService(context: context)
        for (dateKey, fields) in unrecordedEdits {
            guard let day = Day(key: dateKey), let record = try records.record(on: day) else { continue }
            for field in fields {
                try service.recordEdit(dateKey: dateKey, field: field, value: record[keyPath: field.keyPath])
            }
        }
        unrecordedEdits.removeAll()
    }

    /// 텍스트 입력 중 여부. 포커스가 칸 사이를 옮겨 다녀도 끊기지 않도록 출처별로 센다.
    func setEditing(_ isEditing: Bool, source: String) {
        if isEditing {
            editingSources.insert(source)
        } else {
            editingSources.remove(source)
            flush()
        }
    }

    /// 대기 중인 변경을 지금 저장한다. 포커스 종료, 날짜 이동, 앱 종료 직전에 호출한다.
    func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        guard context.hasChanges else { return }
        perform {
            try recordPendingEdits()
            try context.save()
        }
        reloadStats()
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    // MARK: - 루틴

    /// ⌘N. 루틴 관리 화면에서는 그 화면의 입력칸으로, 다른 화면에서는 오늘의 대시보드로 간다.
    func requestQuickAddFocus() {
        if section != .routines {
            section = .dashboard
            goToToday()
        }
        quickAddFocusToken += 1
    }

    /// 루틴 변경의 공통 경로: 대기 중인 입력을 저장하고, 변경하고, 화면의 값을 다시 계산한다.
    @discardableResult
    func mutateRoutines(_ body: (RoutineService) throws -> Void) -> Bool {
        flush()
        let succeeded = perform { try body(RoutineService(context: context)) }
        reload()
        return succeeded
    }

    // MARK: - 다시 계산

    private func reload() {
        perform {
            let service = RoutineService(context: context)
            groups = try service.groups()
            routines = try service.routines()
        }
        reloadStats()
    }

    /// 보고 있는 날짜의 체크 목록을 저장된 값으로 다시 만든다.
    func refreshChecks() {
        let updated = makeCheckSections()
        if updated != checkSections { checkSections = updated }
    }

    func reloadStats() {
        dataVersion += 1
        // 체크 목록이 휴가 정책을 따르므로 휴가부터 읽는다.
        perform {
            let periods = try VacationService(context: context, deviceID: deviceID).periods()
            if periods != vacationPeriods { vacationPeriods = periods }
        }
        refreshChecks()
        let updatedToday = isViewingToday ? checkSections : makeTodaySections()
        if updatedToday != todaySections { todaySections = updatedToday }
        perform {
            let updated = try StatsService(context: context).dashboard(today: today)
            if updated != stats { stats = updated }
        }
        // 30일보다 오래된 날짜를 고쳐도 캘린더에는 보이므로 항상 함께 맞춘다.
        reloadMonth()
        onReload?()
    }

    private func reloadMonth() {
        perform {
            let first = calendarMonth
            let last = first.adding(days: first.daysInMonth - 1)
            let outcomes = try StatsService(context: context).outcomes(from: first, to: last, today: today)
            let updated = Dictionary(uniqueKeysWithValues: outcomes.map { ($0.day, $0) })
            if updated != monthOutcomes { monthOutcomes = updated }
        }
    }

    /// 저장·조회 실패를 삼키지 않고 사용자에게 알린다.
    @discardableResult
    func perform(_ body: () throws -> Void) -> Bool {
        do {
            try body()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
