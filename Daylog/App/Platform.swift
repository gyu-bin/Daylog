import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// macOS와 iOS·iPadOS에서 이름이 다른 것들을 한곳에 모은다. 화면과 서비스는 이 이름만 쓴다.
enum Platform {
    #if os(macOS)
    static let didBecomeActive = NSApplication.didBecomeActiveNotification
    static let willResignActive = NSApplication.willResignActiveNotification
    static let willTerminate = NSApplication.willTerminateNotification
    /// 잠자기에서 깨어났거나 시계가 크게 바뀐 시점.
    static var timeMayHaveJumped: NotificationCenter.Publisher {
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
    }
    static let thisDevice = "이 Mac"
    #else
    static let didBecomeActive = UIApplication.didBecomeActiveNotification
    static let willResignActive = UIApplication.willResignActiveNotification
    static let willTerminate = UIApplication.willTerminateNotification
    static var timeMayHaveJumped: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
    }
    static var thisDevice: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "이 iPad" : "이 iPhone"
    }
    #endif
}

extension Color {
    /// 라이트/다크에 따라 달라지는 색. 값은 sRGB 0...1.
    static func adaptive(name: String, light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        #if os(macOS)
        return Color(nsColor: NSColor(name: name) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: value.0, green: value.1, blue: value.2, alpha: 1)
        })
        #else
        return Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
        })
        #endif
    }

    /// 화면 바탕, 카드 바탕, 구분선. 각 플랫폼의 시스템 색을 쓴다.
    static var platformWindowBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }

    static var platformCardBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    static var platformSeparator: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color(uiColor: .separator)
        #endif
    }
}
