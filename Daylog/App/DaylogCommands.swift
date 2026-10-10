import SwiftUI

struct DaylogCommands: Commands {
    let store: AppStore?

    var body: some Commands {
        // 창이 하나뿐인 앱이라 "새 창" 대신 ⌘N을 루틴 빠른 추가에 쓴다.
        // 마지막으로 쓴 그룹(없으면 첫 그룹)의 항목 입력칸으로 가고, 그룹이 없으면 그룹 이름 입력칸으로 간다.
        CommandGroup(replacing: .newItem) {
            Button("새 루틴 항목") {
                store?.requestQuickAddFocus()
            }
            .keyboardShortcut("n")
            .disabled(store == nil)
        }

        CommandMenu("이동") {
            Button("이전 날짜") { store?.goToPreviousDay() }
                .keyboardShortcut("[")
            Button("다음 날짜") { store?.goToNextDay() }
                .keyboardShortcut("]")
                .disabled(!(store?.canGoToNextDay ?? false))
            Button("오늘") { store?.goToToday() }
                .keyboardShortcut("t")
            Divider()
            ForEach(Array(AppStore.Section.allCases.enumerated()), id: \.element) { index, section in
                Button(section.title) { store?.section = section }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
            }
        }
    }
}
