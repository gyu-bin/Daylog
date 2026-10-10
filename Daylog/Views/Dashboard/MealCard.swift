import AppKit
import SwiftUI

/// 아침·점심·저녁·간식과 식사 메모. 모두 자유 텍스트이고 자동 저장된다.
struct MealCard: View {
    @Environment(AppStore.self) private var store
    @FocusState private var focus: DayTextField?

    /// Enter를 눌렀을 때 이동할 칸.
    private func next(after field: DayTextField) -> DayTextField {
        switch field {
        case .breakfast: return .lunch
        case .lunch: return .dinner
        case .dinner: return .snack
        default: return .mealMemo
        }
    }

    var body: some View {
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(
                    symbol: "fork.knife",
                    title: store.isViewingToday ? "오늘의 식사 기록" : "\(store.selectedDay.shortTitle)의 식사 기록",
                    tint: Theme.mealTint
                )

                VStack(spacing: 6) {
                    ForEach(MealKind.allCases) { kind in
                        mealRow(kind)
                    }
                }

                memo
            }
            // 날짜가 바뀌면 입력 칸을 새로 만들어 이전 날짜의 포커스·편집 상태를 넘기지 않는다.
            .id(store.selectedDay)
        }
        .onChange(of: focus) { _, newValue in
            store.setEditing(newValue != nil, source: "meal")
        }
    }

    private func binding(_ field: DayTextField) -> Binding<String> {
        Binding(
            get: { store.text(field.keyPath) },
            set: { store.setText($0, at: field.keyPath) }
        )
    }

    private func mealRow(_ kind: MealKind) -> some View {
        let field = kind.field
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label {
                Text(kind.title).font(.callout.weight(.semibold))
            } icon: {
                Image(systemName: kind.symbol).foregroundStyle(kind.tint)
            }
            .frame(width: 66, alignment: .leading)
            .accessibilityHidden(true)

            TextField(kind.title, text: binding(field), prompt: Text("무엇을 드셨나요?"), axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                // macOS에서는 이게 없으면 긴 내용이 한 줄에서 잘린 채 늘어나지 않는다.
                .fixedSize(horizontal: false, vertical: true)
                .focused($focus, equals: field)
                .onSubmit {
                    focus = next(after: field)
                    moveCaretToEnd()
                }
                // Shift+Enter는 다음 칸으로 넘어가지 않고 커서 위치에 줄바꿈을 넣는다.
                .onKeyPress(.return, phases: .down) { press in
                    guard press.modifiers.contains(.shift) else { return .ignored }
                    NSApp.sendAction(#selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)), to: nil, from: nil)
                    return .handled
                }
                .accessibilityLabel(kind.title)
                .accessibilityHint("Enter로 다음 칸, Shift+Enter로 줄바꿈")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(alignment: .leading) {
            // 포커스가 있는 칸은 왼쪽에 그 식사의 색 띠를 보여 준다.
            if focus == field {
                RoundedRectangle(cornerRadius: 2).fill(kind.tint).frame(width: 3).padding(.vertical, 7)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focus = field
        }
    }

    /// 포커스를 옮기면 macOS는 칸 전체를 선택한다. 그대로 타이핑하면 기존 내용이 지워지므로
    /// 이어 쓸 수 있게 커서를 끝으로 보낸다.
    private func moveCaretToEnd() {
        DispatchQueue.main.async {
            guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
            editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        }
    }

    private var memo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(DayTextField.mealMemo.label).font(.callout.weight(.semibold))
            } icon: {
                Image(systemName: "note.text").foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)

            TextEditor(text: binding(.mealMemo))
                .font(.body)
                .scrollContentBackground(.hidden)
                .focused($focus, equals: .mealMemo)
                .frame(height: 62)
                .overlay(alignment: .topLeading) {
                    if store.text(\.mealMemo).isEmpty {
                        Text("컨디션, 물 섭취량 등 자유롭게 적어 두세요")
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel(DayTextField.mealMemo.label)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.inset, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
