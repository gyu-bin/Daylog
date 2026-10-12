import SwiftUI

/// 내일 오전에 할 일 한 줄. 그날의 기록(`DayRecord.tomorrowTask`)에 저장된다.
struct TomorrowTaskCard: View {
    @Environment(AppStore.self) private var store
    @FocusState private var isFocused: Bool

    var body: some View {
        let label = store.isViewingToday ? "내일 오전 할 일" : "다음 날 오전 할 일"
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(symbol: "lightbulb.fill", title: label, tint: GroupColor.yellow.color)
                TextField(
                    label,
                    text: Binding(
                        get: { store.text(\.tomorrowTask) },
                        set: { store.setText($0, at: \.tomorrowTask) }
                    ),
                    prompt: Text("한 줄로 적어 두세요")
                )
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .labelsHidden()
                .accessibilityLabel(label)
            }
            // 날짜가 바뀌면 입력 칸을 새로 만들어 이전 날짜의 포커스·편집 상태를 넘기지 않는다.
            .id(store.selectedDay)
        }
        .onChange(of: isFocused) { _, focused in
            store.setEditing(focused, source: "tomorrow")
        }
    }
}
