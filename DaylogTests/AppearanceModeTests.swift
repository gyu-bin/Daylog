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

/// 브랜드 아이콘 에셋과 외관 연동
@MainActor
struct BrandIconTests {
    /// 그 외관에서 그렸을 때 아이콘 한가운데 위쪽(배경 부분)의 밝기.
    private func backgroundBrightness(of image: NSImage, in appearanceName: NSAppearance.Name, at y: Int = 5) throws -> CGFloat {
        let appearance = try #require(NSAppearance(named: appearanceName))
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        appearance.performAsCurrentDrawingAppearance {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            image.draw(in: NSRect(x: 0, y: 0, width: 64, height: 64))
            NSGraphicsContext.restoreGraphicsState()
        }
        return try #require(rep.colorAt(x: 32, y: y)).brightnessComponent
    }

    /// 앱 안의 브랜드 아이콘은 외관에 따라 라이트·다크 그림으로 바뀐다.
    @Test func brandIconFollowsAppearance() throws {
        let image = try #require(NSImage(named: "BrandIcon"))
        #expect(try backgroundBrightness(of: image, in: .aqua) > 0.9)
        #expect(try backgroundBrightness(of: image, in: .darkAqua) < 0.5)
    }

    /// Dock 아이콘: 다크일 때만 다크 그림을 걸고, 라이트에서는 번들의 기본 아이콘으로 되돌린다(nil).
    @Test func dockIconFollowsAppearance() throws {
        let dark = try #require(NSAppearance(named: .darkAqua))
        let light = try #require(NSAppearance(named: .aqua))
        #expect(DockIcon.isDark(dark))
        #expect(!DockIcon.isDark(light))
        #expect(DockIcon.image(for: light) == nil)
        let image = try #require(DockIcon.image(for: dark))
        // macOS 아이콘 격자에 맞춘 그림이라 가장자리는 투명하고, 안쪽 배경은 어둡다.
        #expect(try backgroundBrightness(of: image, in: .darkAqua, at: 12) < 0.5)
    }

    /// v1.4: 식사 기록과 캘린더가 따로 생겨 여섯 개. 이후 휴가 메뉴가 더해져 일곱 개(설정은 늘 마지막).
    @Test func sidebarMenuHasSevenSections() {
        #expect(AppStore.Section.allCases.map(\.title) == ["오늘", "루틴", "식사 기록", "통계", "캘린더", "휴가", "설정"])
        #expect(Set(AppStore.Section.allCases.map(\.filledSymbol)).count == 7)
    }

    /// 아래 탭(iPhone, 좁은 iPad 창)은 다섯 개. 캘린더는 통계 화면 안에서 연다.
    @Test func phoneTabsLeaveCalendarToStatistics() {
        #expect(AppStore.Section.phoneTabs == [.dashboard, .routines, .meals, .statistics, .settings])
        #expect(!AppStore.Section.phoneTabs.contains(.calendar))
    }
}
