import SwiftUI

/// 설정의 갈래. 왼쪽 목록(넓은 창)이나 첫 화면(iPhone)에 보이고, 고르면 그 갈래의 설정이 나온다.
enum SettingsCategory: String, CaseIterable, Identifiable {
    case sync, general, today, routine, calendar, notifications, vacation, data, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sync: return "iCloud"
        case .general: return "일반"
        case .today: return "오늘 화면"
        case .routine: return "루틴"
        case .calendar: return "캘린더"
        case .notifications: return "알림"
        case .vacation: return "휴가"
        case .data: return "데이터"
        case .about: return "정보"
        }
    }

    var subtitle: String {
        switch self {
        case .sync: return "계정 상태, 동기화"
        case .general:
            #if os(macOS)
            return "앱 테마, 메뉴 막대"
            #else
            return "앱 테마, 위젯"
            #endif
        case .today: return "식사 표시, 카드 구성"
        case .routine: return "달성한 날 기준값"
        case .calendar: return "한 주의 시작 요일"
        case .notifications: return "루틴 알림"
        case .vacation: return "휴가 기간 관리"
        case .data: return "가져오기, 내보내기"
        case .about: return "버전, 시작 안내"
        }
    }

    var symbol: String {
        switch self {
        case .sync: return "icloud.fill"
        case .general: return "gearshape.fill"
        case .today: return "square.grid.2x2.fill"
        case .routine: return "checklist"
        case .calendar: return "calendar"
        case .notifications: return "bell.fill"
        case .vacation: return "beach.umbrella.fill"
        case .data: return "externaldrive.fill"
        case .about: return "info.circle.fill"
        }
    }

    var color: GroupColor {
        switch self {
        case .sync: return .blue
        case .general: return .purple
        case .today: return .mint
        case .routine: return .blue
        case .calendar: return .orange
        case .notifications: return .coral
        case .vacation: return .coral
        case .data: return .green
        case .about: return .yellow
        }
    }
}

