import SwiftUI

/// 이번 주의 성장: 이번 주에 실천한 날 수와 주간 목표. 새싹이가 옆에서 응원한다.
/// 보고 있는 날짜와 상관없이 실제 이번 주를 보여 준다. 값은 `WeeklyGrowthCalculator`가 통계의 날짜별 결과에서 센다.
struct WeeklyGrowthCard: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences

    var body: some View {
        let growth = store.weeklyGrowth(weekStart: preferences.weekStart, chosenGoal: preferences.weeklyGoal)
        Card(fillsHeight: false) {
            VStack(alignment: .leading, spacing: 8) {
                CardHeader(symbol: "leaf.fill", title: "이번 주의 성장", tint: Theme.accent) {
                    goalMenu(growth)
                }
                HStack(alignment: .center, spacing: 12) {
                    SaessagiView(pose: .cheer, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        // 글자가 커서 한 줄에 다 들어가지 않으면 칸을 아랫줄로 내린다.
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: 10) {
                                count(growth)
                                dots(growth)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                count(growth)
                                dots(growth)
                            }
                        }
                        Text(growth.headline)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(growth.isGoalReached ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.primary))
                        Text(growth.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(growth.accessibilityLabel)
                }
            }
        }
    }

    private func count(_ growth: WeeklyGrowth) -> some View {
        Text("\(growth.practicedDays) / \(growth.goal)일 실천")
            .font(.title3.weight(.bold))
            .monospacedDigit()
            .lineLimit(1)
    }

    /// 목표만큼의 칸. 실천한 날만큼 채운다.
    private func dots(_ growth: WeeklyGrowth) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<growth.goal, id: \.self) { index in
                Circle()
                    .fill(index < growth.filledDots ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.track))
                    .frame(width: 11, height: 11)
            }
        }
        .accessibilityHidden(true)
    }

    /// 주간 목표 바꾸기(1~7일). 고르지 않으면 루틴 일정에 맞춘 추천값을 쓴다.
    private func goalMenu(_ growth: WeeklyGrowth) -> some View {
        let recommended = WeeklyGrowthCalculator.recommendedGoal(routineWeekdays: store.activeRoutines.map(\.weekdays))
        return Menu {
            Picker("주간 목표", selection: Binding(
                get: { preferences.weeklyGoal ?? 0 },
                set: { preferences.setWeeklyGoal($0 == 0 ? nil : $0) }
            )) {
                Text("추천 (\(recommended)일)").tag(0)
                ForEach(1...7, id: \.self) { days in
                    Text("\(days)일").tag(days)
                }
            }
            .pickerStyle(.inline)
        } label: {
            #if os(macOS)
            // Mac의 메뉴 단추는 펼침 표시를 스스로 그린다.
            Text("목표 \(growth.goal)일")
            #else
            HStack(spacing: 3) {
                Text("목표 \(growth.goal)일")
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            // 누르는 자리를 글자보다 넉넉하게 잡는다.
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            #endif
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        #endif
        .fixedSize()
        .accessibilityLabel("주간 목표 \(growth.goal)일")
        .accessibilityHint("주간 목표를 1일에서 7일 사이로 바꿉니다.")
    }
}
