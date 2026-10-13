import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@main
struct DaylogApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #else
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    private let launch: AppLaunch
    #if os(macOS)
    @AppStorage(MenuBarSettings.key) private var showsMenuBar = true
    #endif

    init() {
        launch = AppLaunch.make()
    }

    var body: some Scene {
        #if os(macOS)
        Window("Daylog", id: "main") {
            content
                .frame(minWidth: 900, minHeight: 650)
        }
        .defaultSize(width: 1200, height: 850)
        .windowResizability(.contentMinSize)
        .commands {
            DaylogCommands(store: launch.store)
        }

        // 메뉴 막대의 빠른 체크. 같은 프로세스의 같은 저장소를 쓴다(따로 띄우는 프로세스가 없다).
        // 앱을 종료하면 함께 사라진다.
        MenuBarExtra(isInserted: menuBarInserted) {
            menuBarContent
        } label: {
            // 잎사귀와 해를 단색으로 그린 전용 템플릿 아이콘(Assets/MenuBarIcon). 메뉴 막대의 밝기에 따라 색이 맞춰진다.
            Image("MenuBarIcon")
                .renderingMode(.template)
                .accessibilityLabel("Daylog 오늘의 루틴")
        }
        .menuBarExtraStyle(.window)
        #else
        WindowGroup {
            content
        }
        .commands {
            DaylogCommands(store: launch.store)
        }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        switch launch {
        case .ready(let container, let store, let sync, let runtime):
            RootView()
                .environment(store)
                .environment(sync)
                .environment(runtime.notifications)
                .modelContainer(container)
        case .failed(let message):
            StoreFailureView(message: message)
        }
    }

    #if os(macOS)
    /// 설정에서 끄거나, 저장소를 열지 못했거나, 단위 테스트의 호스트로 떠 있을 때는 메뉴 막대에 넣지 않는다.
    private var menuBarInserted: Binding<Bool> {
        Binding(
            get: { showsMenuBar && launch.store != nil && !RuntimeEnvironment.isRunningTests },
            set: { showsMenuBar = $0 }
        )
    }

    @ViewBuilder
    private var menuBarContent: some View {
        if case .ready(_, let store, _, _) = launch {
            MenuBarView()
                .environment(store)
        }
    }
    #endif
}

/// 실행 중에도 다른 기기의 변경을 받으려면 앱이 원격 알림을 등록해야 한다.
/// 등록하지 않으면 iCloud의 변경은 앱을 다시 실행할 때에만 들어온다(실측).
/// 알림을 받은 뒤 가져오기 자체는 시스템이 하고, 끝나면 저장소 변경 알림으로 화면이 갱신된다.
#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appearanceObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 앱의 외관이 바뀌면(설정에서 고르거나, 시스템 설정을 따르는 중에 Mac의 외관이 바뀌면) Dock 아이콘도 맞춘다.
        appearanceObservation = NSApplication.shared.observe(\.effectiveAppearance, options: [.initial]) { application, _ in
            MainActor.assumeIsolated { DockIcon.update(for: application) }
        }
        // 창을 닫아 둔 채(메뉴 막대만 남긴 채) 종료하면, 다음 실행 때 창 복원이 "창 없음"을 복원해 창이 안 뜬다.
        // 복원이 끝난 뒤에도 창이 없으면 Dock에서 앱을 누른 것처럼 다시 열어 달라고 스스로에게 요청한다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard !RuntimeEnvironment.isRunningTests, !Self.hasMainWindow else { return }
            Self.requestReopen()
        }
        guard RuntimeEnvironment.cloudKitContainerID != nil else { return }
        NSApplication.shared.registerForRemoteNotifications()
    }

    /// 제목 표시줄이 있는 보이는 창(메뉴 막대·팝오버의 창은 제외).
    static var hasMainWindow: Bool {
        NSApplication.shared.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) }
    }

    /// Dock 아이콘을 눌렀을 때와 같은 "다시 열기" 이벤트. SwiftUI가 받아 주 창을 연다.
    static func requestReopen() {
        let target = NSAppleEventDescriptor(processIdentifier: ProcessInfo.processInfo.processIdentifier)
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEReopenApplication),
            targetDescriptor: target, returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)
        )
        _ = try? event.sendEvent(options: [.noReply], timeout: 1)
    }

    /// Finder나 다른 앱에서 템플릿 파일을 Daylog로 열었을 때. 미리보기만 띄우고, 추가는 사용자가 확인한 뒤에 한다.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first(where: \.isFileURL) else { return }
        Task { @MainActor in TemplateInbox.shared.open(url) }
    }

    /// 메뉴 막대를 쓰는 동안에는 창을 닫아도 앱이 남는다(메뉴 막대에서 계속 체크할 수 있게).
    /// 메뉴 막대를 껐으면 예전처럼 창을 닫을 때 끝난다.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !MenuBarSettings.isShown
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // 등록에 실패해도 기록과 동기화는 계속된다. 다른 기기의 변경이 다음 실행 때 들어올 뿐이다.
        NSLog("Daylog: 원격 알림 등록 실패 - %@", error.localizedDescription)
    }
}
#else
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if RuntimeEnvironment.cloudKitContainerID != nil {
            application.registerForRemoteNotifications()
        }
        return true
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("Daylog: 원격 알림 등록 실패 - %@", error.localizedDescription)
    }
}
#endif

/// 저장소를 열 수 없을 때 빈 저장소로 조용히 대체하지 않는다. 그러면 기록이 사라진 것처럼 보인다.
@MainActor
enum AppLaunch {
    case ready(ModelContainer, AppStore, CloudSyncMonitor, AppRuntime)
    case failed(String)

