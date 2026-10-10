import AppKit
import SwiftUI

/// Modern Colorful Minimal. 바탕은 시스템 색, 색은 그룹·지표를 구분하는 곳에만 제한적으로 쓴다.
enum Theme {
    /// 앱의 기본 포인트 컬러(초록). Light #36A879 / Dark #55C98A
    static let accent = GroupColor.green.color
    /// 포인트 컬러 위에 올리는 글자·기호. 다크 모드의 밝은 색 위에서는 어두운 색이어야 읽힌다.
    static let onAccent = Color(nsColor: NSColor(name: "DaylogOnAccent") { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.08, alpha: 1)
            : NSColor.white
    })
    /// 기준 미만인 날처럼 한 단계 약한 강조.
    static let accentSoft = accent.opacity(0.4)
    static let accentWash = accent.opacity(0.12)

    // 지표 카드마다 다른 색으로 구분한다(아이콘과 작은 그래프에만 쓴다).
    static let todayTint = GroupColor.green.color
    static let weekTint = GroupColor.blue.color
    static let streakTint = GroupColor.coral.color
    static let longestTint = GroupColor.yellow.color

    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let separator = Color(nsColor: .separatorColor)
    static let track = Color.primary.opacity(0.08)

    static let cardRadius: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let spacing: CGFloat = 14
    static let pagePadding: CGFloat = 20
}

extension GroupColor {
    /// 라이트/다크에 따라 달라지는 그룹 색.
    var color: Color {
        Color(nsColor: NSColor(name: "DaylogGroup-\(rawValue)") { appearance in
            let rgb = self.rgb(isDark: appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
            return NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        })
    }

    /// 그룹 머리말 바탕처럼 넓은 면에 까는 옅은 색.
    var wash: Color { color.opacity(0.13) }
}

/// 그룹을 나타내는 작은 배지: 그룹 색 바탕에 이름의 첫 글자. 색을 못 보더라도 글자로 구분된다.
struct GroupBadge: View {
    let title: String
    let color: GroupColor
    var size: CGFloat = 22

    var body: some View {
        Text(title.trimmingCharacters(in: .whitespaces).prefix(1))
            .font(.system(size: size * 0.52, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.onAccent)
            .frame(width: size, height: size)
            .background(color.color, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}
