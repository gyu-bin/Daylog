import AppKit
import Foundation
import Testing
@testable import Daylog

/// v1.3.2: 앱 내부의 외관(시스템/라이트/다크) 설정
struct AppearanceModeTests {
    /// 테스트마다 따로 쓰는 UserDefaults. 실제 앱 설정은 건드리지 않는다.
    private func makeDefaults() throws -> (UserDefaults, String) {
        let name = "daylog.tests.appearance.\(UUID().uuidString)"
        return (try #require(UserDefaults(suiteName: name)), name)
    }

    @Test func defaultsToSystem() throws {
        let (defaults, name) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(AppearanceMode.stored(in: defaults) == .system)
    }

    @Test func choiceSurvivesRelaunch() throws {
        let (defaults, name) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        for mode in AppearanceMode.allCases {
            defaults.set(mode.rawValue, forKey: AppearanceMode.storageKey)
            // 앱을 다시 실행하면 같은 이름의 UserDefaults를 새로 연다.
            let reopened = try #require(UserDefaults(suiteName: name))
            #expect(AppearanceMode.stored(in: reopened) == mode)
        }
    }

    @Test func unknownValueFallsBackToSystem() throws {
        let (defaults, name) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("sepia", forKey: AppearanceMode.storageKey)
        #expect(AppearanceMode.stored(in: defaults) == .system)
    }

    @Test func mapsToAppearances() {
        #expect(AppearanceMode.allCases.map(\.title) == ["시스템 설정", "라이트", "다크"])
        // 시스템을 따를 때는 외관을 지정하지 않는다. 그래야 Mac의 외관이 바뀔 때 같이 바뀐다.
        #expect(AppearanceMode.system.appearanceName == nil)
        #expect(AppearanceMode.light.appearanceName == .aqua)
        #expect(AppearanceMode.dark.appearanceName == .darkAqua)
    }

    /// 외관은 이 Mac의 설정 파일에만 있다. 동기화되는 저장소(AppSettings)에는 관련 속성이 없다.
    @Test func isNotPartOfTheSyncedSettings() {
        let synced = Mirror(reflecting: AppSettings()).children.compactMap(\.label)
        #expect(!synced.contains { $0.lowercased().contains("appearance") || $0.lowercased().contains("theme") })
    }

    @MainActor
    @Test func appliesToTheWholeApp() {
        let application = NSApplication.shared
        let original = application.appearance
        defer { application.appearance = original }

        AppearanceMode.dark.apply(to: application)
        #expect(application.appearance?.name == .darkAqua)
        AppearanceMode.light.apply(to: application)
        #expect(application.appearance?.name == .aqua)
        AppearanceMode.system.apply(to: application)
        #expect(application.appearance == nil)
    }
}