/// 설정. 넓은 창(macOS, iPad)은 왼쪽에 갈래 목록, 오른쪽에 고른 갈래의 설정. 좁은 화면(iPhone)은 목록에서 들어간다.
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(CloudSyncMonitor.self) private var sync
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selected: SettingsCategory = .sync
    /// 좁은 화면에서 들어가 있는 갈래. nil이면 갈래 목록.
    @State private var compactSelection: SettingsCategory?

    var body: some View {
        if horizontalSizeClass == .compact {
            compactSettings
        } else {
            wideSettings
        }
    }

    // MARK: - 넓은 창

    private var wideSettings: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            PageTitle(title: "설정", subtitle: "Daylog를 내 방식에 맞게 바꿔요.")
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, Theme.pagePadding)
            HStack(alignment: .top, spacing: 24) {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(SettingsCategory.allCases) { category in
                            Button {
                                selected = category
                            } label: {
                                SettingsCategoryRow(category: category, isSelected: selected == category)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected == category ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                    .padding(8)
                    .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(width: 280)
                .padding(.leading, Theme.pagePadding)
                .padding(.bottom, Theme.pagePadding)

                // 고른 갈래의 이름을 크게 적고, 그 아래에 설정을 넉넉한 줄 높이로 둔다.
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Image(systemName: selected.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.onAccent)
                            .frame(width: 40, height: 40)
                            .background(selected.color.color, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.title)
                                .font(.title3.weight(.semibold))
                                .accessibilityAddTraits(.isHeader)
                            Text(selected.subtitle)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    detail(selected)
                        .environment(\.defaultMinListRowHeight, 46)
                }
                .frame(maxWidth: 620, alignment: .topLeading)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - 좁은 화면

    /// iPhone과 좁은 창: 갈래 목록에서 하나를 고르면 그 갈래의 설정으로 들어가고, 위의 [설정]으로 돌아온다.
    /// 탭 안에 NavigationStack을 두면 탭 전체가 빈 화면이 되어(iOS 26 시뮬레이터에서 확인), 직접 오가게 했다.
    @ViewBuilder
    private var compactSettings: some View {
        if let category = compactSelection {
            detail(category)
                .safeAreaInset(edge: .top, spacing: 0) {
                    ZStack {
                        Text(category.title)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        HStack {
                            Button {
                                compactSelection = nil
                            } label: {
                                Label("설정", systemImage: "chevron.left")
                                    .font(.body.weight(.medium))
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("설정 목록으로 돌아가기")
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(Theme.windowBackground)
                }
        } else {
            Form {
                Section {
                    ForEach(SettingsCategory.allCases) { category in
                        Button {
                            compactSelection = category
                        } label: {
                            HStack(spacing: 8) {
                                SettingsCategoryRow(category: category, isSelected: false, showsChevron: false)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .formStyle(.grouped)
            .safeAreaInset(edge: .top, spacing: 0) {
                Text("설정")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .background(Theme.windowBackground)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    // MARK: - 갈래별 설정

    private func detail(_ category: SettingsCategory) -> some View {
        Form {
            switch category {
            case .sync:
                syncSection
            case .general:
                AppearanceSection()
                #if os(macOS)
                MenuBarSettingsSection()
                #else
                WidgetGuideSection()
                #endif
            case .today:
                DevicePreferenceSections()
            case .routine:
                Section {
                    ThresholdControl()
                } header: {
                    Text("달성한 날 기준값")
                } footer: {
                    Text("하루 달성률이 이 값 이상이면 달성한 날로 세요.")
                }
            case .calendar:
                CalendarSettingsSection()
            case .notifications:
                NotificationSettingsSection()
            case .vacation:
                VacationSettingsSection()
            case .data:
                DataTransferSettingsSection()
            case .about:
                aboutSection
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .scrollContentBackground(.hidden)
        #endif
    }

    private var aboutSection: some View {
        Section {
            HStack(spacing: 12) {
                BrandIcon(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daylog")
                        .font(.headline)
                    Text("버전 \(Self.version)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
            OnboardingReplayButton()
        } header: {
            Text("앱 정보")
        } footer: {
            Text("별도 계정이나 자체 서버를 쓰지 않고, 사용 정보도 수집하지 않아요.")
        }
    }

    /// iCloud 계정과 동기화 상태. 시스템이 알려 주는 것만 보여 준다(계정 이름·사진은 앱이 알 수 없다).
    private var syncSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(GroupColor.blue.color)
                    .frame(width: 44, height: 44)
                    .background(GroupColor.blue.wash, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud")
                        .font(.headline)
                    Text(sync.account == .available ? "Apple 계정으로 연결되어 있어요" : sync.account.title)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)

            // 30초마다 "n분 전"을 다시 계산한다.
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                let summary = SyncSummary.make(
                    isEnabled: sync.isEnabled, account: sync.account, lastImportAt: sync.lastImportAt,
                    lastExportAt: sync.lastExportAt, errorMessage: sync.lastErrorMessage, now: timeline.date
                )
                LabeledContent("동기화 상태") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Self.color(for: summary.tone))
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(summary.title)
                            .fontWeight(.semibold)
                        Text("· \(summary.detail)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if sync.isEnabled {
                if let environment = sync.environmentTitle {
                    LabeledContent("iCloud 환경", value: environment)
                }
                if let lastImportAt = sync.lastImportAt {
                    LabeledContent("마지막으로 가져온 시각", value: Self.timestamp(lastImportAt))
                }
                if let lastExportAt = sync.lastExportAt {
                    LabeledContent("마지막으로 보낸 시각", value: Self.timestamp(lastExportAt))
                }
                if let error = sync.lastErrorMessage {
                    Label("최근 동기화 오류: \(error)", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                ForEach(store.syncNotices, id: \.self) { notice in
                    Label(notice, systemImage: "arrow.triangle.merge")
                }
                Button("상태 새로고침") {
                    sync.refreshAccountStatus()
                }
            }
        } footer: {
            Text(sync.isEnabled
                 ? "같은 Apple 계정의 Mac·iPhone·iPad가 기록을 맞춰요. 인터넷이 없어도 쓸 수 있고, 연결되면 이어서 맞춰요. 계정은 기기의 시스템 설정에서 관리해요."
                 : "기록은 \(Platform.thisDevice)에만 저장돼요.")
        }
    }

    private static func color(for tone: SyncSummary.Tone) -> Color {
        switch tone {
        case .good: return GroupColor.green.color
        case .waiting: return GroupColor.yellow.color
        case .warning: return GroupColor.orange.color
        case .off: return Color.secondary
        }
    }

    private static func timestamp(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().hour().minute().second().locale(Locale(identifier: "ko_KR")))
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }
}

/// 외관(시스템 설정/라이트/다크). 고르는 즉시 앱 전체에 적용되고, 이 Mac에만 저장된다.
private struct AppearanceSection: View {
    @AppStorage(AppearanceMode.storageKey) private var mode: AppearanceMode = .system

    var body: some View {
        Section {
            Picker("테마", selection: $mode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            #if os(macOS)
            .pickerStyle(.radioGroup)
            .onChange(of: mode) { _, newValue in
                newValue.apply()
            }
            #else
            // iOS·iPadOS는 화면 뿌리가 같은 설정값을 읽어 바로 바꾼다.
            .pickerStyle(.segmented)
            #endif
        } header: {
            Text("외관")
        } footer: {
            Text("라이트·다크를 고르면 Daylog만 그 모드로 보여요. \(Platform.thisDevice)에만 적용돼요.")
        }
    }
}

/// 달력의 한 주 시작 요일. 이 기기에만 저장하고, 고르는 즉시 모든 달력에 적용된다.
private struct CalendarSettingsSection: View {
    @Environment(DevicePreferences.self) private var preferences

    var body: some View {
        Section {
            Picker("한 주의 시작", selection: Binding(
                get: { preferences.weekStart },
                set: { preferences.setWeekStart($0) }
            )) {
                ForEach(WeekStart.allCases) { start in
                    Text(start.title).tag(start)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("캘린더")
        } footer: {
            Text("달력과 히트맵의 요일 순서만 바뀌어요. 통계 집계 기간은 그대로예요.")
        }
    }
}

/// 달성 기준값(50~100%). 설정과 루틴 관리 화면이 같이 쓴다.
struct ThresholdControl: View {
    @Environment(AppStore.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var range: ClosedRange<Int> { SettingsService.thresholdRange }

    var body: some View {
        // 좁은 화면(iPhone, 좁은 iPad 창)에서는 슬라이더가 눌리지 않게 값과 단추를 아래 줄로 내린다.
        if horizontalSizeClass == .compact {
            VStack(alignment: .leading, spacing: 10) {
                slider
                stepper
            }
        } else {
            HStack(spacing: 12) {
                slider
                stepper
            }
        }
    }

    private var slider: some View {
        Slider(
            value: Binding(
                get: { Double(store.threshold) },
                set: { store.setThreshold(Int($0.rounded())) }
            ),
            in: Double(range.lowerBound)...Double(range.upperBound),
            step: 5
        ) {
            Text("기준값")
        } minimumValueLabel: {
            Text("\(range.lowerBound)%").font(.caption).foregroundStyle(.secondary)
        } maximumValueLabel: {
            Text("\(range.upperBound)%").font(.caption).foregroundStyle(.secondary)
        }
        .labelsHidden()
        .accessibilityLabel("달성한 날 기준값")
        .accessibilityValue("\(store.threshold)%")
    }

    /// 값과 올림·내림 단추. 폼 안의 스테퍼는 레이블을 달면 줄 전체로 늘어나므로, 값은 따로 그리고 스테퍼는 단추만 둔다.
    private var stepper: some View {
        HStack(spacing: 8) {
            Text("\(store.threshold)%")
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
                .accessibilityHidden(true)
            Stepper(
                "달성한 날 기준값",
                value: Binding(
                    get: { store.threshold },
                    set: { store.setThreshold($0) }
                ),
                in: range
            )
            .labelsHidden()
            .accessibilityValue("\(store.threshold)%")
        }
        .fixedSize()
    }
}

/// 설정 갈래 한 줄: 색 있는 아이콘, 이름, 한 줄 요약.
struct SettingsCategoryRow: View {
    let category: SettingsCategory
    let isSelected: Bool
    var showsChevron = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 32, height: 32)
                .background(category.color.color, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(.body.weight(.semibold))
                Text(category.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, showsChevron ? 12 : 0)
        .padding(.vertical, showsChevron ? 10 : 4)
        .background(isSelected ? category.color.color.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
