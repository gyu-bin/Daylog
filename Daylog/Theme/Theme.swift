import AppKit
import SwiftUI

/// Minimal Green. 색은 시스템 색을 기반으로 하고 포인트 컬러만 직접 정의한다.
enum Theme {
    /// Light #449B6B / Dark #55C98A
    static let accent = Color(nsColor: NSColor(name: "DaylogAccent") { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 0x55 / 255.0, green: 0xC9 / 255.0, blue: 0x8A / 255.0, alpha: 1)
            : NSColor(srgbRed: 0x44 / 255.0, green: 0x9B / 255.0, blue: 0x6B / 255.0, alpha: 1)
    })
    /// 포인트 컬러 위에 올리는 글자·기호. 다크 모드의 밝은 초록 위에서는 어두운 색이어야 읽힌다.
    static let onAccent = Color(nsColor: NSColor(name: "DaylogOnAccent") { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.08, alpha: 1)
            : NSColor.white
    })
    /// 기준 미만인 날처럼 한 단계 약한 강조.
    static let accentSoft = accent.opacity(0.4)
    static let accentWash = accent.opacity(0.12)

    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let separator = Color(nsColor: .separatorColor)
    static let track = Color.primary.opacity(0.08)

    static let cardRadius: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let spacing: CGFloat = 14
    static let pagePadding: CGFloat = 20
}
