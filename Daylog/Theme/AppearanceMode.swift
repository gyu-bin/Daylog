import AppKit

/// 앱의 외관 설정. 이 Mac의 UserDefaults에만 저장하고 iCloud로 동기화하지 않는다
/// (Mac mini와 MacBook에서 서로 다른 외관을 고를 수 있어야 한다).
enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    /// Mac의 외관 설정을 따른다. 시스템 외관이 바뀌면 같이 바뀐다.
    case system
    case light
    case dark

    static let storageKey = "appearanceMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "시스템 설정"
        case .light: return "라이트"
        case .dark: return "다크"
        }
    }

    /// 앱에 지정할 외관의 이름. 시스템을 따를 때는 nil(지정하지 않음).
    var appearanceName: NSAppearance.Name? {
        switch self {
        case .system: return nil
        case .light: return .aqua
        case .dark: return .darkAqua
        }
    }

    /// 저장된 설정. 없거나 알 수 없는 값이면 시스템 설정을 따른다.
    static func stored(in defaults: UserDefaults = .standard) -> AppearanceMode {
        defaults.string(forKey: storageKey).flatMap(AppearanceMode.init(rawValue:)) ?? .system
    }

    /// 앱 전체(창, 시트, 팝오버, 알림창, 메뉴)에 적용한다.
    /// SwiftUI의 `preferredColorScheme`은 창의 내용에만 걸려서 알림창·메뉴가 따로 놀 수 있고
    /// 시스템 설정으로 되돌릴 때 바로 풀리지 않는 경우가 있어, 앱의 외관을 직접 지정한다.
    @MainActor
    func apply(to application: NSApplication? = nil) {
        (application ?? .shared).appearance = appearanceName.flatMap(NSAppearance.init(named:))
    }
}

/// 실행 중인 동안 Dock 아이콘을 앱의 외관에 맞춘다.
///
/// macOS의 에셋 카탈로그는 앱 아이콘의 다크 변형을 iOS에서만 지원한다(macOS는 Icon Composer 파일이 필요하다).
/// 그래서 번들의 기본 아이콘은 라이트로 두고, 앱이 다크로 보이는 동안에만 `applicationIconImage`로 다크 아이콘을 건다.
/// 앱을 끄면 Dock과 Finder에는 기본(라이트) 아이콘이 보인다.
@MainActor
enum DockIcon {
    static let darkImageName = "DockIconDark"

    static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    /// 외관이 바뀔 때마다 호출한다. 라이트에서는 nil을 넣어 번들의 기본 아이콘으로 되돌린다.
    static func update(for application: NSApplication) {
        application.applicationIconImage = image(for: application.effectiveAppearance)
    }

    /// 그 외관에서 걸 Dock 아이콘. 라이트는 번들의 기본 아이콘을 쓰므로 nil.
    static func image(for appearance: NSAppearance) -> NSImage? {
        isDark(appearance) ? NSImage(named: darkImageName) : nil
    }
}
