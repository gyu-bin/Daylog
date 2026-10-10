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
