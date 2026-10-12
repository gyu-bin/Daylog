import SwiftUI

/// 시작 안내를 다시 여는 단추(앱 정보 섹션).
struct OnboardingReplayButton: View {
    @State private var showsOnboarding = false

    var body: some View {
        Button("시작 안내 다시 보기") { showsOnboarding = true }
            .sheet(isPresented: $showsOnboarding) { OnboardingView() }
    }
}

struct DevicePreferenceSections: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    @Environment(DashboardDecor.self) private var decor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showsCards = false

    /// 목록에 보여 줄 카드. 내용이 사라진 꾸미기 카드(다른 기기에서 지운 텍스트 카드 등)는 뺀다.
    private var listedCards: [DashboardCard] {
        preferences.cardOrder.filter { decor.isAvailable($0, texts: store.dashboardTexts) }
    }

    var body: some View {
        Section {
            Toggle("식사 기록 표시", isOn: Binding(
                get: { preferences.mealsEnabled },
                set: { store.setMealsEnabled($0, preferences: preferences) }
            ))
            if horizontalSizeClass == .compact {
                // iPhone과 좁은 창: 오늘 화면에 편집 모드가 없어서 여기서 순서와 표시를 바꾼다. 평소에는 접어 둔다.
                DisclosureGroup("카드 순서와 표시", isExpanded: $showsCards) {
                    cardRows
                    Button("기본 배치 복원") { preferences.restoreDashboard() }
                }
            } else {
                // 넓은 창: 순서·열·숨김은 오늘 화면의 편집 모드에서 직접 끌어서 바꾼다. 여기서는 그리로 보낸다.
                LabeledContent {
                    Button("편집") {
                        store.wantsDashboardEditing = true
                        store.section = .dashboard
                    }
                    .accessibilityLabel("대시보드 구성 편집")
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("대시보드 구성")
                        Text(Self.layoutSummary(visible: preferences.visibleCards.count, hidden: preferences.hiddenChoices.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("오늘 화면")
        } footer: {
            Text("\(Platform.thisDevice)에만 적용돼요. 식사 표시를 꺼도 적어 둔 내용은 보관돼요.")
        }
    }

    /// "카드 6개 표시 · 4개 숨김".
    static func layoutSummary(visible: Int, hidden: Int) -> String {
        hidden == 0 ? "카드 \(visible)개 표시" : "카드 \(visible)개 표시 · \(hidden)개 숨김"
    }

    @ViewBuilder
    private var cardRows: some View {
        ForEach(Array(listedCards.enumerated()), id: \.element) { index, card in
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
                reorderButton(card, offset: -1, disabled: index == 0)
                reorderButton(card, offset: 1, disabled: index == preferences.cardOrder.count - 1)
            }
        }
    }

    #if os(macOS)
    private static let reorderButtonSize: CGFloat = 28
    #else
    private static let reorderButtonSize: CGFloat = 44
    #endif

    private func reorderButton(_ card: DashboardCard, offset: Int, disabled: Bool) -> some View {
        Button { preferences.move(card, by: offset) } label: {
            Image(systemName: offset < 0 ? "arrow.up" : "arrow.down")
                .font(.callout)
                // 터치 화면은 44pt, 마우스는 줄이 길어지지 않게 28pt.
                .frame(width: Self.reorderButtonSize, height: Self.reorderButtonSize)
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
