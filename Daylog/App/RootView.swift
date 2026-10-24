import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 화면의 뿌리. 플랫폼과 창 너비에 맞는 탐색 구조를 고른다.
struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var purchaseScenePhase
    @State private var preferences = DevicePreferences.shared
    @State private var templateInbox = TemplateInbox.shared
    /// 새 기기의 첫 동기화 안내. 떠 있는 동안에는 시작 안내와 알림 안내를 올리지 않는다.
    @State private var firstSync = FirstSyncGate.shared
    /// 앱을 연 뒤 첫 화면에서만 스플래시를 튼다(백그라운드에서 돌아올 때나 Mac의 두 번째 창에서는 틀지 않는다).
    @State private var showsSplash = SplashPolicy.claim()
    /// 스플래시가 걷히기 시작했다. 이때부터 시작 안내가 올라올 수 있다.
    @State private var splashIsLeaving = false
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system
    /// 원격 UI 설정(iPhone·iPad 전용). 화면 값은 환경으로 내려보낸다.
    @State private var uiConfig = MobileUIConfigStore.shared
    @Environment(RoutineNotifications.self) private var notifications
    /// 따로 띄우는 알림 안내(시작 안내를 건너뛴 사람, 이 안내가 생기기 전부터 쓰던 사람에게 한 번).
    @State private var showsNotificationGuide = false
    @Environment(\.scenePhase) private var scenePhase
    #endif

    var body: some View {
        navigation
            .task {
                let appStore = store
                PioAppearanceCoordinator.shared.bindGrowthSource { [weak appStore] in appStore?.growth.level ?? 1 }
                if !RuntimeEnvironment.isRunningTests { await PioWardrobeStore.shared.start() }
            }
            .onChange(of: purchaseScenePhase) { _, phase in
                if phase == .active, !RuntimeEnvironment.isRunningTests {
                    Task { await PioWardrobeStore.shared.refreshEntitlements() }
                }
            }
            .environment(preferences)
            .environment(DashboardDecor.shared)
            .environment(CommunityStore.shared)
            .sheet(isPresented: onboardingPresented) {
                OnboardingView().environment(preferences)
            }
            .onChange(of: preferences.mealsEnabled) { _, _ in
                store.section = preferences.safeSelection(store.section)
            }
            .onChange(of: store.section) { _, section in
                let safe = preferences.safeSelection(section)
                if safe != section { store.section = safe }
            }
            .alert("문제가 발생했어요", isPresented: errorIsPresented) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(store.errorMessage ?? "")
            }
            // 날짜 변경·외부 변경·저장 시점은 창이 없어도 돌아야 해서 화면이 아니라 `AppRuntime`이 맡는다.
            // 다른 앱(파일 앱, Finder, 메신저)이 넘겨준 템플릿 파일: 읽어서 미리보기를 띄운다. 추가는 사용자가 확인한 뒤에만 한다.
            #if os(macOS)
            // macOS의 시트는 이미 떠 있는 시트 뒤에 줄을 서므로, 창에 그대로 건다.
            .sheet(item: $templateInbox.incoming) { template in
                TemplateDetailSheet(template: template) {
                    templateInbox.incoming = nil
                    store.leaveSheet(to: .routines)
                }
                .environment(preferences)
                .environment(CommunityStore.shared)
            }
            .alert("템플릿 파일을 열 수 없어요", isPresented: Binding(
                get: { templateInbox.error != nil }, set: { if !$0 { templateInbox.error = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(templateInbox.error ?? "")
            }
            .onOpenURL { url in
                if url.isFileURL { templateInbox.open(url) }
            }
            #endif
            #if os(iOS)
            // 템플릿 파일, 또는 위젯을 눌러 들어온 링크.
            .onOpenURL { url in
                if url.isFileURL { templateInbox.open(url) } else { AppRuntime.shared?.open(url) }
            }
            // iOS에서는 다른 시트가 떠 있으면 뿌리 화면의 시트가 뜨지 못한다. 그래서 맨 위에 떠 있는 화면 위에 직접 올린다.
            .onChange(of: templateInbox.incoming) { _, template in
                guard let template else { return }
                templateInbox.incoming = nil
                TopPresenter.present {
                    TemplateDetailSheet(template: template) {
                        TopPresenter.dismissAll()
                        store.leaveSheet(to: .routines)
                    }
                    .environment(store)
                    .environment(preferences)
                    .environment(DashboardDecor.shared)
                    .environment(CommunityStore.shared)
                    .environment(\.mobileUI, uiConfig.settings)
                    .tint(Theme.accent)
                    .preferredColorScheme(appearance.colorScheme)
                }
            }
            .onChange(of: templateInbox.error) { _, message in
                guard let message else { return }
                templateInbox.error = nil
                TopPresenter.alert(title: "템플릿 파일을 열 수 없어요", message: message)
            }
            // 원격 UI 설정: 화면 값은 환경으로 내려보내고, 앱을 열거나 돌아올 때 받아 둔 설정을 적용한 뒤 새로 확인한다.
            .environment(\.mobileUI, uiConfig.settings)
            .environment(uiConfig)
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active { Task { await uiConfig.activate() } }
            }
            // 알림 안내: 스플래시와 시작 안내가 끝난 뒤에 필요한 사람에게만 한 번 띄운다.
            .sheet(isPresented: $showsNotificationGuide) {
                NotificationGuideSheet()
                    .environment(preferences)
                    .environment(\.mobileUI, uiConfig.settings)
            }
            .task(id: NotificationGuideTrigger(
                splash: isSplashShowing, onboarding: preferences.onboardingCompleted,
                feature: uiConfig.settings.showsOnboardingNotificationGuide, firstSync: firstSync.isActive
            )) {
                await presentNotificationGuideIfNeeded()
            }
            // 기본 카드 배치는 사용자가 배치를 바꾼 적이 없을 때만 따라간다(DevicePreferences가 판단한다).
            .onChange(of: RemoteLayoutDefaults(uiConfig.settings), initial: true) { _, defaults in
                preferences.applyRemoteDefaults(order: defaults.order, hidden: defaults.hidden)
            }
            #endif
    }

    @ViewBuilder
    private var navigation: some View {
        #if DEBUG
        if PioLayeredDiagnosticsView.isEnabled {
            PioLayeredDiagnosticsView()
        } else if PioOutfitDiagnosticsView.isEnabled {
            PioOutfitDiagnosticsView()
        } else {
            applicationNavigation
        }
        #else
        applicationNavigation
        #endif
    }

    @ViewBuilder
    private var applicationNavigation: some View {
        #if os(macOS)
        SidebarNavigation()
            // 안내에 가려진 화면은 누르거나 입력할 수 없게 한다(Tab으로 입력 칸에 들어가 루틴을 만드는 일을 막는다).
            .disabled(firstSync.isActive || isSplashShowing)
            .accessibilityHidden(firstSync.isActive || isSplashShowing)
            .overlay { firstSyncOverlay }
            .animation(.easeOut(duration: 0.3), value: firstSync.isActive)
            // 피오 시범의 스플래시(검증용 앱에서만, 실행할 때 한 번).
            .overlay { PioTrialMacSplashOverlay() }
            .overlay {
                if showsSplash {
                    if RoutimoriSplashTrial.isEnabled {
                        RoutimoriSplashView(onLeaving: { splashIsLeaving = true }) { showsSplash = false }
                    } else if !PioTrial.isEnabled {
                        // 피오 시범은 따로 스플래시를 띄운다(PioTrialMacSplashOverlay).
                        SplashView(onLeaving: { splashIsLeaving = true }) { showsSplash = false }
                    }
                }
            }
            .overlay(alignment: .bottom) { PioTrialStagePreview() }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
                // 창이 처음 앞에 올 때 첫 입력 칸이 전체 선택된 채 포커스를 받으면 실수로 덮어쓰기 쉽다.
                // 창을 닫았다가 메뉴 막대에서 다시 열면 새 창이라, 창마다 한 번씩 푼다. 시트와 메뉴 막대 창은 건드리지 않는다.
                guard let window = notification.object as? NSWindow,
                      window.styleMask.contains(.titled), !window.isSheet,
                      FirstKeyWindows.markSeen(window)
                else { return }
                DispatchQueue.main.async {
                    window.makeFirstResponder(nil)
                }
            }
        #else
        Group {
            // 창이 좁으면(iPhone, iPad의 좁은 Split View·Stage Manager 창) 아래 탭, 넓으면 사이드바.
            if horizontalSizeClass == .compact {
                if store.section == .wardrobe && AppStore.Section.wardrobe.isAvailable {
                    NavigationStack {
                        PioWardrobeView()
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button("오늘로 돌아가기") { store.section = .dashboard }
                                }
                            }
                    }
                } else {
                    TabNavigation()
                }
            } else {
                SidebarNavigation()
            }
        }
        // 안내에 가려진 화면은 누르거나 입력할 수 없게 한다(외장 키보드로 입력 칸에 들어가 루틴을 만드는 일을 막는다).
        .disabled(firstSync.isActive || (RoutimoriSplashTrial.isEnabled && isSplashShowing))
        .accessibilityHidden(firstSync.isActive || (RoutimoriSplashTrial.isEnabled && isSplashShowing))
        // 첫 동기화 안내는 화면 위, 스플래시 아래에 둔다.
        .overlay { firstSyncOverlay }
        .animation(.easeOut(duration: 0.3), value: firstSync.isActive)
        .preferredColorScheme(Self.debugColorScheme ?? appearance.colorScheme)
        .keyboardDoneBar(defersToSheets: true)
        .clearingWindowControls()
        .overlay(alignment: .bottom) { PioTrialStagePreview() }
        // 실제 화면은 밑에서 이미 준비돼 있다. 스플래시는 그 위를 덮었다가 걷힌다.
        .overlay {
            if showsSplash {
                if RoutimoriSplashTrial.isEnabled {
                    RoutimoriSplashView(onLeaving: { splashIsLeaving = true }) { showsSplash = false }
                } else if PioTrial.isEnabled {
                    // 피오 시범(검증용 앱에서만).
                    PioTrialSplash(onLeaving: { splashIsLeaving = true }) { showsSplash = false }
                } else {
                    SplashView(onLeaving: { splashIsLeaving = true }) { showsSplash = false }
                }
            }
        }
        #endif
    }

    @ViewBuilder
    private var firstSyncOverlay: some View {
        if firstSync.isActive {
            FirstSyncView(gate: firstSync)
                .transition(.opacity)
        }
    }

    #if !os(macOS)
    /// 개발 중 화면 검증용: `-DaylogDebugAppearance light|dark`.
    private static var debugColorScheme: ColorScheme? {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "DaylogDebugAppearance") {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
        #else
        return nil
        #endif
    }
    #endif

    /// 스플래시가 떠 있는 동안에는 시작 안내를 올리지 않는다(시트는 스플래시 위에 뜬다). 걷히기 시작할 때 이어서 올라온다.
    /// 첫 동기화 안내가 떠 있는 동안에도 올리지 않는다. 그 안내가 기록을 찾으면 시작 안내는 아예 건너뛴다.
    private var isSplashShowing: Bool {
        #if os(macOS)
        showsSplash && !splashIsLeaving && !PioTrial.isEnabled
        #else
        showsSplash && !splashIsLeaving
        #endif
    }

    private var onboardingPresented: Binding<Bool> {
        Binding(
            get: {
                !preferences.onboardingCompleted && !RuntimeEnvironment.isRunningTests && !isSplashShowing
                    && !firstSync.isActive
            },
            set: { if !$0 { preferences.completeOnboarding() } }
        )
    }

    #if os(iOS)
    /// 알림 안내를 띄울지 정한다. 시작 안내 3단계에서 본 사람, 이미 알림을 정한 사람에게는 띄우지 않는다.
    private func presentNotificationGuideIfNeeded() async {
        guard !isSplashShowing, !firstSync.isActive, !preferences.notificationGuideCompleted else { return }
        await notifications.refreshPermission()
        let decision = NotificationGuidePolicy.decide(
            guideCompleted: preferences.notificationGuideCompleted, onboardingCompleted: preferences.onboardingCompleted,
            permission: notifications.permission, hasExplicitChoice: notifications.hasExplicitChoice,
            featureEnabled: uiConfig.settings.showsOnboardingNotificationGuide
        )
        switch decision {
        case .present:
            // 시작 안내 시트가 내려가는 동안에는 새 시트를 올릴 수 없다. 잠깐 기다린다.
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled, !preferences.notificationGuideCompleted else { return }
            showsNotificationGuide = true
        case .complete:
            preferences.completeNotificationGuide()
        case .wait, .done:
            break
        }
    }
    #endif

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }
}

