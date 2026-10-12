import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// macOS와 iOS·iPadOS에서 이름이 다른 것들을 한곳에 모은다. 화면과 서비스는 이 이름만 쓴다.
enum Platform {
    /// "1.5.1 (1)" 같은 앱 버전.
    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "—") (\(info?["CFBundleVersion"] as? String ?? "—"))"
    }

    #if os(macOS)
    static let didBecomeActive = NSApplication.didBecomeActiveNotification
    static let willResignActive = NSApplication.willResignActiveNotification
    static let willTerminate = NSApplication.willTerminateNotification
    /// 잠자기에서 깨어났거나 시계가 크게 바뀐 시점.
    static var timeMayHaveJumped: NotificationCenter.Publisher {
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
    }
    static let thisDevice = "이 Mac"
    static let isPhone = false
    /// iCloud 기기 목록에 적는 이름과 종류.
    static var deviceName: String { Host.current().localizedName ?? "Mac" }
    static let deviceKind = DeviceInfo.Kind.mac

    /// 시스템 설정의 알림 화면을 연다.
    @MainActor
    static func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
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
    static var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    /// iCloud 기기 목록에 적는 이름과 종류. iOS는 사용자가 지은 기기 이름을 앱에 주지 않아 "iPhone"·"iPad"로 나온다.
    static var deviceName: String { UIDevice.current.name }
    static var deviceKind: DeviceInfo.Kind { UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone }

    /// 설정 앱에서 Daylog의 알림 화면을 연다.
    @MainActor
    static func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    #endif
}

extension Color {
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
