import SwiftUI

/// 사이드바: 브랜드 머리말, 메뉴, 아래쪽 한 줄 문구.
struct SidebarView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SidebarBrandHeader()
                .padding(.horizontal, 8)
                .padding(.top, 2)
                .padding(.bottom, 16)

            ForEach(Array(AppStore.Section.allCases.enumerated()), id: \.element) { index, section in
                SidebarRow(section: section, isSelected: store.section == section, shortcut: index + 1) {
                    store.section = section
                }
            }

            Spacer(minLength: 12)

            Divider()
                .padding(.horizontal, 8)
            Text("오늘도, 더 나은 하루를 위해.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// 앱 아이콘과 이름, 슬로건. 사이드바가 좁아지면 글자를 줄이고, 그래도 모자라면 슬로건부터 뺀다.
struct SidebarBrandHeader: View {
    var body: some View {
        HStack(spacing: 11) {
            BrandIcon(size: 42)
            ViewThatFits(in: .horizontal) {
                titles(showsSlogan: true)
                titles(showsSlogan: false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daylog, 하루를 기록하다.")
        .accessibilityAddTraits(.isHeader)
    }

    private func titles(showsSlogan: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Daylog")
                .font(.system(size: 20, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if showsSlogan {
                Text("하루를 기록하다.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

/// Daylog 앱 아이콘. 앱의 외관(시스템/라이트/다크)에 따라 라이트·다크 그림이 자동으로 바뀐다.
struct BrandIcon: View {
    var size: CGFloat = 42

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        Image("BrandIcon")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            // 라이트 아이콘은 바탕이 밝아서, 옅은 선으로 사이드바 바탕과 구분한다.
            .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            .accessibilityHidden(true)
    }
}

/// 사이드바 메뉴 한 줄. 색은 아이콘과 선택 표시에만 쓴다.
private struct SidebarRow: View {
    let section: AppStore.Section
    let isSelected: Bool
    let shortcut: Int
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.filledSymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(section.tint)
                    .frame(width: 22)
                Text(section.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("\(section.title) (⌘\(shortcut))")
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var rowBackground: Color {
        if isSelected { return section.tint.opacity(0.18) }
        return isHovered ? Theme.track : .clear
    }
}

extension AppStore.Section {
    /// 메뉴 아이콘과 선택 표시의 색.
    var tint: Color {
        switch self {
        case .dashboard: return GroupColor.mint.color
        case .routines: return GroupColor.blue.color
        case .meals: return GroupColor.coral.color
        case .statistics: return GroupColor.purple.color
        case .calendar: return GroupColor.orange.color
        case .settings: return Color.secondary
        }
    }

    var filledSymbol: String {
        switch self {
        case .dashboard: return "house.fill"
        case .routines: return "checklist"
        case .meals: return "fork.knife"
        case .statistics: return "chart.bar.fill"
        case .calendar: return "calendar"
        case .settings: return "gearshape.fill"
        }
    }
}
