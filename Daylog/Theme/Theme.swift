import SwiftUI

/// Modern Colorful Minimal. 바탕은 시스템 색, 색은 의미를 구분하는 곳에만 제한적으로 쓴다.
///
/// 색의 의미: 오늘 달성률 = 민트, 최근 7일 = 파랑, 연속 달성 = 코랄, 최장 연속 = 노랑, 식사 = 주황, 휴가 = 코랄,
/// 루틴 그룹 = 사용자가 고른 색. 일반 버튼과 본문 글자에는 색을 입히지 않는다.
enum Theme {
    /// 앱의 기본 포인트 컬러(민트). 선택 상태와 주요 동작에만 쓴다.
    /// iPhone·iPad에서는 원격 UI 설정이 허용된 색 가운데 하나로 바꿀 수 있고, 앱을 켤 때의 값으로 정해진다.
    static let accent = MobileUIConfigCache.atLaunch.accent.color
    /// 포인트 컬러 위에 올리는 글자·기호. 다크 모드의 밝은 색 위에서는 어두운 색이어야 읽힌다.
    static let onAccent = GroupColor.onAccent
    /// 기준 미만인 날처럼 한 단계 약한 강조.
    static let accentSoft = accent.opacity(0.4)
    static let accentWash = accent.opacity(0.14)

    static let todayTint = GroupColor.mint.color
    static let weekTint = GroupColor.blue.color
    static let streakTint = GroupColor.coral.color
    static let longestTint = GroupColor.yellow.color
    static let mealTint = GroupColor.orange.color
    /// 휴가를 나타내는 색(카드, 달력의 선택 범위).
    static let vacationTint = GroupColor.coral.color

    static let windowBackground = Color.platformWindowBackground
    static let cardBackground = Color.platformCardBackground
    static let separator = Color.platformSeparator
    /// 카드 테두리. 구분선보다 옅게 해서 테두리가 화면을 지배하지 않게 한다.
    static let cardBorder = Color.primary.opacity(0.07)
    static let track = Color.primary.opacity(0.08)
    /// 입력칸·목록 행처럼 카드 안에서 한 단계 들어간 면.
    static let inset = Color.primary.opacity(0.045)

    static let cardRadius: CGFloat = 14
    static let cardPadding: CGFloat = 18
    /// 카드 안의 입력칸·행·단추처럼 작은 면의 모서리.
    static let controlRadius: CGFloat = 9
    static let spacing: CGFloat = 16
    static let pagePadding: CGFloat = 22
    /// macOS 시트의 바깥 여백.
    static let sheetPadding: CGFloat = 22
    /// 좁은 화면(iPhone, 좁은 iPad 창)의 화면 가장자리 여백.
    static let compactPagePadding: CGFloat = 16
    static let statCardHeight: CGFloat = 122
}

/// 식사 종류별 아이콘과 색. 대시보드와 식사 기록 화면이 같이 쓴다.
enum MealKind: CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: Self { self }

    var field: DayTextField {
        switch self {
        case .breakfast: return .breakfast
        case .lunch: return .lunch
        case .dinner: return .dinner
        case .snack: return .snack
        }
    }

    var title: String { field.label }

    var symbol: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "cup.and.saucer.fill"
        }
    }

    var tint: Color {
        switch self {
        case .breakfast: return GroupColor.orange.color
        case .lunch: return GroupColor.yellow.color
        case .dinner: return GroupColor.purple.color
        case .snack: return GroupColor.mint.color
        }
    }
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

extension View {
    /// 화면 가장자리 여백. 좁은 화면에서는 조금 줄인다.
    func pagePadding() -> some View {
        modifier(PagePadding())
    }
}

private struct PagePadding: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content.padding(horizontalSizeClass == .compact ? Theme.compactPagePadding : Theme.pagePadding)
    }
}
