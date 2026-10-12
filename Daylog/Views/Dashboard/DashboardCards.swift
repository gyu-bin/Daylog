import SwiftUI
import UniformTypeIdentifiers

/// 대시보드의 카드들. 넓으면 두 열, 좁으면 한 열로 같은 순서를 보여 준다.
/// 편집 모드에서는 카드를 끌어 옮기고, 메뉴로도 옮기고, 숨길 수 있다(macOS·iPad). iPhone은 설정 화면에서 바꾼다.
struct DashboardCards: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    let compact: Bool
    let wide: Bool
    var isEditing = false

    private var vacationStatus: VacationStatus {
        VacationStatus.resolve(periods: store.vacationPeriods, on: store.selectedDay, today: store.today)
    }

    /// 편집 중에는 보이지 않는 조건의 카드(다음 루틴, 휴가)도 자리를 보여 준다. 평소에는 보여 줄 것이 있을 때만 그린다.
    /// 휴가는 휴가 중이거나 시작이 며칠 안으로 다가왔을 때만 나온다.
    private var cards: [DashboardCard] {
        preferences.visibleCards.filter { card in
            if isEditing { return true }
            switch card {
            case .nextRoutine:
                return store.isViewingToday && !store.isVacation(on: store.today)
                    && NextCheck.pick(from: store.checkSections, nowMinutes: 0) != nil
            case .vacation:
                return vacationStatus.showsOnDashboard
            default:
                return true
            }
        }
    }

    var body: some View {
        // 넓은 화면에서 휴가 중이면 카드 자리 대신 맨 위에 얇은 띠로 올린다(오늘 달성률이 왜 비는지 먼저 보이게).
        let hoistsVacation = wide && !isEditing && vacationStatus.isActive && self.cards.contains(.vacation)
        let cards = hoistsVacation ? self.cards.filter { $0 != .vacation } : self.cards
        if wide {
            let layout = preferences.layout(of: cards)
            VStack(alignment: .leading, spacing: Theme.spacing) {
                if hoistsVacation {
                    VacationBanner(day: store.selectedDay)
                }
                ForEach(layout.band) { card in
                    slot(card, column: nil, siblings: layout.band)
                }
                HStack(alignment: .top, spacing: Theme.spacing) {
                    column(.left, layout)
                    column(.right, layout)
                }
            }
        } else {
            let column = cards.filter { !$0.spansFullWidth }
            VStack(alignment: .leading, spacing: Theme.spacing) {
                ForEach(cards) { card in
                    slot(card, column: preferences.column(of: card), siblings: card.spansFullWidth ? [card] : column)
                }
                if isEditing {
                    DropTail(column: preferences.column(of: column.last ?? .routines))
                }
            }
        }
    }

    private func column(_ side: DashboardColumn, _ layout: DashboardLayout) -> some View {
        let cards = layout.cards(in: side)
        return VStack(alignment: .leading, spacing: Theme.spacing) {
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
            EditableCard(card: card, column: column, siblings: siblings) {
                content(card)
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
            if compact { StatCardsGrid(columns: 2) } else { StatCardsGrid(columns: wide ? 4 : 2) }
        case .nextRoutine:
            if isEditing, !(store.isViewingToday && NextCheck.pick(from: store.checkSections, nowMinutes: 0) != nil) {
                EditingPlaceholder(card: card, note: "시간이 정해진 남은 루틴이 있을 때만 보여요.")
            } else {
                NextRoutineCard()
            }
        case .vacation:
            if vacationStatus.isActive {
                VacationBanner(day: store.selectedDay)
            } else if isEditing, !vacationStatus.showsOnDashboard {
                EditingPlaceholder(card: card, note: "휴가 중이거나 휴가가 \(VacationStatus.soonDays)일 안으로 다가왔을 때만 보여요.")
            } else {
                VacationDayCard(day: store.selectedDay)
            }
        case .routines: RoutineCard()
        case .meals:
            if compact { MealSummaryCard() } else { MealCard() }
        case .achievement:
            if compact { TodayProgressCard() } else { AchievementCard() }
        case .recentDays: WeekOverviewCard()
        case .tomorrow: TomorrowTaskCard()
        case .calendar: MonthCalendarCard()
        case .trend: TrendChartCard()
        case .routineRates: RoutineRatesCard()
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
private struct EditableCard<Content: View>: View {
    @Environment(DevicePreferences.self) private var preferences
    let card: DashboardCard
    /// 지금 속한 열. 띠 카드(주요 지표)는 nil.
    let column: DashboardColumn?
    /// 같은 열의 카드들(위/아래 이동의 범위).
    let siblings: [DashboardCard]
    @ViewBuilder let content: () -> Content

    @State private var isTargeted = false

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
                    .frame(width: 28, height: 28)
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
            Menu {
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
                    .frame(width: 28, height: 28)
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
private struct DropTail: View {
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
