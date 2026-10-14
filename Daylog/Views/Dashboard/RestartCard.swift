import SwiftUI

/// 다시 시작하기: 예정된 루틴을 며칠 하지 않은 사람에게 오늘 화면 위쪽에 잠깐 보여 주는 안내.
/// 오늘 하나를 완료하면 저절로 사라지고, 닫으면 다시 실천하기 전까지는 나오지 않는다. 대시보드 카드 배치와는 별개다.
struct RestartCard: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    let prompt: RestartPrompt

    var body: some View {
        Card(fillsHeight: false) {
            HStack(alignment: .center, spacing: 12) {
                // 반갑게 까딱이며 인사하고 가끔 통 뛴다.
                SaessagiAnimatedView(pose: .welcome, size: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text("오늘부터 다시 시작해 볼까요?")
                        .font(.headline)
                    Text("잠시 쉬었어도 괜찮아요. 오늘 작은 루틴 하나부터 시작해 보세요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("오늘 루틴 보기", action: showRoutines)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(.top, 4)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // 닫기 단추가 글자를 덮지 않게 오른쪽을 비워 둔다.
            .padding(.trailing, 22)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                preferences.setRestartDismissedDay(store.today)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("안내 닫기")
            .accessibilityHint("다시 실천하기 전까지는 이 안내를 보여 주지 않습니다.")
        }
    }

    /// 오늘로 돌아가 루틴 카드를 보여 준다. 오늘 예정된 루틴이 없으면 루틴을 추가할 수 있는 루틴 관리 화면으로 간다.
    /// 사용자의 카드 배치는 바꾸지 않는다.
    private func showRoutines() {
        store.goToToday()
        let hasRoutinesToday = store.todaySections.contains { !$0.checks.isEmpty }
        if hasRoutinesToday, preferences.visibleCards.contains(.routines) {
            store.focusRoutineCard()
        } else {
            store.section = .routines
        }
    }
}

/// 루틴 카드로 스크롤하고 약 1초 동안 은은하게 강조한다. 움직임 줄이기를 켰으면 스크롤과 강조를 움직임 없이 한다.
struct RoutineCardFocus: ViewModifier {
    static let scrollID = "dashboard.routineCard"
    /// 강조가 머무는 시간(초).
    static let duration = 1.0

    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHighlighted = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        content
            .overlay {
                shape
                    .fill(Theme.accent.opacity(isHighlighted ? 0.08 : 0))
                    .overlay(shape.strokeBorder(Theme.accent.opacity(isHighlighted ? 0.7 : 0), lineWidth: 2))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .onChange(of: store.routineCardFocusToken) { _, _ in
                Task {
                    if reduceMotion {
                        isHighlighted = true
                    } else {
                        withAnimation(.easeOut(duration: 0.25)) { isHighlighted = true }
                    }
                    try? await Task.sleep(for: .seconds(Self.duration))
                    if reduceMotion {
                        isHighlighted = false
                    } else {
                        withAnimation(.easeIn(duration: 0.45)) { isHighlighted = false }
                    }
                }
            }
    }

    @MainActor
    static func scroll(_ proxy: ScrollViewProxy, reduceMotion: Bool) {
        if reduceMotion {
            proxy.scrollTo(scrollID, anchor: .top)
        } else {
            withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(scrollID, anchor: .top) }
        }
    }
}
