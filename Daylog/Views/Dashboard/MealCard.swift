import AppKit
import SwiftUI

/// 아침·점심·저녁·간식과 식사 메모. 모두 자유 텍스트이고 자동 저장된다.
struct MealCard: View {
    @Environment(AppStore.self) private var store
    @FocusState private var focus: Field?

    private enum Field: Hashable, CaseIterable {
        case breakfast, lunch, dinner, snack, memo

        var title: String {
            switch self {
            case .breakfast: return "아침"
            case .lunch: return "점심"
            case .dinner: return "저녁"
            case .snack: return "간식"
            case .memo: return "식사 메모"
            }
        }

        var symbol: String {
            switch self {
            case .breakfast: return "sunrise.fill"
            case .lunch: return "sun.max.fill"
            case .dinner: return "moon.fill"
            case .snack: return "cup.and.saucer.fill"
            case .memo: return "note.text"
            }
        }

        var tint: Color {
            switch self {
            case .breakfast: return .orange
            case .lunch: return .yellow
            case .dinner: return .indigo
            case .snack: return .teal
            case .memo: return Theme.accent
            }
        }

        var keyPath: ReferenceWritableKeyPath<DayRecord, String> {
            switch self {
            case .breakfast: return \.breakfast
            case .lunch: return \.lunch
            case .dinner: return \.dinner
            case .snack: return \.snack
            case .memo: return \.mealMemo
            }
        }

        /// Enter를 눌렀을 때 이동할 칸.
        var next: Field {
            switch self {
            case .breakfast: return .lunch
            case .lunch: return .dinner
            case .dinner: return .snack
            case .snack, .memo: return .memo
            }
        }

        static let meals: [Field] = [.breakfast, .lunch, .dinner, .snack]
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(
                    symbol: "fork.knife",
                    title: store.isViewingToday ? "오늘의 식사 기록" : "\(store.selectedDay.shortTitle)의 식사 기록"
                )

                VStack(spacing: 0) {
                    ForEach(Field.meals, id: \.self) { field in
                        if field != .breakfast { Divider() }
                        mealRow(field)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.separator, lineWidth: 1))

                memo
                    .frame(maxHeight: .infinity)
            }
            // 날짜가 바뀌면 입력 칸을 새로 만들어 이전 날짜의 포커스·편집 상태를 넘기지 않는다.
            .id(store.selectedDay)
        }
        .onChange(of: focus) { _, newValue in
            store.setEditing(newValue != nil, source: "meal")
        }
    }

    private func binding(_ field: Field) -> Binding<String> {
        Binding(
            get: { store.text(field.keyPath) },
            set: { store.setText($0, at: field.keyPath) }
        )
    }

    private func mealRow(_ field: Field) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Label {
                Text(field.title).font(.body.weight(.semibold))
            } icon: {
                Image(systemName: field.symbol).foregroundStyle(field.tint)
            }
            .frame(width: 88, alignment: .leading)
            .accessibilityHidden(true)

            TextField(field.title, text: binding(field), prompt: Text("무엇을 드셨나요?"), axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                // macOS에서는 이게 없으면 긴 내용이 한 줄에서 잘린 채 늘어나지 않는다.
                .fixedSize(horizontal: false, vertical: true)
                .focused($focus, equals: field)
                .onSubmit {
                    focus = field.next
                    moveCaretToEnd()
                }
                // Shift+Enter는 다음 칸으로 넘어가지 않고 커서 위치에 줄바꿈을 넣는다.
                .onKeyPress(.return, phases: .down) { press in
                    guard press.modifiers.contains(.shift) else { return .ignored }
                    NSApp.sendAction(#selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)), to: nil, from: nil)
                    return .handled
                }
                .accessibilityLabel(field.title)
                .accessibilityHint("Enter로 다음 칸, Shift+Enter로 줄바꿈")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
                Text(Field.memo.title).font(.body.weight(.semibold))
            } icon: {
                Image(systemName: Field.memo.symbol).foregroundStyle(Field.memo.tint)
            }
            .accessibilityHidden(true)

            TextEditor(text: binding(.memo))
                .font(.body)
                .scrollContentBackground(.hidden)
                .focused($focus, equals: .memo)
                .frame(minHeight: 60, idealHeight: 60)
                .overlay(alignment: .topLeading) {
                    if store.text(\.mealMemo).isEmpty {
                        Text("컨디션, 물 섭취량 등 자유롭게 적어 두세요")
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel(Field.memo.title)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
