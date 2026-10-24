import SwiftUI

/// 사이드바: 브랜드 머리말, 주요 메뉴, 맨 아래에 고정된 설정.
/// 창이 낮아지면 메뉴가 스크롤되고 설정은 늘 보인다.
struct SidebarView: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences

    var body: some View {
        let sections = preferences.navigationSections(phone: false)
        VStack(alignment: .leading, spacing: 0) {
            SidebarBrandHeader()
                .padding(.horizontal, 8)
                .padding(.top, 2)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(sections.filter { $0 != .settings }) { section in
                        row(section, shortcut: section.shortcutNumber)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            Divider()
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            row(.settings, shortcut: AppStore.Section.settings.shortcutNumber)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func row(_ section: AppStore.Section, shortcut: Int?) -> some View {
        SidebarRow(section: section, isSelected: store.section == section, shortcut: shortcut) {
            store.section = section
        }
    }
}

/// 앱 아이콘과 이름, 슬로건. 사이드바가 좁아지면 글자를 줄이고, 그래도 모자라면 슬로건부터 뺀다.
/// 글자는 기본 크기(이름 20pt·슬로건 11pt)를 지키면서 iPad의 큰 글자 설정을 따라 커진다(macOS는 그대로).
struct SidebarBrandHeader: View {
    @ScaledMetric(relativeTo: .title3) private var titleSize: CGFloat = 20
    @ScaledMetric(relativeTo: .caption2) private var sloganSize: CGFloat = 11
    @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 42

    var body: some View {
        HStack(spacing: 11) {
            BrandIcon(size: min(iconSize, 56))
            ViewThatFits(in: .horizontal) {
                titles(showsSlogan: true)
                titles(showsSlogan: false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(AppBrand.name), 하루를 기록하다.")
        .accessibilityAddTraits(.isHeader)
    }

    private func titles(showsSlogan: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: AppBrand.name)
                .font(.system(size: titleSize, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if showsSlogan {
                Text("하루를 기록하다.")
                    .font(.system(size: sloganSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

/// RoutiMori 브랜드 아이콘(공식 앱 아이콘과 같은 그림). 사이드바 머리말, 설정의 앱 정보, 시작 안내에 쓴다.
struct BrandIcon: View {
    var size: CGFloat = 42

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        // 공식 앱 아이콘(피오, AppIcon의 iOS 1024 그림과 같은 파일)을 둥근 사각형으로 잘라 쓴다. 다크 변형은 없다.
        Image("BrandIcon")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(shape)
            // 바탕이 밝은 그림이라, 옅은 선으로 사이드바 바탕과 구분한다.
            .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            .accessibilityHidden(true)
    }
}

/// 사이드바 메뉴 한 줄. 색은 아이콘과 선택 표시에만 쓴다.
private struct SidebarRow: View {
    let section: AppStore.Section
    let isSelected: Bool
    /// ⌘ 단축키 번호(이동 메뉴와 같은 번호). 없으면 도움말에 적지 않는다.
    let shortcut: Int?
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// 메뉴 글자·아이콘·줄 높이. 기본은 14pt·22pt·34pt 그대로, iPad의 큰 글자 설정을 따라 함께 커진다(macOS는 그대로).
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 34

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? section.filledSymbol : section.symbol)
                    .font(.system(size: fontSize, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(section.navigationTint) : Self.unselectedIconStyle(section))
                    .frame(width: iconWidth)
                Text(section.title)
                    .font(.system(size: fontSize, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(section.navigationInk) : AnyShapeStyle(.primary))
                    // 큰 글자에서는 메뉴 이름을 자르지 않고 두 줄까지 쓴다.
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 6 : 0)
            .frame(minHeight: rowHeight)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(shortcut.map { "\(section.title) (⌘\($0))" } ?? section.title)
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var rowBackground: Color {
        if isSelected { return section.navigationTint.opacity(0.16) }
        return isHovered ? Theme.track : .clear
    }

    /// 고르지 않은 메뉴의 아이콘 농도. 메뉴 색은 남기되 고른 메뉴(채운 아이콘·바탕)보다 한 단계 물러나 보이게 한다.
    static let unselectedIconOpacity = 0.8

    /// 고르지 않은 메뉴의 아이콘: 메뉴마다의 파스텔 색(macOS·iPad 공통). 글자는 색을 입히지 않아 그대로 읽힌다.
    static func unselectedIconStyle(_ section: AppStore.Section) -> AnyShapeStyle {
        AnyShapeStyle(section.navigationTint.opacity(unselectedIconOpacity))
    }
}

extension AppStore.Section {
    /// 메뉴 아이콘과 선택 표시의 색.
    var tint: Color {
        switch self {
        case .dashboard: return GroupColor.mint.color
        case .routines: return GroupColor.blue.color
        case .meals: return Theme.mealTint
        case .statistics: return GroupColor.purple.color
        case .calendar: return GroupColor.orange.color
        case .vacation: return Theme.vacationTint
        case .templates: return GroupColor.yellow.color
        case .wardrobe: return GroupColor.green.color
        case .settings: return GroupColor.blue.color
        }
    }

    /// 고른 메뉴의 글자색. 메뉴 색을 한 단계 진하게 써서 밝은 바탕에서도 읽힌다.
    var selectedInk: Color {
        switch self {
        case .dashboard: return GroupColor.mint.ink
        case .routines: return GroupColor.blue.ink
        case .meals: return GroupColor.orange.ink
        case .statistics: return GroupColor.purple.ink
        case .calendar: return GroupColor.orange.ink
        case .vacation: return GroupColor.coral.ink
        case .templates: return GroupColor.yellow.ink
        case .wardrobe: return GroupColor.green.ink
        case .settings: return GroupColor.blue.ink
        }
    }

    /// 내비게이션(macOS·iPad 사이드바, iPhone 아래 탭)에서 쓰는 메뉴 색. 세 곳이 같은 색을 쓴다.
    /// 오늘 민트 / 루틴 블루 / 식사 코랄 / 통계 퍼플 / 캘린더 오렌지 / 휴가 청록 / 템플릿 노랑 / 설정 중립 회색.
    /// 화면 안의 색(`tint`: 식사 주황, 휴가 코랄)과는 따로다.
    var navigationTint: Color {
        switch self {
        case .meals: return GroupColor.coral.color
        case .vacation: return Self.tealTint
        case .settings: return Self.neutralTint
        default: return tint
        }
    }

    /// 고른 메뉴의 글자색(내비게이션용). 메뉴 색을 한 단계 진하게 써서 밝은 바탕에서도 읽힌다.
    var navigationInk: Color {
        switch self {
        case .meals: return GroupColor.coral.ink
        case .vacation: return Self.tealInk
        case .settings: return Self.neutralInk
        default: return selectedInk
        }
    }

    /// 휴가 메뉴의 청록. 오늘(민트)·루틴(블루)과 구분되게 둘 사이의 물빛으로 잡았다.
    static let tealTint = Color.adaptive(name: "DaylogNavTeal", light: (0.22, 0.69, 0.78), dark: (0.38, 0.80, 0.88))
    static let tealInk = Color.adaptive(name: "DaylogNavTealInk", light: (0.13, 0.47, 0.55), dark: (0.38, 0.80, 0.88))

    /// 설정 메뉴의 중립 회색(아이콘)과 그보다 진한 글자색. 라이트·다크에서 바탕과 구분된다.
    static let neutralTint = Color.adaptive(name: "DaylogNavNeutral", light: (0.50, 0.53, 0.57), dark: (0.66, 0.68, 0.72))
    static let neutralInk = Color.adaptive(name: "DaylogNavNeutralInk", light: (0.30, 0.32, 0.36), dark: (0.84, 0.86, 0.89))

    var filledSymbol: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .routines: return "checklist"
        case .meals: return "fork.knife"
        case .statistics: return "chart.bar.fill"
        case .calendar: return "calendar"
        case .vacation: return "beach.umbrella.fill"
        case .templates: return "rectangle.stack.fill"
        case .wardrobe: return "tshirt.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