#if os(iOS)
/// 알림 안내를 다시 판단해야 하는 조건들.
private struct NotificationGuideTrigger: Equatable {
    let splash: Bool
    let onboarding: Bool
    let feature: Bool
    let firstSync: Bool
}

/// 원격 설정의 기본 카드 배치만 떼어 낸 값(이 부분이 바뀔 때만 반영하려고).
private struct RemoteLayoutDefaults: Equatable {
    let order: [String]?
    let hidden: [String]?

    init(_ settings: MobileUISettings) {
        order = settings.defaultCardOrder
        hidden = settings.defaultHiddenCards
    }
}
#endif

/// 메뉴 하나에 해당하는 화면.
struct SectionContent: View {
    @Environment(DevicePreferences.self) private var preferences
    let section: AppStore.Section

    var body: some View {
        Group {
            switch section {
            case .dashboard: DashboardView()
            case .routines: RoutineManagementView()
            case .meals:
                if preferences.mealsEnabled { MealsView() } else { DashboardView() }
            case .statistics: StatisticsView()
            case .calendar: CalendarView()
            case .vacation: VacationView()
            case .templates: TemplateLibraryView()
            case .wardrobe:
                if section.isAvailable { PioWardrobeView() } else { SettingsView() }
            case .settings: SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.windowBackground)
    }
}

/// 사이드바 + 상세 화면. macOS와, 창이 넓은 iPad에서 쓴다.
struct SidebarNavigation: View {
    @Environment(AppStore.self) private var store
    #if os(iOS)
    /// iPad 사이드바 폭. 기본 글자에서는 216pt 그대로, 큰 글자에서는 메뉴 글자를 따라 넓어지되 288pt를 넘지 않는다
    /// (상세 화면 자리를 지키기 위해서다. 넘치는 메뉴 이름은 두 줄로 넘기고, 메뉴 목록은 스크롤된다).
    @ScaledMetric(relativeTo: .body) private var scaledSidebarWidth: CGFloat = 216
    private var sidebarWidth: CGFloat { min(max(scaledSidebarWidth, 216), 288) }
    #endif

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            SectionContent(section: store.section)
        }
        #else
        // iPad에서는 사이드바를 늘 보이게 둔다(세로 방향에서도 숨지 않는다).
        // 창이 좁아지면 이 화면 대신 아래 탭으로 바뀌므로, 접었다 펴는 단추가 필요 없다.
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: sidebarWidth)
                .background(Theme.cardBackground)
            Divider()
            SectionContent(section: store.section)
        }
        #endif
    }
}

