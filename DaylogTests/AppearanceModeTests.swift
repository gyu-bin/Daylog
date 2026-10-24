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

    /// 앱 안의 브랜드 아이콘(사이드바·설정·온보딩)은 공식 RoutiMori 앱 아이콘(피오)과 같은 그림이다.
    /// 2026-10-24: 옛 Daylog 나뭇잎 아이콘(라이트·다크 두 그림)을 공식 아이콘으로 바꿨다. 공식 아이콘에는 다크 변형이 없어
    /// 외관과 상관없이 같은 밝은 바탕이다(예전 테스트는 다크에서 어두운 그림을 기대했다).
    @Test func brandIconIsTheOfficialAppIconInEveryAppearance() throws {
        let image = try #require(NSImage(named: "BrandIcon"))
        let light = try backgroundBrightness(of: image, in: .aqua)
        let dark = try backgroundBrightness(of: image, in: .darkAqua)
        #expect(light > 0.8)
        #expect(abs(light - dark) < 0.02)
        // 공식 아이콘 원본(AppIcon의 iOS 1024)과 같은 파일에서 왔다: 1024 정사각형, 투명 없이 꽉 찬 그림.
        let rep = try #require(image.representations.first)
        #expect(rep.pixelsWide == 1024 && rep.pixelsHigh == 1024)
    }

    /// Dock 아이콘: 공식 아이콘에 다크 변형이 없으므로 어느 외관에서도 번들의 앱 아이콘을 그대로 둔다(nil).
    /// 예전에는 다크에서 옛 나뭇잎 다크 아이콘을 걸었다.
    @Test func dockIconKeepsTheBundleIconInEveryAppearance() throws {
        let dark = try #require(NSAppearance(named: .darkAqua))
        let light = try #require(NSAppearance(named: .aqua))
        #expect(DockIcon.isDark(dark))
        #expect(!DockIcon.isDark(light))
        #expect(DockIcon.image(for: light) == nil)
        #expect(DockIcon.image(for: dark) == nil)
        #expect(NSImage(named: "DockIconDark") == nil, "옛 나뭇잎 다크 Dock 아이콘 에셋이 남아 있으면 안 된다")
    }

    /// v1.4: 식사 기록과 캘린더가 따로 생겨 여섯 개. 이후 휴가, 템플릿(Phase 5-C), 피오 옷장이 더해져 아홉 개(설정은 늘 마지막).
    @Test func sidebarMenuHasSevenSections() {
        #expect(AppStore.Section.allCases.map(\.title) == ["오늘", "루틴", "식사 기록", "통계", "캘린더", "휴가", "템플릿", "피오 옷장", "설정"])
        #expect(Set(AppStore.Section.allCases.map(\.filledSymbol)).count == 9)
    }

    /// 아래 탭(iPhone, 좁은 iPad 창)은 다섯 개. 캘린더는 통계 화면 안에서 연다.
    @Test func phoneTabsLeaveCalendarToStatistics() {
        #expect(AppStore.Section.phoneTabs == [.dashboard, .routines, .meals, .statistics, .settings])
        #expect(!AppStore.Section.phoneTabs.contains(.calendar))
    }
}
