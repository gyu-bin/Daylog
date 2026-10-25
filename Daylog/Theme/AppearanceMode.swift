import SwiftUI
#if os(macOS)
import AppKit
#endif

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

    /// SwiftUI의 색 구성. 시스템을 따를 때는 nil. iOS·iPadOS에서 화면 전체에 건다.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    #if os(macOS)
    /// 앱에 지정할 외관의 이름. 시스템을 따를 때는 nil(지정하지 않음).
    var appearanceName: NSAppearance.Name? {
        switch self {
        case .system: return nil
        case .light: return .aqua
        case .dark: return .darkAqua
        }
    }
    #endif

    /// 저장된 설정. 없거나 알 수 없는 값이면 시스템 설정을 따른다.
    static func stored(in defaults: UserDefaults = .standard) -> AppearanceMode {
        defaults.string(forKey: storageKey).flatMap(AppearanceMode.init(rawValue:)) ?? .system
    }

    #if os(macOS)
    /// 앱 전체(창, 시트, 팝오버, 알림창, 메뉴)에 적용한다.
    /// SwiftUI의 `preferredColorScheme`은 창의 내용에만 걸려서 알림창·메뉴가 따로 놀 수 있고
    /// 시스템 설정으로 되돌릴 때 바로 풀리지 않는 경우가 있어, 앱의 외관을 직접 지정한다.
    @MainActor
    func apply(to application: NSApplication? = nil) {
        (application ?? .shared).appearance = appearanceName.flatMap(NSAppearance.init(named:))
    }
    #endif
}

#if os(macOS)
/// 실행 중인 동안 Dock 아이콘을 앱의 외관에 맞춘다.
///
/// 예전(Daylog 나뭇잎 아이콘)에는 다크로 보이는 동안 `applicationIconImage`로 다크 아이콘을 걸었다.
/// 지금의 공식 RoutiMori 아이콘(피오)에는 승인된 다크 변형이 없어서, 외관과 상관없이 번들의 앱 아이콘을 그대로 둔다
/// (다크에서 옛 나뭇잎 아이콘이 Dock에 뜨던 문제, 2026-10-24). 다크 변형이 생기면 여기서 다시 건다.
@MainActor
enum DockIcon {
    /// 다크 외관에서 걸 Dock 아이콘 에셋 이름. 공식 아이콘에 다크 변형이 없으므로 nil(번들 아이콘 유지).
    static let darkImageName: String? = nil

    static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    /// 외관이 바뀔 때마다 호출한다. 라이트에서는 nil을 넣어 번들의 기본 아이콘으로 되돌린다.
    static func update(for application: NSApplication) {
        application.applicationIconImage = image(for: application.effectiveAppearance)
    }

    /// 그 외관에서 걸 Dock 아이콘. 라이트는 번들의 기본 아이콘을 쓰므로 nil.
    static func image(for appearance: NSAppearance) -> NSImage? {
        // 피오 시범(검증용 앱에서만)은 번들 아이콘(피오)을 그대로 둔다.
        if PioTrial.isEnabled { return nil }
        guard isDark(appearance), let darkImageName else { return nil }
        return NSImage(named: darkImageName)
    }
}
#endif