#if !os(macOS)
/// 아래 탭. iPhone과, 창이 좁은 iPad에서 쓴다. 캘린더는 탭에 없어서 통계 탭으로 보낸다(그 화면에 캘린더가 있다).
struct TabNavigation: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let current = selection.wrappedValue
        TabView(selection: selection) {
            ForEach(preferences.navigationSections(phone: true)) { section in
                SectionContent(section: section)
                    // 탭 막대에 건 메뉴 색이 화면 안의 단추·스위치까지 물들이지 않게, 내용에는 앱의 강조색을 되돌려 둔다.
                    .tint(Theme.accent)
                    .tabItem {
                        // 사이드바와 같은 메뉴 색. 고른 탭은 채운 아이콘과 진한 색, 나머지는 선 아이콘과 한 단계 옅은 색.
                        Label {
                            Text(section == .meals ? "식사" : section.title)
                        } icon: {
                            Image(uiImage: TabIcon.image(section, isSelected: section == current, isDark: colorScheme == .dark))
                                .renderingMode(.original)
                        }
                    }
                    .tag(section)
            }
        }
        // 고른 탭의 글자색(아이콘은 위에서 직접 칠한다).
        .tint(current.navigationInk)
    }

    private var selection: Binding<AppStore.Section> {
        Binding(
            get: { preferences.safeSelection(Self.tab(for: store.section)) },
            set: { store.section = $0 }
        )
    }
}
#endif