    var store: AppStore? {
        if case .ready(_, let store, _, _) = self { return store }
        return nil
    }

    static func make() -> AppLaunch {
        #if os(macOS)
        // 설정에서 고른 외관을 창이 뜨기 전에 적용한다. (iOS·iPadOS는 화면 뿌리에서 색 구성으로 건다.)
        AppearanceMode.stored().apply()
        #if DEBUG
        // 개발 중 화면 검증용: `-DaylogDebugAppearance light|dark`로 설정과 다른 모드를 본다.
        if let name = UserDefaults.standard.string(forKey: "DaylogDebugAppearance") {
            NSApplication.shared.appearance = NSAppearance(named: name == "light" ? .aqua : .darkAqua)
        }
        #endif
        #endif
        #if DEBUG
        DebugScript.purgeAndExitIfRequested()
        DebugBackup.createIfRequested()
        #endif
        do {
            let cloudContainerID = RuntimeEnvironment.cloudKitContainerID
            let container = try DaylogStore.makeContainer(
                RuntimeEnvironment.storeLocation, cloudKitContainerID: cloudContainerID,
                cloudKitEnvironment: RuntimeEnvironment.cloudKitEnvironment,
                // `--args -DaylogReuploadAll YES`로 한 번 실행하면, 이 Mac의 기존 기록을 지금 환경의 iCloud에 다시 올린다
                // (다른 환경과 동기화하던 저장소를 옮길 때). 백업을 만들고, 같은 환경에는 한 번만 한다.
                reuploadAll: UserDefaults.standard.bool(forKey: "DaylogReuploadAll")
            )
            let store = AppStore(
                container: container,
                deviceID: DaylogStore.deviceID(for: RuntimeEnvironment.storeLocation),
                clock: RuntimeEnvironment.clock
            )
            store.tracksDevice = !RuntimeEnvironment.isRunningTests
            store.start()
            let sync = CloudSyncMonitor(containerIdentifier: cloudContainerID, environment: RuntimeEnvironment.cloudKitEnvironment)
            sync.start()
            // 단위 테스트의 호스트로 떠 있을 때는 실제 알림 센터를 건드리지 않는다.
            let isTesting = RuntimeEnvironment.isRunningTests
            let runtime = AppRuntime(
                store: store,
                notifications: RoutineNotifications(client: isTesting ? DisabledNotificationClient() : SystemNotificationClient())
            )
            runtime.start(installDelegate: !isTesting)
            #if DEBUG
            DebugScript.runIfRequested(store: store, sync: sync, container: container)
            #endif
            return .ready(container, store, sync, runtime)
        } catch {
            #if DEBUG
            print("DAYLOG_SCRIPT LAUNCH_FAILED \(error.localizedDescription)")
            fflush(stdout)
            #endif
            return .failed(error.localizedDescription)
        }
    }
}

enum RuntimeEnvironment {
    static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return ["XCTestConfigurationFilePath", "XCTestBundlePath", "XCTestSessionIdentifier"]
            .contains { environment[$0] != nil }
    }

    /// 단위 테스트의 호스트로 실행될 때는 실제 저장소를 열지 않는다.
    static var storeLocation: DaylogStore.Location {
        if isRunningTests { return .inMemory }
        #if DEBUG
        // 개발 중 검증용: `-DaylogStoreName <이름>`으로 실행하면 별도 저장소 파일을 쓴다.
        if let name = UserDefaults.standard.string(forKey: "DaylogStoreName"),
           !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) {
            return .onDisk(name: name)
        }
        #endif
        return .onDisk(name: "Daylog")
    }
}

extension RuntimeEnvironment {
    /// 동기화할 iCloud 컨테이너. nil이면 로컬 전용.
    static var cloudKitContainerID: String? {
        if isRunningTests { return nil }
        #if DEBUG
        // 검증용 저장소(-DaylogStoreName)는 항상 로컬 전용이다. 실제 기록과 같은 iCloud 영역을 쓰면
        // 검증 데이터가 실제 기록에 섞이기 때문에, 붙일 방법 자체를 두지 않는다.
        if UserDefaults.standard.string(forKey: "DaylogStoreName") != nil {
            return nil
        }
        #endif
        return CloudSyncConfiguration.containerIdentifier
    }

    /// 이 빌드의 CloudKit 환경. 로컬 전용이면 nil.
    static var cloudKitEnvironment: String? {
        cloudKitContainerID == nil ? nil : CloudSyncConfiguration.environment
    }

    /// "오늘"을 알려 주는 시계.
    static var clock: () -> Day {
        #if DEBUG
        // 개발 중 날짜 변경 검증용: `defaults write com.mungyubin.daylog DaylogDebugToday 2026-10-11`처럼
        // 값을 바꾼 뒤 앱을 다시 활성화하면 자정이 지난 것처럼 동작한다. 릴리스 빌드에는 포함되지 않는다.
        return {
            UserDefaults.standard.string(forKey: "DaylogDebugToday").flatMap(Day.init(key:)) ?? Day.today()
        }
        #else
        return { Day.today() }
        #endif
    }
}

struct StoreFailureView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("기록 저장소를 열 수 없어요")
                .font(.title2.bold())
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
            Text("기존 기록은 지워지지 않았습니다. 앱을 다시 실행해 보세요.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if os(macOS)
/// 메뉴 막대 아이콘 표시 여부. 이 Mac에만 저장한다.
enum MenuBarSettings {
    static let key = "showsMenuBarExtra"

    /// 기본은 켜짐.
    static var isShown: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}
#endif
