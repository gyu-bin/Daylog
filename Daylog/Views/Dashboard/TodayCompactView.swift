import SwiftUI

/// 좁은 화면(iPhone, 좁은 iPad 창)의 오늘 화면: 진행률 → 다음 루틴 → 체크 목록 → 식사 요약.
/// 넓은 화면과 같은 카드 순서·표시 설정을 한 열로 보여 준다.
struct TodayCompactView: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    /// 대시보드 편집 중: 카드를 끌어 옮기고 숨긴다. 그동안 카드 안의 체크·입력은 눌리지 않는다.
    @State private var isEditing = false
    @Environment(\.mobileUI) private var ui
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 휴가 중에 평소 화면을 보고 있을 때: 휴식 화면으로 돌아가는 동작.
    var onShowVacationRest: (() -> Void)?

    var body: some View {
        ScrollViewReader { scroll in
        ScrollView {
            VStack(alignment: .leading, spacing: min(ui.cardSpacing, 12)) {
                VStack(alignment: .leading, spacing: min(ui.cardSpacing, 6)) {
                header
                    // 사진이 있으면 머리말 뒤에 낮게 깐다. 머리말 높이만큼만 차지해 첫 카드가 거의 밀리지 않는다.
                    .dashboardHeaderBackdrop(padding: 12)
                if let onShowVacationRest {
                    VacationRestReturnBar(action: onShowVacationRest)
                }
                if isEditing {
                    DashboardEditBar(isEditing: $isEditing)
                } else if !store.stats.hasStarted {
                    StartHint()
                } else if let prompt = store.restartPrompt(dismissedDay: preferences.restartDismissedDay) {
                    RestartCard(prompt: prompt)
                }
                }
                DashboardCards(compact: true, wide: false, isEditing: isEditing)
            }
            .padding(.horizontal, Theme.compactPagePadding)
            .padding(.top, 4)
            .padding(.bottom, Theme.compactPagePadding)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: preferences.cardOrder)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: preferences.hiddenCards)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: store.section) { _, _ in isEditing = false }
        .onChange(of: store.routineCardFocusToken) { _, _ in
            RoutineCardFocus.scroll(scroll, reduceMotion: reduceMotion)
        }
        }
    }

    /// A compact brand/companion row followed by the date and its controls.
    /// Large type moves controls to their own row rather than squeezing text.
    @ViewBuilder private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                brandTitle
                HStack(alignment: .center, spacing: 12) {
                    greeting(showsIcon: false).frame(maxWidth: .infinity, alignment: .leading)
                    PioHeaderCompanion(size: 64)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        DateNavigator(showsDate: false, minimumTouchTarget: 44)
                        Spacer(minLength: 4)
                        headerActions
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        DateNavigator(showsDate: false, minimumTouchTarget: 44)
                        headerActions
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ViewThatFits(in: .horizontal) {
                    topRow(pioSize: 64)
                    topRow(pioSize: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        brandTitle
                        HStack {
                            PioHeaderCompanion(size: 52)
                            Spacer(minLength: 8)
                            headerActions
                        }
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 8) {
                        greeting(showsIcon: false).fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 4)
                        DateNavigator(showsDate: false, minimumTouchTarget: 44)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        greeting(showsIcon: true)
                        DateNavigator(showsDate: false, minimumTouchTarget: 44)
                    }
                }
            }
        }
    }

    private var brandTitle: some View {
        Text(verbatim: AppBrand.name)
            .font(.title2.weight(.bold))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("dashboard.brand")
    }

    private func topRow(pioSize: CGFloat?) -> some View {
        HStack(spacing: 8) {
            brandTitle.fixedSize(horizontal: true, vertical: false)
            if store.isVacation(on: store.today) {
                Label("휴가 중", systemImage: "beach.umbrella.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GroupColor.coral.ink)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.vacationTint.opacity(0.16), in: Capsule())
            }
            if let pioSize {
                PioHeaderCompanion(size: pioSize)
                    .frame(minWidth: pioSize, maxWidth: .infinity, alignment: .center)
                    .layoutPriority(-1)
            } else { Spacer(minLength: 4) }
            headerActions
        }
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            Button {
                isEditing.toggle()
            } label: {
                Image(systemName: isEditing ? "checkmark" : "square.grid.2x2")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isEditing ? AnyShapeStyle(Theme.onAccent) : AnyShapeStyle(.primary))
                    .frame(width: 38, height: 36)
                    .background(
                        isEditing ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.cardBackground),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: isEditing ? 0 : 1))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isEditing ? "대시보드 편집 완료" : "대시보드 편집")
            .accessibilityHint("카드의 순서를 바꾸거나 숨깁니다.")
            Button {
                isEditing = false
                store.requestQuickAddFocus(
                    dashboardShowsRoutines: !preferences.hiddenCards.contains(.routines),
                    isShowingSheet: Platform.isShowingSheet
                )
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 36)
                    .background(GroupColor.blue.color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("루틴 추가")
            .accessibilityHint("오늘의 루틴에 새 항목을 적습니다.")
        }
    }

    /// 날짜와 인사말(지난 날짜를 볼 때는 "…의 기록").
    private func greeting(showsIcon: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(store.selectedDay.longTitle)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text(verbatim: store.isViewingToday ? ui.string(.dashboardGreeting) : "\(store.selectedDay.shortTitle)의 기록")
                    .font(.title3.weight(.bold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .minimumScaleFactor(0.8)
                if showsIcon, store.isViewingToday, ui.showsGreetingIcon {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(GroupColor.yellow.color)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// 보고 있는 날짜의 진행률 고리. 쉬는 날·아직 체크하지 않은 날·다 한 날을 글자로도 구분한다.
struct TodayProgressCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let outcome = store.selectedOutcome
        // 첫 루틴을 만들기 전의 날짜는 쉬는 날이 아니라 "시작 전"이다.
        let hasStarted = store.hasRoutines && (store.stats.firstDay.map { store.selectedDay >= $0 } ?? true)
        let headline = Self.headline(outcome, hasStarted: hasStarted)
        let detail = Self.detail(
            outcome, isToday: store.isViewingToday, hasStarted: hasStarted,
            skipped: store.checkSections.reduce(0) { $0 + $1.skipped }
        )
        Button {
            store.section = .statistics
        } label: {
            Card(fillsHeight: false, padding: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        ProgressRing(ratio: outcome.ratio, lineWidth: 8)
                        if outcome.status == .vacation {
                            Image(systemName: "beach.umbrella.fill").foregroundStyle(Theme.vacationTint)
                        } else if outcome.total > 0 {
                            Text(outcome.percentLabel)
                                .font(.system(size: 17, weight: .bold))
                                .monospacedDigit()
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                        } else {
                            Image(systemName: hasStarted ? "cup.and.saucer" : "plus")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 68, height: 68)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(outcome.total > 0 && outcome.status != .vacation ? "\(outcome.done) / \(outcome.total) 완료" : headline)
                            .font(.headline)
                            .monospacedDigit()
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("통계를 엽니다.")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(store.isViewingToday ? "오늘" : store.selectedDay.shortTitle)의 진행률, \(headline). \(detail)")
    }

    static func headline(_ outcome: DayOutcome, hasStarted: Bool) -> String {
        if outcome.status == .vacation { return "휴가" }
        guard outcome.total > 0 else { return hasStarted ? "휴식" : "시작 전" }
        return outcome.percentLabel
    }

    /// 쉬는 날(예정된 루틴 없음)과 미기록(예정은 있었는데 체크 없음)을 다르게 말한다.
    /// - Parameter skipped: 그날 건너뛴 항목 수. 남은 개수에서 빼고 따로 적는다(달성률은 그대로다).
    static func detail(_ outcome: DayOutcome, isToday: Bool, hasStarted: Bool, skipped: Int = 0) -> String {
        if outcome.status == .vacation {
            return outcome.total > 0
                ? "유지 루틴 \(outcome.total)개 중 \(outcome.done)개 완료 · 달성률 통계는 쉬어요."
                : "루틴 통계와 알림은 쉬어 가요. 기존 기록은 보관돼요."
        }
        if outcome.total == 0 {
            if !hasStarted {
                return isToday ? "루틴을 추가하면 여기에 진행률이 보여요." : "루틴을 시작하기 전의 날이에요."
            }
            return isToday ? "오늘은 예정된 루틴이 없어요." : "예정된 루틴이 없던 날이에요."
        }
        if outcome.done == outcome.total { return "\(outcome.total)개를 모두 완료했어요." }
        if skipped > 0 {
            let remaining = max(outcome.total - outcome.done - skipped, 0)
            return remaining == 0
                ? "\(outcome.total)개 중 \(outcome.done)개 완료, \(skipped)개는 건너뛰었어요."
                : "\(outcome.total)개 중 \(outcome.done)개 완료, \(remaining)개 남았어요 · 건너뜀 \(skipped)"
        }
        if outcome.done == 0 {
            return isToday ? "\(outcome.total)개가 기다리고 있어요." : "미기록 · 체크한 항목이 없어요."
        }
        return "\(outcome.total)개 중 \(outcome.done)개 완료, \(outcome.total - outcome.done)개 남았어요."
    }
}

/// 시간이 정해진 루틴 가운데 다음 차례. 없으면 아무것도 그리지 않는다. 표시만 하고 알림은 없다.
struct NextRoutineCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // 분이 바뀔 때마다 다시 고른다.
        TimelineView(.everyMinute) { timeline in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: timeline.date)
            if let next = NextCheck.pick(
                from: store.checkSections, nowMinutes: (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            ) {
                card(next)
            }
        }
    }

    private func card(_ next: NextCheck) -> some View {
        let color = GroupColor(key: next.group.colorKey)
        return HStack(spacing: 12) {
            Image(systemName: next.isOverdue ? "clock.badge.exclamationmark" : "clock")
                .font(.title3)
                .foregroundStyle(color.ink)
                .frame(width: 40, height: 40)
                .background(color.wash, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(next.isOverdue ? "아직 안 한 루틴" : "다음 루틴")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(next.check.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                Text("\(TimeLabel.label(minutes: next.minutes)) · \(next.group.title)")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }
            Spacer(minLength: 8)
            Button("완료") {
                store.setDone(routineID: next.check.id, true)
            }
            .buttonStyle(.borderedProminent)
            .tint(color.color)
            .foregroundStyle(Theme.onAccent)
            .accessibilityLabel("\(next.check.title) 완료로 표시")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardChrome(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

/// 보고 있는 날짜의 식사를 한 줄씩. 적는 일은 식사 탭에서 한다.
struct MealSummaryCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(
                    symbol: "fork.knife",
                    title: store.isViewingToday ? "오늘의 식사" : "\(store.selectedDay.shortTitle)의 식사",
                    tint: Theme.mealTint
                ) {
                    HeaderLink(title: "식사 적기") {
                        store.section = .meals
                    }
                }
                HStack(alignment: .top, spacing: 6) {
                    ForEach(MealKind.allCases) { kind in
                        row(kind)
                    }
                }
            }
        }
    }

    /// 식사 한 칸: 이름과 적은 내용(없으면 줄표). 누르면 식사 탭에서 적는다.
    private func row(_ kind: MealKind) -> some View {
        let text = store.text(kind.field.keyPath).trimmingCharacters(in: .whitespacesAndNewlines)
        return Button {
            store.section = .meals
        } label: {
            VStack(spacing: 4) {
                Text(kind.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(kind.tint)
                Text(text.isEmpty ? "–" : text)
                    .font(.caption)
                    .foregroundStyle(text.isEmpty ? .tertiary : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.title), \(text.isEmpty ? "기록 없음" : text)")
        .accessibilityHint("식사 탭에서 적습니다.")
    }
}
