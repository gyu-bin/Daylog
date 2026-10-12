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

    private var onboardingPresented: Binding<Bool> {
        Binding(
            get: { !preferences.onboardingCompleted && !RuntimeEnvironment.isRunningTests },
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

    var body: some View {
        TabView(selection: selection) {
            ForEach(preferences.navigationSections(phone: true)) { section in
                SectionContent(section: section)
                    .tabItem {
                        Label(section == .meals ? "식사" : section.title, systemImage: section.symbol)
                    }
                    .tag(section)
            }
        }
    }

    private var selection: Binding<AppStore.Section> {
        Binding(
            get: { preferences.safeSelection(store.section == .calendar ? .statistics : store.section) },
            set: { store.section = $0 }
        )
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
