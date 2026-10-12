import SwiftUI

/// 보고 있는 날짜의 휴가 카드. 등록된 휴가에 따라 세 가지 모습이 된다.
/// - 휴가 없음: "휴가 설정"과 기간 추가.
/// - 예정된 휴가: 다음 휴가의 날짜·기간과 D-day.
/// - 그날이 휴가: "휴가 중"을 강조하고 기간과 남은 날만 보여 준다(통계 제외 안내는 루틴 카드에 한 줄).
/// 어느 상태에서든 기간을 눌러 고치거나 해제하고, 휴가 관리로 갈 수 있다.
struct VacationDayCard: View {
    @Environment(AppStore.self) private var store
    let day: Day
    @State private var editing: VacationEditorTarget?
    @State private var managing = false

    private var tint: Color { Theme.vacationTint }

    var body: some View {
        let status = VacationStatus.resolve(periods: store.vacationPeriods, on: day, today: store.today)
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            switch status {
            case .none:
                header(symbol: "sun.max", title: "휴가 설정", badge: nil) {
                    HeaderLink(title: "기간 추가") { editing = VacationEditorTarget(day: day) }
                }
            case .upcoming(let period, let daysUntil):
                header(symbol: "sun.max", title: "다음 휴가", badge: VacationStatus.dDayLabel(daysUntil)) {
                    HeaderLink(title: "휴가 관리") { managing = true }
                }
                periodRow(period, action: "수정")
            case .active(let periods, let start, let end, let remainingDays):
                header(
                    symbol: "sun.max.fill",
                    title: day == store.today ? "휴가 중" : "\(day.shortTitle) 휴가",
                    badge: day == store.today ? VacationStatus.remainingLabel(remainingDays) : nil
                ) {
                    HeaderLink(title: "휴가 관리") { managing = true }
                }
                // 겹치거나 이어진 기간이 여럿이면 이어진 전체 구간을 먼저 알려 준다.
                if periods.count > 1 || periods.first.map({ $0.start != start || $0.end != end }) == true {
                    Text("\(VacationStatus.rangeTitle(start: start, end: end)) · \(start.days(until: end) + 1)일 동안 이어져요")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                ForEach(periods) { period in
                    periodRow(period, action: "수정·해제")
                }
                // 이 휴가가 끝난 뒤의 다음 휴가도 한 줄로 알려 준다.
                if let next = VacationStatus.nextPeriod(periods: store.vacationPeriods, after: max(end, store.today)) {
                    Button {
                        editing = VacationEditorTarget(day: next.start, period: next)
                    } label: {
                        Label(
                            "다음 휴가 · \(VacationPeriodLabel.rangeTitle(next)) · \(VacationStatus.dDayLabel(store.today.days(until: next.start)))",
                            systemImage: "calendar"
                        )
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("누르면 그 기간을 고칩니다.")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.cardBackground, in: shape)
        // 휴가인 날은 카드 전체를 옅은 휴가 색으로 덮어 한눈에 알아보게 한다.
        .background(status.isActive ? tint.opacity(0.10) : .clear, in: shape)
        .overlay(shape.strokeBorder(status.isActive ? tint.opacity(0.45) : Theme.cardBorder, lineWidth: 1))
        .sheet(item: $editing) { VacationEditorSheet(target: $0) }
        .sheet(isPresented: $managing) { VacationManagementView() }
        .accessibilityElement(children: .contain)
    }

    private func header<Trailing: View>(
        symbol: String, title: String, badge: String?, @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            if let badge {
                Text(badge)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(GroupColor.blue.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tint.opacity(0.18), in: Capsule())
            }
            Spacer(minLength: 8)
            trailing()
        }
    }

    private func periodRow(_ period: VacationPeriod, action: String) -> some View {
        Button {
            editing = VacationEditorTarget(day: period.start, period: period)
        } label: {
            HStack(spacing: 8) {
                VacationPeriodLabel(period: period, showsIcon: false)
                Spacer(minLength: 8)
                Text(action)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("누르면 기간을 고치거나 해제합니다.")
    }
}

private extension VacationStatus {
    var isActive: Bool {
        if case .active = self { return true }
        return false
    }
}
