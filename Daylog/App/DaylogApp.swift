import AppKit
import SwiftData
import SwiftUI

@main
struct DaylogApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let launch: AppLaunch

    init() {
        launch = AppLaunch.make()
    }

    var body: some Scene {
        Window("Daylog", id: "main") {
            Group {
                switch launch {
                case .ready(let container, let store, let sync):
                    RootView()
                        .environment(store)
                        .environment(sync)
                        .modelContainer(container)
                case .failed(let message):
                    StoreFailureView(message: message)
                }
            }
            .frame(minWidth: 900, minHeight: 650)
        }
        .defaultSize(width: 1200, height: 850)
        .windowResizability(.contentMinSize)
        .commands {
            DaylogCommands(store: launch.store)
        }
    }
}

/// 실행 중에도 다른 기기의 변경을 받으려면 앱이 원격 알림을 등록해야 한다.
/// 등록하지 않으면 iCloud의 변경은 앱을 다시 실행할 때에만 들어온다(실측).
/// 알림을 받은 뒤 가져오기 자체는 시스템이 하고, 끝나면 저장소 변경 알림으로 화면이 갱신된다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appearanceObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 앱의 외관이 바뀌면(설정에서 고르거나, 시스템 설정을 따르는 중에 Mac의 외관이 바뀌면) Dock 아이콘도 맞춘다.
        appearanceObservation = NSApplication.shared.observe(\.effectiveAppearance, options: [.initial]) { application, _ in
            MainActor.assumeIsolated { DockIcon.update(for: application) }
        }
        guard RuntimeEnvironment.cloudKitContainerID != nil else { return }
        NSApplication.shared.registerForRemoteNotifications()
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // 등록에 실패해도 기록과 동기화는 계속된다. 다른 기기의 변경이 다음 실행 때 들어올 뿐이다.
        NSLog("Daylog: 원격 알림 등록 실패 - %@", error.localizedDescription)
    }
}

/// 저장소를 열 수 없을 때 빈 저장소로 조용히 대체하지 않는다. 그러면 기록이 사라진 것처럼 보인다.
@MainActor
enum AppLaunch {
    case ready(ModelContainer, AppStore, CloudSyncMonitor)
    case failed(String)

    var store: AppStore? {
        if case .ready(_, let store, _) = self { return store }
        return nil
    }

    static func make() -> AppLaunch {
        // 설정에서 고른 외관을 창이 뜨기 전에 적용한다.
        AppearanceMode.stored().apply()
        #if DEBUG
        // 개발 중 화면 검증용: `-DaylogDebugAppearance light|dark`로 설정과 다른 모드를 본다.
        if let name = UserDefaults.standard.string(forKey: "DaylogDebugAppearance") {
            NSApplication.shared.appearance = NSAppearance(named: name == "light" ? .aqua : .darkAqua)
        }
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
            store.start()
            let sync = CloudSyncMonitor(containerIdentifier: cloudContainerID, environment: RuntimeEnvironment.cloudKitEnvironment)
            sync.start()
            #if DEBUG
            DebugScript.runIfRequested(store: store, sync: sync, container: container)
            #endif
            return .ready(container, store, sync)
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

private struct StoreFailureView: View {
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
