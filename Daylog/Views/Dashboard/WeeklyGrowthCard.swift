import SwiftUI

/// 이번 주의 성장: 이번 주에 실천한 날 수와 주간 목표. 실천한 날의 칸이 중심이다.
/// 보고 있는 날짜와 상관없이 실제 이번 주를 보여 준다. 값은 `WeeklyGrowthCalculator`가 통계의 날짜별 결과에서 센다.
/// 오늘 화면에 움직이는 새싹이가 겹치지 않도록 이 카드에는 새싹이를 두지 않는다(성장의 새싹이는 "새싹이 성장" 카드가 맡는다).
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
                VStack(alignment: .leading, spacing: 4) {
                    // 루틴이 없으면 0/5 칸 대신 시작 안내만 보여 준다.
                    if growth.hasRoutines {
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
                        .padding(.bottom, 2)
                    }
                    Text(growth.headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(growth.isGoalReached ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.primary))
                    Text(detail(growth))
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

    /// 둘째 줄. 루틴은 있는데 아직 한 번도 완료한 적이 없으면 첫 행동을 알려 준다.
    private func detail(_ growth: WeeklyGrowth) -> String {
        if growth.hasRoutines, !growth.isOnVacation, store.stats.lastPracticedDay == nil {
            return "오늘 루틴 하나를 완료하면 첫 실천이 기록돼요."
        }
        return growth.detail
    }

    private func count(_ growth: WeeklyGrowth) -> some View {
        HStack(spacing: 5) {
            Text("\(growth.practicedDays) / \(growth.goal)일 실천")
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
            if growth.isGoalReached {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
            }
        }
    }

    /// 목표만큼의 칸. 실천한 날만큼 채운다.
    private func dots(_ growth: WeeklyGrowth) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<growth.goal, id: \.self) { index in
                Circle()
                    .fill(index < growth.filledDots ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.track))
                    .frame(width: 12, height: 12)
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
