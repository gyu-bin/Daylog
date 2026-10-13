import SwiftUI

struct DaylogCommands: Commands {
    let store: AppStore?

    var body: some Commands {
        #if os(macOS)
        CommandGroup(after: .appInfo) {
            CheckForUpdatesButton()
        }
        // 앱 메뉴의 표준 자리(⌘,). 창을 닫아 두었으면 다시 연다.
        CommandGroup(replacing: .appSettings) {
            OpenSettingsButton(store: store)
        }
        #endif

        // 창이 하나뿐인 앱이라 "새 창" 대신 ⌘N을 루틴 빠른 추가에 쓴다.
        // 마지막으로 쓴 그룹(없으면 첫 그룹)의 항목 입력칸으로 가고, 그룹이 없으면 그룹 이름 입력칸으로 간다.
        CommandGroup(replacing: .newItem) {
            Button("새 루틴 항목") {
                store?.requestQuickAddFocus(
                    dashboardShowsRoutines: !DevicePreferences.shared.hiddenCards.contains(.routines),
                    isShowingSheet: Platform.isShowingSheet
                )
            }
            .keyboardShortcut("n")
            .disabled(store == nil)
        }

        CommandMenu("이동") {
            // 편집 시트가 떠 있으면 날짜도 바꾸지 않는다: 그날의 휴가 카드처럼 시트를 띄운 카드가 사라지면 시트도 닫힌다.
            Button("이전 날짜") { if !Platform.isShowingSheet { store?.goToPreviousDay() } }
                .keyboardShortcut("[")
            Button("다음 날짜") { if !Platform.isShowingSheet { store?.goToNextDay() } }
                .keyboardShortcut("]")
                .disabled(!(store?.canGoToNextDay ?? false))
            // 화면 목록의 "오늘"(⌘1)과 이름이 겹치지 않게 날짜임을 적는다.
            Button("오늘 날짜") { if !Platform.isShowingSheet { store?.goToToday() } }
                .keyboardShortcut("t")
            Divider()
            ForEach(Array(DevicePreferences.shared.navigationSections(phone: false).enumerated()), id: \.element) { index, section in
                Button(section.title) { store?.go(to: section, isShowingSheet: Platform.isShowingSheet) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
            }
        }
    }
}

#if os(macOS)
/// 앱 메뉴의 "설정…": 설정 화면으로 간다. 편집 시트가 떠 있으면 아무것도 하지 않는다(시트가 닫히지 않게).
private struct OpenSettingsButton: View {
    let store: AppStore?
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("설정…") {
            guard let store, !Platform.isShowingSheet else { return }
            store.go(to: .settings, isShowingSheet: false)
            openWindow(id: "main")
        }
        .keyboardShortcut(",")
        .disabled(store == nil)
    }
}
#endif