#if !os(macOS)
extension TabNavigation {
    /// 아래 탭에 없는 메뉴는 그 내용이 들어 있는 탭으로 보낸다: 캘린더 → 통계, 휴가 → 오늘(휴가 카드), 템플릿 → 루틴([템플릿] 단추).
    static func tab(for section: AppStore.Section) -> AppStore.Section {
        switch section {
        case .calendar: return .statistics
        case .vacation: return .dashboard
        case .templates: return .routines
        case .wardrobe: return .dashboard
        default: return section
        }
    }
}
#endif

#if !os(macOS)
/// 아래 탭의 아이콘. 시스템 탭 막대는 고른 탭 하나의 색만 정할 수 있어서, 메뉴별 색을 입힌 그림을 직접 넘긴다.
enum TabIcon {
    /// 고르지 않은 탭의 색 농도. 색은 남기되 고른 탭보다 물러나 보이게 한다.
    static let unselectedOpacity = 0.6

    static func symbolName(_ section: AppStore.Section, isSelected: Bool) -> String {
        isSelected ? section.filledSymbol : section.symbol
    }

    static func color(_ section: AppStore.Section, isSelected: Bool, isDark: Bool) -> UIColor {
        let traits = UITraitCollection(userInterfaceStyle: isDark ? .dark : .light)
        // 고른 탭은 글자와 같은 진한 색, 나머지는 메뉴 색을 옅게.
        let base = UIColor(isSelected ? section.navigationInk : section.navigationTint).resolvedColor(with: traits)
        return isSelected ? base : base.withAlphaComponent(unselectedOpacity)
    }

    static func image(_ section: AppStore.Section, isSelected: Bool, isDark: Bool) -> UIImage {
        let symbol = UIImage(systemName: symbolName(section, isSelected: isSelected)) ?? UIImage()
        return symbol.withTintColor(color(section, isSelected: isSelected, isDark: isDark), renderingMode: .alwaysOriginal)
    }
}
#endif

#if os(macOS)
/// 처음 앞에 온 적이 있는 창을 기억한다(창 번호 기준).
@MainActor
enum FirstKeyWindows {
    private static var seen: Set<Int> = []

    /// 이 창을 처음 보면 true.
    static func markSeen(_ window: NSWindow) -> Bool {
        seen.insert(window.windowNumber).inserted
    }
}
#endif
