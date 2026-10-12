import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 화면의 뿌리. 플랫폼과 창 너비에 맞는 탐색 구조를 고른다.
struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var preferences = DevicePreferences.shared
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system
    /// 앱을 연 뒤 첫 화면에서만 스플래시를 튼다(백그라운드에서 돌아올 때는 틀지 않는다).
    @State private var showsSplash = SplashPolicy.claim()
    /// 스플래시가 걷히기 시작했다. 이때부터 시작 안내가 올라올 수 있다.
    @State private var splashIsLeaving = false
    #endif

    var body: some View {
        navigation
            .environment(preferences)
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
            #if os(iOS)
            // 위젯을 눌러 들어온 링크.
            .onOpenURL { url in
                AppRuntime.shared?.open(url)
            }
            #endif
    }

    @ViewBuilder
    private var navigation: some View {
        #if os(macOS)
        SidebarNavigation()
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
                TabNavigation()
            } else {
                SidebarNavigation()
            }
        }
        .preferredColorScheme(Self.debugColorScheme ?? appearance.colorScheme)
        .keyboardDoneBar()
        .clearingWindowControls()
        // 실제 화면은 밑에서 이미 준비돼 있다. 스플래시는 그 위를 덮었다가 걷힌다.
        .overlay {
            if showsSplash {
                SplashView(onLeaving: { splashIsLeaving = true }) { showsSplash = false }
            }
        }
        #endif
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
    private var isSplashShowing: Bool {
        #if os(macOS)
        false
        #else
        showsSplash && !splashIsLeaving
        #endif
    }

    private var onboardingPresented: Binding<Bool> {
        Binding(
            get: { !preferences.onboardingCompleted && !RuntimeEnvironment.isRunningTests && !isSplashShowing },
            set: { if !$0 { preferences.completeOnboarding() } }
        )
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }
}

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
                .frame(width: 216)
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
                    .tint(Color("AccentColor"))
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
    /// 아래 탭에 없는 메뉴는 그 내용이 들어 있는 탭으로 보낸다: 캘린더 → 통계, 휴가 → 오늘(휴가 카드).
    static func tab(for section: AppStore.Section) -> AppStore.Section {
        switch section {
        case .calendar: return .statistics
        case .vacation: return .dashboard
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
