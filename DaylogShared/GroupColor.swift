import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// 앱(macOS·iOS)과 위젯이 함께 쓰는 색. 이 폴더(DaylogShared)의 코드는 저장소나 앱 상태에 기대지 않는다.

/// 그룹 색상 팔레트의 식별자. 저장소에는 이 문자열만 들어가고, 실제 색은 화면 쪽(`Theme`)에서 정한다.
enum GroupColor: String, CaseIterable, Sendable {
    case orange, blue, mint, purple, coral, yellow, green

    /// 모르는 값(나중 버전에서 추가된 색 등)은 기본색으로 본다.
    init(key: String) {
        self = GroupColor(rawValue: key) ?? .green
    }

    var label: String {
        switch self {
        case .orange: return "주황"
        case .blue: return "파랑"
        case .mint: return "민트"
        case .purple: return "보라"
        case .coral: return "코랄"
        case .yellow: return "노랑"
        case .green: return "초록"
        }
    }

    struct RGB: Equatable, Sendable {
        var red: Double
        var green: Double
        var blue: Double

        init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        init(hex: UInt32) {
            self.init(
                red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255
            )
        }

        /// WCAG 상대 휘도.
        var luminance: Double {
            func linear(_ channel: Double) -> Double {
                channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }
    }

    /// 라이트 모드는 명세의 파스텔 팔레트, 다크 모드는 어두운 배경에서 묻히지 않게 한 단계 밝힌 색.
    func rgb(isDark: Bool) -> RGB {
        switch (self, isDark) {
        case (.orange, false): return RGB(hex: 0xF59E63)
        case (.orange, true): return RGB(hex: 0xFFB07A)
        case (.blue, false): return RGB(hex: 0x6395E8)
        case (.blue, true): return RGB(hex: 0x7FAAF5)
        case (.mint, false): return RGB(hex: 0x43BFA6)
        case (.mint, true): return RGB(hex: 0x5AD3BA)
        case (.purple, false): return RGB(hex: 0xA78BFA)
        case (.purple, true): return RGB(hex: 0xB9A2FF)
        case (.coral, false): return RGB(hex: 0xEF8B80)
        case (.coral, true): return RGB(hex: 0xFF948C)
        case (.yellow, false): return RGB(hex: 0xF4C65E)
        case (.yellow, true): return RGB(hex: 0xFFD675)
        case (.green, false): return RGB(hex: 0x36A879)
        case (.green, true): return RGB(hex: 0x55C98A)
        }
    }

    /// 새 그룹에 줄 색: 아직 안 쓴 색 중 첫 번째, 다 썼으면 돌아가며.
    static func next(after used: [String]) -> GroupColor {
        let usedColors = Set(used.map(GroupColor.init(key:)))
        return allCases.first { !usedColors.contains($0) } ?? allCases[used.count % allCases.count]
    }
}

extension GroupColor {
    /// 라이트/다크에 따라 달라지는 그룹 색.
    var color: Color {
        let light = rgb(isDark: false), dark = rgb(isDark: true)
        return Color.adaptive(
            name: "DaylogGroup-\(rawValue)",
            light: (light.red, light.green, light.blue), dark: (dark.red, dark.green, dark.blue)
        )
    }

    /// 큰 숫자처럼 색으로 쓰는 글자. 밝은 배경에서는 파스텔 색이 흐려 보여 한 단계 진하게 쓴다.
    var ink: Color {
        let light = rgb(isDark: false), dark = rgb(isDark: true)
        return Color.adaptive(
            name: "DaylogGroupInk-\(rawValue)",
            light: (light.red * 0.72, light.green * 0.72, light.blue * 0.72), dark: (dark.red, dark.green, dark.blue)
        )
    }

    /// 그룹 머리말 바탕처럼 넓은 면에 까는 옅은 색.
    var wash: Color { color.opacity(0.13) }
}

extension GroupColor {
    /// 그룹 색 위에 올리는 글자·기호. 다크 모드의 밝은 색 위에서는 어두운 색이어야 읽힌다.
    static let onAccent = Color.adaptive(name: "DaylogOnAccent", light: (1, 1, 1), dark: (0.08, 0.08, 0.08))
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
}
