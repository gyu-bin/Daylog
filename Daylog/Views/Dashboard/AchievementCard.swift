import SwiftUI

/// 보고 있는 날짜의 달성 현황: 전체 달성률 고리와 그룹별 완료/전체.
struct AchievementCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let outcome = store.selectedOutcome
        let sections = store.checkSections
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 14) {
                CardHeader(
                    symbol: "target",
                    title: store.isViewingToday ? "오늘의 달성 현황" : "\(store.selectedDay.shortTitle)의 달성 현황"
                )

                if store.isVacation(on: store.selectedDay) {
                    // 달성률은 0%가 아니라 휴가로 보여 준다. 이어 가는 루틴이 있으면 개수만 함께 알린다.
                    vacation(done: outcome.done, total: outcome.total)
                } else if sections.isEmpty {
                    EmptyHint(
                        symbol: "target",
                        message: store.isViewingToday ? "오늘은 예정된 루틴이 없어요." : "이 날짜에는 예정된 루틴이 없었어요."
                    )
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .center, spacing: 22) {
                            ring(outcome)
                            groups(sections)
                        }
                        VStack(alignment: .leading, spacing: 14) {
                            ring(outcome)
                            groups(sections)
                        }
                    }
                }
            }
        }
    }

    private func vacation(done: Int, total: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "beach.umbrella.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.vacationTint)
                .frame(width: 44, height: 44)
                .background(Theme.vacationTint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("휴가")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(GroupColor.coral.ink)
                Text(Self.vacationDetail(done: done, total: total))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// 휴가인 날의 설명. 이어 가는 루틴이 있으면 그 개수도 알린다(달성률 통계에는 들어가지 않는다).
    static func vacationDetail(done: Int, total: Int) -> String {
        total > 0
            ? "달성률 통계에서 제외돼요 · 유지 루틴 \(total)개 중 \(done)개 완료"
            : "달성률 통계에서 제외돼요. 기존 기록은 보관돼요."
    }

    private func ring(_ outcome: DayOutcome) -> some View {
        ZStack {
            ProgressRing(ratio: outcome.ratio ?? 0, lineWidth: 11)
            VStack(spacing: 2) {
                Text(outcome.percentLabel)
                    .font(.system(size: 26, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("\(outcome.done) / \(outcome.total) 완료")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
        }
        .frame(width: 132, height: 132)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("전체 달성률 \(outcome.percentLabel), \(outcome.total)개 중 \(outcome.done)개 완료")
    }

    private func groups(_ sections: [CheckSection]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sections) { section in
                let color = GroupColor(key: section.group.colorKey)
                HStack(spacing: 10) {
                    Circle()
                        .fill(color.color)
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)
                    Text(section.group.title)
                        .font(.callout)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("\(section.done)/\(section.total)")
                        .font(.callout.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(section.done == section.total ? AnyShapeStyle(color.ink) : AnyShapeStyle(.secondary))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(section.group.title) 그룹, \(section.total)개 중 \(section.done)개 완료")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
