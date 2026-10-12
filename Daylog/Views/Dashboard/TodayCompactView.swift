import SwiftUI

/// 좁은 화면(iPhone, 좁은 iPad 창)의 오늘 화면: 진행률 → 다음 루틴 → 체크 목록 → 식사 요약.
/// 넓은 화면과 같은 카드 순서·표시 설정을 한 열로 보여 준다.
struct TodayCompactView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                header
                DateNavigator()
                    .frame(maxWidth: .infinity)
                if !store.stats.hasStarted {
                    StartHint()
                }
                DashboardCards(compact: true, wide: false)
            }
            .padding(Theme.compactPagePadding)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        HStack(spacing: 10) {
            BrandIcon(size: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Daylog")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(store.isViewingToday ? "오늘도 좋은 하루예요" : "\(store.selectedDay.shortTitle)의 기록")
                    .font(.title3.weight(.bold))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
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
        let detail = Self.detail(outcome, isToday: store.isViewingToday, hasStarted: hasStarted)
        Card(fillsHeight: false) {
            HStack(spacing: 18) {
                ZStack {
                    ProgressRing(ratio: outcome.ratio, lineWidth: 10)
                    if outcome.status == .vacation {
                        Image(systemName: "sun.max").foregroundStyle(Theme.accent)
                    } else if outcome.total > 0 {
                        Text("\(outcome.done)/\(outcome.total)")
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                    } else {
                        Image(systemName: hasStarted ? "cup.and.saucer" : "plus")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 92, height: 92)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.isViewingToday ? "오늘의 진행률" : "\(store.selectedDay.shortTitle)의 진행률")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(headline)
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(store.isViewingToday ? "오늘" : store.selectedDay.shortTitle)의 진행률, \(headline). \(detail)")
    }

    static func headline(_ outcome: DayOutcome, hasStarted: Bool) -> String {
        if outcome.status == .vacation { return "휴가" }
        guard outcome.total > 0 else { return hasStarted ? "휴식" : "시작 전" }
        return outcome.percentLabel
    }

    /// 쉬는 날(예정된 루틴 없음)과 미기록(예정은 있었는데 체크 없음)을 다르게 말한다.
    static func detail(_ outcome: DayOutcome, isToday: Bool, hasStarted: Bool) -> String {
        if outcome.status == .vacation { return "루틴 통계와 알림은 쉬어 가요. 기존 기록은 보관돼요." }
        if outcome.total == 0 {
            if !hasStarted {
                return isToday ? "루틴을 추가하면 여기에 진행률이 보여요." : "루틴을 시작하기 전의 날이에요."
            }
            return isToday ? "오늘은 예정된 루틴이 없어요." : "예정된 루틴이 없던 날이에요."
        }
        if outcome.done == outcome.total { return "\(outcome.total)개를 모두 완료했어요." }
        if outcome.done == 0 {
            return isToday ? "\(outcome.total)개가 기다리고 있어요." : "미기록 · 체크한 항목이 없어요."
        }
        return "\(outcome.total)개 중 \(outcome.done)개 완료, \(outcome.total - outcome.done)개 남았어요."
    }
}

/// 시간이 정해진 루틴 가운데 다음 차례. 없으면 아무것도 그리지 않는다. 표시만 하고 알림은 없다.
struct NextRoutineCard: View {
    @Environment(AppStore.self) private var store

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
                    .lineLimit(1)
                Text("\(TimeLabel.label(minutes: next.minutes)) · \(next.group.title)")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Theme.cardBorder, lineWidth: 1)
        )
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
                VStack(spacing: 8) {
                    ForEach(MealKind.allCases) { kind in
                        row(kind)
                    }
                }
            }
        }
    }

    private func row(_ kind: MealKind) -> some View {
        let text = store.text(kind.field.keyPath).trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label {
                Text(kind.title).font(.callout.weight(.semibold))
            } icon: {
                Image(systemName: kind.symbol).foregroundStyle(kind.tint)
            }
            .frame(width: 70, alignment: .leading)
            Text(text.isEmpty ? "아직 안 적었어요" : text)
                .font(.callout)
                .foregroundStyle(text.isEmpty ? .tertiary : .primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.title), \(text.isEmpty ? "기록 없음" : text)")
    }
}
