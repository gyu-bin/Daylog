import SwiftUI

/// 휴가 메뉴: 지금 상태와, 등록한 휴가를 진행 중·예정·지난 순으로 보여 준다.
/// 기간을 눌러 고치거나 해제하고, 새 기간을 추가한다. 대시보드의 휴가 카드·설정과 같은 기록을 쓴다.
struct VacationView: View {
    @Environment(AppStore.self) private var store
    @State private var editing: VacationEditorTarget?

    var body: some View {
        let periods = store.vacationPeriods.sorted { ($0.start, $0.end) < ($1.start, $1.end) }
        let today = store.today
        let current = periods.filter { $0.contains(today) }
        let upcoming = periods.filter { $0.start > today }
        let past = periods.filter { $0.end < today }.reversed()

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                HStack(alignment: .center, spacing: 12) {
                    PageTitle(title: "휴가", subtitle: "휴가인 날은 통계에서 빠지고, 기록은 그대로 남아요. 이어 갈 루틴은 휴가마다 고를 수 있어요.")
                    Spacer(minLength: 8)
                    Button {
                        editing = VacationEditorTarget(day: today)
                    } label: {
                        Label("휴가 추가", systemImage: "plus")
                            .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.vacationTint)
                    .fixedSize()
                }

                // 오늘 기준의 상태(휴가 중 / 다음 휴가 / 없음). 대시보드와 같은 카드다.
                VacationDayCard(day: today)

                if periods.isEmpty {
                    Card(fillsHeight: false) {
                        EmptyHint(symbol: "beach.umbrella", message: "등록된 휴가가 없어요.\n쉬는 날을 미리 넣어 두면 연속 달성 기록이 끊기지 않아요.", tint: Theme.vacationTint)
                    }
                }
                group("진행 중", Array(current))
                group("예정", Array(upcoming))
                group("지난 휴가", Array(past))
            }
            .pagePadding()
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .sheet(item: $editing) { VacationEditorSheet(target: $0) }
    }

    @ViewBuilder
    private func group(_ title: String, _ periods: [VacationPeriod]) -> some View {
        if !periods.isEmpty {
            Card(fillsHeight: false, padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(title) \(periods.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(periods) { period in
                        Button {
                            editing = VacationEditorTarget(day: period.start, period: period)
                        } label: {
                            HStack(spacing: 10) {
                                VacationPeriodLabel(period: period)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Theme.inset, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("누르면 고치거나 해제합니다.")
                    }
                }
            }
        }
    }
}
