import SwiftUI

struct DevicePreferenceSections: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showsOnboarding = false

    var body: some View {
        Section {
            Toggle("식사 기록 표시", isOn: Binding(
                get: { preferences.mealsEnabled },
                set: { store.setMealsEnabled($0, preferences: preferences) }
            ))
        } header: {
            Text("기록 화면")
        } footer: {
            Text("이 기기에만 적용돼요. 끄면 식사 메뉴와 카드가 숨겨지며, 입력한 내용과 기존 기록은 보관돼요. 다시 켜면 그대로 볼 수 있어요.")
        }

        Section {
            ForEach(Array(preferences.cardOrder.enumerated()), id: \.element) { index, card in
                HStack(spacing: 4) {
                    if card == .routines {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.title)
                            Text("항상 표시").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                    } else {
                        Toggle(card.title, isOn: Binding(
                            get: { !preferences.hiddenCards.contains(card) },
                            set: { preferences.setVisible($0, card: card) }
                        ))
                        .toggleStyle(.checkboxOnMac)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if horizontalSizeClass != .compact, !card.spansFullWidth {
                        columnPicker(card)
                    }
                    reorderButton(card, offset: -1, disabled: index == 0)
                    reorderButton(card, offset: 1, disabled: index == preferences.cardOrder.count - 1)
                }
            }
            Button("기본 배치 복원") { preferences.restoreDashboard() }
        } header: {
            Text("오늘 화면 구성")
        } footer: {
            Text(horizontalSizeClass == .compact
                 ? "위에서 아래 순서로 표시돼요. 식사 표시가 꺼져 있으면 식사 카드도 숨겨지지만 카드 선택은 유지돼요."
                 : "넓은 창에서는 두 열로, 좁은 창에서는 이 순서대로 한 열로 보여요. 오늘 화면의 편집 단추로 카드를 끌어 옮길 수도 있어요. 식사 표시가 꺼져 있으면 식사 카드도 숨겨지지만 카드 선택은 유지돼요.")
        }

        Section {
            Button("시작 안내 다시 보기") { showsOnboarding = true }
        } header: {
            Text("사용 안내")
        }
        .sheet(isPresented: $showsOnboarding) { OnboardingView() }
    }

    /// 넓은 창의 두 열 중 어디에 둘지.
    private func columnPicker(_ card: DashboardCard) -> some View {
        Picker("열", selection: Binding(
            get: { preferences.column(of: card) },
            set: { preferences.setColumn($0, for: card) }
        )) {
            ForEach(DashboardColumn.allCases, id: \.self) { column in
                Text(column.title).tag(column)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .accessibilityLabel("\(card.title) 카드의 열")
    }

    private func reorderButton(_ card: DashboardCard, offset: Int, disabled: Bool) -> some View {
        Button { preferences.move(card, by: offset) } label: {
            Image(systemName: offset < 0 ? "arrow.up" : "arrow.down")
                .font(.callout)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(disabled)
        .accessibilityLabel("\(card.title) \(offset < 0 ? "위로" : "아래로") 이동")
    }
}

/// Keep native toggles on iOS and a compact checkbox beside ordering controls on macOS.
private struct DeviceCardToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        #if os(macOS)
        Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.checkbox)
        #else
        Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.switch)
        #endif
    }
}

private extension ToggleStyle where Self == DeviceCardToggleStyle {
    static var checkboxOnMac: DeviceCardToggleStyle { DeviceCardToggleStyle() }
}
