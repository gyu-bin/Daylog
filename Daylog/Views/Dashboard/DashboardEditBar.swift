import SwiftUI

/// 편집 모드의 안내와 도구: 꾸미기 카드 추가, 숨긴 카드 되살리기, 기본 배치 복원, 완료.
struct DashboardEditBar: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    @Environment(DashboardDecor.self) private var decor
    @Binding var isEditing: Bool
    /// 새 꾸미기 카드나 상단 배경의 편집 시트.
    @State private var editorTarget: CustomCardEditorTarget?

    /// 다시 보일 수 있는 숨긴 카드(내용이 사라진 꾸미기 카드는 뺀다).
    private var hiddenChoices: [DashboardCard] {
        preferences.hiddenChoices.filter { decor.isAvailable($0, texts: store.dashboardTexts) }
    }

    /// 다른 기기에서 만든 텍스트 카드 가운데 이 기기의 대시보드에 아직 두지 않은 것.
    private var sharedTexts: [(id: UUID, text: DashboardText)] {
        store.dashboardTexts
            .filter { !preferences.cardOrder.contains(.custom(.text, $0.key)) }
            .map { (id: $0.key, text: $0.value) }
            .sorted { ($0.text.title, $0.text.body, $0.id.uuidString) < ($1.text.title, $1.text.body, $1.id.uuidString) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 넓으면 한 줄, 좁으면(iPhone) 안내와 단추를 두 줄로.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    hint
                    Spacer(minLength: 8)
                    buttons
                }
                VStack(alignment: .leading, spacing: 8) {
                    hint
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        buttons
                    }
                }
            }
            addRow
            if !hiddenChoices.isEmpty {
                HStack(spacing: 8) {
                    Text("숨긴 카드")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 6) {
                        ForEach(hiddenChoices) { card in
                            Button {
                                preferences.setVisible(true, card: card)
                            } label: {
                                Label(card.title, systemImage: "plus")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel("\(card.title) 카드 다시 보이기")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentWash, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .sheet(item: $editorTarget) { CustomCardEditorSheet(target: $0) }
    }

    /// 꾸미기 카드 추가와 상단 배경. 새 카드는 맨 위에 생기고, 끌어서 옮긴다.
    private var addRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("카드 추가")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(CustomCardKind.addable) { kind in
                    chip(kind.shortTitle, symbol: "plus", label: "\(kind.title) 추가") { add(kind) }
                }
                chip(
                    decor.headerImageFile == nil ? "상단 배경" : "상단 배경 바꾸기", symbol: "photo.on.rectangle.angled",
                    label: "상단 배경 이미지 설정"
                ) { editorTarget = .header }
                ForEach(sharedTexts, id: \.id) { item in
                    chip(Self.chipTitle(item.text), symbol: "icloud.and.arrow.down", label: "다른 기기의 텍스트 카드 추가") {
                        decor.setSize(.regular, for: item.id)
                        preferences.addCustom(.custom(.text, item.id))
                    }
                }
            }
        }
    }

    private func chip(_ title: String, symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(label)
    }

    /// 구분선은 정할 내용이 없어 바로 넣고, 나머지는 내용을 적는 시트를 연다.
    private func add(_ kind: CustomCardKind) {
        if kind == .divider {
            let id = UUID()
            decor.setSize(.regular, for: id)
            preferences.addCustom(.custom(.divider, id))
        } else {
            editorTarget = .new(kind)
        }
    }

    /// 다른 기기의 텍스트 카드를 알아볼 수 있게 제목(없으면 내용의 앞부분)을 적는다.
    static func chipTitle(_ text: DashboardText) -> String {
        let source = text.title.isEmpty ? text.body : text.title
        let line = source.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return line.count > 14 ? String(line.prefix(14)) + "…" : line
    }

    private var hint: some View {
        Label("손잡이를 길게 눌러 끌거나 ⋯ 메뉴로 옮기고 숨겨요.", systemImage: "hand.draw")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var buttons: some View {
        Button("기본 배치 복원") { preferences.restoreDashboard() }
            .controlSize(.small)
        Button("완료") { isEditing = false }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .controlSize(.small)
            .keyboardShortcut(.defaultAction)
    }
}
