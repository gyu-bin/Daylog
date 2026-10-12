import SwiftUI
import UniformTypeIdentifiers

/// 끌어 옮기는 카드의 끌기 데이터: "card:<id>".
enum DashboardDrag {
    static let prefix = "card:"

    static func string(_ card: DashboardCard) -> String { prefix + card.rawValue }

    static func card(from string: String) -> DashboardCard? {
        guard string.hasPrefix(prefix) else { return nil }
        return DashboardCard(rawValue: String(string.dropFirst(prefix.count)))
    }
}

/// 편집 모드의 카드 한 장: 손잡이로 끌고, 다른 카드 위에 놓으면 그 앞에 들어간다. 메뉴로도 옮기고 숨길 수 있다.
/// 안의 체크박스·입력칸·단추는 편집 중에 눌리지 않는다.
struct EditableCard<Content: View>: View {
    @Environment(DevicePreferences.self) private var preferences
    let card: DashboardCard
    /// 지금 속한 열. 띠 카드(주요 지표)는 nil.
    let column: DashboardColumn?
    /// 같은 열의 카드들(위/아래 이동의 범위).
    let siblings: [DashboardCard]
    /// 꾸미기 카드의 편집 시트를 연다(사진·글·크기 바꾸기, 삭제). 기능 카드에는 없다.
    var onEdit: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    @State private var isTargeted = false

    /// 손잡이와 메뉴 단추의 크기. 터치 화면에서는 누르기 쉽게 키운다.
    #if os(macOS)
    private static var controlSize: CGFloat { 28 }
    #else
    private static var controlSize: CGFloat { 40 }
    #endif

    private var isMovable: Bool { !card.spansFullWidth }
    private var index: Int { siblings.firstIndex(of: card) ?? 0 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        VStack(spacing: 0) {
            // 놓을 자리 미리보기: 이 카드 위에 끌어 오면 위쪽에 띠가 생긴다.
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.accent)
                .frame(height: 4)
                .opacity(isTargeted ? 1 : 0)
                .padding(.bottom, isTargeted ? 6 : 0)
            // 편집 막대를 카드 위에 붙이고, 카드 내용은 눌리지 않게 한다.
            VStack(spacing: 0) {
                handleBar
                content()
                    .disabled(true)
                    .allowsHitTesting(false)
            }
            .background(Theme.accentWash.opacity(0.5), in: shape)
            .overlay(shape.strokeBorder(Theme.accent.opacity(isTargeted ? 0.9 : 0.45), style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: isTargeted ? [] : [6, 4])))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .dropDestination(for: String.self) { items, _ in
            guard isMovable, let dragged = items.first.flatMap(DashboardDrag.card(from:)), dragged != card else { return false }
            preferences.place(dragged, before: card)
            return true
        } isTargeted: { isTargeted = isMovable && $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(card.title) 카드, 편집 중")
    }

    /// 카드 위쪽에 겹치는 편집 막대: 손잡이(끌기), 이름, 메뉴.
    private var handleBar: some View {
        HStack(spacing: 8) {
            if isMovable {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: Self.controlSize, height: Self.controlSize)
                    .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
                    .contentShape(Rectangle())
                    .draggable(DashboardDrag.string(card)) {
                        Label(card.title, systemImage: "rectangle.on.rectangle")
                            .padding(10)
                            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .help("끌어서 옮기기")
                    .accessibilityLabel("\(card.title) 끌어서 옮기기")
            }
            Text(card.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let onEdit {
                Button(action: onEdit) {
                    Label("편집", systemImage: "pencil")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .frame(height: Self.controlSize)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("내용·크기 바꾸기, 삭제")
                .accessibilityLabel("\(card.title) 편집")
            }
            Menu {
                if let onEdit {
                    Button("편집…", action: onEdit)
                    Divider()
                }
                if isMovable {
                    Button("위로 이동") { preferences.moveUp(card, in: siblings) }
                        .disabled(index == 0)
                    Button("아래로 이동") { preferences.moveDown(card, in: siblings) }
                        .disabled(index >= siblings.count - 1)
                    if let column {
                        Divider()
                        Button(column == .left ? "오른쪽 열로 이동" : "왼쪽 열로 이동") {
                            preferences.place(card, atEndOf: column == .left ? .right : .left)
                        }
                    }
                }
                if card != .routines {
                    Divider()
                    Button("숨기기") { preferences.setVisible(false, card: card) }
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: Self.controlSize, height: Self.controlSize)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .tint(.secondary)
            .fixedSize()
            .help("위·아래·다른 열로 이동, 숨기기")
            .accessibilityLabel("\(card.title) 카드 옮기기·숨기기")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

/// 열의 맨 아래 빈 자리. 여기에 놓으면 그 열의 마지막이 된다.
struct DropTail: View {
    @Environment(DevicePreferences.self) private var preferences
    let column: DashboardColumn
    @State private var isTargeted = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        Text(isTargeted ? "여기에 놓기" : "카드를 여기로 끌어 오세요")
            .font(.callout)
            .foregroundStyle(isTargeted ? Theme.accent : .secondary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(isTargeted ? Theme.accentWash : Theme.inset, in: shape)
            .overlay(shape.strokeBorder(isTargeted ? Theme.accent : Theme.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [6, 4])))
            .dropDestination(for: String.self) { items, _ in
                guard let dragged = items.first.flatMap(DashboardDrag.card(from:)) else { return false }
                preferences.place(dragged, atEndOf: column)
                return true
            } isTargeted: { isTargeted = $0 }
            .accessibilityLabel("\(column.title) 열의 끝")
    }
}
