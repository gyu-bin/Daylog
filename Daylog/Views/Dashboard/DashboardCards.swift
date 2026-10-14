import SwiftUI

/// 대시보드의 카드들. 넓으면 두 열, 좁으면 한 열로 같은 순서를 보여 준다.
/// 편집 모드에서는 카드를 끌어 옮기고, 메뉴로도 옮기고, 숨길 수 있다(macOS·iPad). iPhone은 설정 화면에서 바꾼다.
struct DashboardCards: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    @Environment(DashboardDecor.self) private var decor
    let compact: Bool
    let wide: Bool
    var isEditing = false
    /// 편집 중인 꾸미기 카드.
    @State private var editorTarget: CustomCardEditorTarget?
    /// 카드 사이 간격 같은 표시 값(iPhone·iPad에서는 원격 UI 설정을 따른다).
    @Environment(\.mobileUI) private var ui

    private var vacationStatus: VacationStatus {
        VacationStatus.resolve(periods: store.vacationPeriods, on: store.selectedDay, today: store.today)
    }

    /// 편집 중에는 보이지 않는 조건의 카드(다음 루틴, 휴가)도 자리를 보여 준다. 평소에는 보여 줄 것이 있을 때만 그린다.
    /// 휴가는 휴가 중이거나 시작이 며칠 안으로 다가왔을 때만 나온다.
    private var cards: [DashboardCard] {
        preferences.visibleCards.filter { card in
            // 내용이 없는 꾸미기 카드(다른 기기에서 지운 텍스트 카드 등)는 그리지 않는다.
            guard decor.isAvailable(card, texts: store.dashboardTexts) else { return false }
            if isEditing { return true }
            switch card {
            case .nextRoutine:
                // 휴가인 날은 보여 주기로 한 루틴만 목록에 있다(전체 휴식이면 비어 있다).
                return store.isViewingToday
                    && NextCheck.pick(from: store.checkSections, nowMinutes: 0) != nil
            case .vacation:
                // iPhone에서는 여느 카드처럼 늘 보이고(기본 위치는 아래쪽), 넓은 화면에서는 휴가 중이거나 임박했을 때만.
                return compact || vacationStatus.showsOnDashboard
            default:
                return true
            }
        }
    }

    var body: some View {
        // 넓은 화면에서 휴가 중이면 카드 자리 대신 맨 위에 얇은 띠로 올린다(오늘 달성률이 왜 비는지 먼저 보이게).
        let hoistsVacation = wide && !isEditing && vacationStatus.isActive && self.cards.contains(.vacation)
        let cards = hoistsVacation ? self.cards.filter { $0 != .vacation } : self.cards
        Group {
            layout(cards, hoistsVacation: hoistsVacation)
        }
        .sheet(item: $editorTarget) { CustomCardEditorSheet(target: $0) }
    }

    @ViewBuilder
    private func layout(_ cards: [DashboardCard], hoistsVacation: Bool) -> some View {
        if wide {
            let layout = preferences.layout(of: cards)
            VStack(alignment: .leading, spacing: ui.cardSpacing) {
                if hoistsVacation {
                    VacationBanner(day: store.selectedDay)
                }
                ForEach(layout.band) { card in
                    slot(card, column: nil, siblings: layout.band)
                }
                HStack(alignment: .top, spacing: ui.cardSpacing) {
                    column(.left, layout)
                    column(.right, layout)
                }
            }
        } else {
            let column = cards.filter { !$0.spansFullWidth }
            VStack(alignment: .leading, spacing: ui.cardSpacing) {
                ForEach(cards) { card in
                    // 한 열뿐인 iPhone에서는 "다른 열로 이동"을 보여 주지 않는다.
                    slot(card, column: compact ? nil : preferences.column(of: card), siblings: card.spansFullWidth ? [card] : column)
                }
                if isEditing {
                    DropTail(column: preferences.column(of: column.last ?? .routines))
                }
            }
        }
    }

    private func column(_ side: DashboardColumn, _ layout: DashboardLayout) -> some View {
        let cards = layout.cards(in: side)
        return VStack(alignment: .leading, spacing: ui.cardSpacing) {
            ForEach(cards) { card in
                slot(card, column: side, siblings: cards)
            }
            if isEditing {
                DropTail(column: side)
            } else if cards.isEmpty {
                // 비어 있는 열도 자리를 차지해야 다른 열이 전체 너비로 늘어나지 않는다.
                Color.clear.frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func slot(_ card: DashboardCard, column: DashboardColumn?, siblings: [DashboardCard]) -> some View {
        if isEditing {
            EditableCard(
                card: card, column: column, siblings: siblings,
                onEdit: card.isCustom ? { editorTarget = .edit(card) } : nil
            ) {
                content(card)
            }
        } else if card.isCustom {
            content(card)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .contextMenu {
                    Button("편집…") { editorTarget = .edit(card) }
                }
        } else {
            content(card)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func content(_ card: DashboardCard) -> some View {
        switch card {
        case .summary:
            if compact { StatCardsGrid(columns: 2, compact: true) } else { StatCardsGrid(columns: wide ? 4 : 2) }
        case .nextRoutine:
            if isEditing, !(store.isViewingToday && NextCheck.pick(from: store.checkSections, nowMinutes: 0) != nil) {
                EditingPlaceholder(card: card, note: "시간이 정해진 남은 루틴이 있을 때만 보여요.")
            } else {
                NextRoutineCard()
            }
        case .vacation:
            if compact {
                VacationDayCard(day: store.selectedDay)
            } else if vacationStatus.isActive {
                VacationBanner(day: store.selectedDay)
            } else if isEditing, !vacationStatus.showsOnDashboard {
                EditingPlaceholder(card: card, note: "휴가 중이거나 휴가가 \(VacationStatus.soonDays)일 안으로 다가왔을 때만 보여요.")
            } else {
                VacationDayCard(day: store.selectedDay)
            }
        case .routines:
            RoutineCard()
                // [오늘 루틴 보기]가 여기로 스크롤하고 잠깐 강조한다.
                .modifier(RoutineCardFocus())
                .id(RoutineCardFocus.scrollID)
        case .weeklyGrowth: WeeklyGrowthCard()
        case .saessagiGrowth: SaessagiGrowthCard()
        case .meals:
            if compact { MealSummaryCard() } else { MealCard() }
        case .achievement:
            if compact { TodayProgressCard() } else { AchievementCard() }
        case .recentDays: WeekOverviewCard()
        case .tomorrow: TomorrowTaskCard()
        case .calendar: MonthCalendarCard()
        case .trend: TrendChartCard()
        case .routineRates: RoutineRatesCard()
        case .custom(let kind, let id):
            CustomCardView(kind: kind, id: id, compact: compact) { editorTarget = .edit(card) }
        }
    }
}

/// 편집 모드에서 조건부로만 보이는 카드의 자리.
private struct EditingPlaceholder: View {
    let card: DashboardCard
    let note: String

    var body: some View {
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.title).font(.headline)
                Text(note).font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}
