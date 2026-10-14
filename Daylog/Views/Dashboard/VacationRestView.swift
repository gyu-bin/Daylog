import SwiftUI

/// 휴가인 날의 오늘 화면: 대시보드 대신 보여 주는 휴식 화면. 새싹이가 낮잠을 자고, 휴가가 며칠째인지 알려 준다.
///
/// 오늘 영역만 차지한다(사이드바·탭은 그대로). 기록이나 카드 배치는 건드리지 않고, 단추로 평소 화면을 잠깐 볼 수 있다.
struct VacationRestView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// [유지할 루틴 보기]. 휴가 중에 이어 가는 루틴이 없으면 nil이고 단추를 보여 주지 않는다.
    var onShowKeptRoutines: (() -> Void)?
    /// [평소 화면 보기].
    let onShowDashboard: () -> Void

    var body: some View {
        GeometryReader { proxy in
            // 글자를 크게 쓰거나 창이 낮으면 한 화면을 넘을 수 있다. 넘치면 스크롤하고, 아니면 가운데에 둔다.
            ScrollView {
                content(mascot: mascotSize(in: proxy.size))
                    .frame(maxWidth: 440)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background {
            VacationSceneBackground().ignoresSafeArea(edges: Self.backgroundEdges)
        }
    }

    /// 배경이 번지는 가장자리. Mac에서는 사이드바 밑으로 들어가지 않게 왼쪽은 남긴다.
    private static var backgroundEdges: Edge.Set {
        #if os(macOS)
        [.top, .bottom, .trailing]
        #else
        .all
        #endif
    }

    /// 새싹이의 크기: 화면 높이에 맞추되 너무 작거나 크지 않게.
    private func mascotSize(in size: CGSize) -> CGFloat {
        min(170, max(96, min(size.height * 0.2, size.width * 0.42)))
    }

    private func content(mascot: CGFloat) -> some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                Text(store.today.longTitle)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text("오늘은\n쉬어가는 날이에요.")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("잠시 멈춰도 괜찮아요.\n새싹이와 함께 여유로운 시간을 보내요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            napping(size: mascot)
                .padding(.top, 8)

            if let info = VacationRestInfo.make(periods: store.vacationPeriods, today: store.today) {
                progress(info)
            }

            VStack(spacing: 10) {
                if let onShowKeptRoutines {
                    Button(action: onShowKeptRoutines) {
                        Text("유지할 루틴 보기").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("휴가 중에도 이어 가기로 한 루틴을 보여 줍니다.")
                }
                Button(action: onShowDashboard) {
                    Text("평소 화면 보기").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("평소의 오늘 화면을 잠시 봅니다. 휴가와 카드 배치는 바뀌지 않아요.")
            }
            .controlSize(.large)
            .frame(maxWidth: 320)
        }
    }

    /// 풀 언덕 위에서 낮잠 자는 새싹이.
    private func napping(size: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(LinearGradient(colors: VacationPalette.mound(isDark: colorScheme == .dark), startPoint: .top, endPoint: .bottom))
                .frame(width: size * 1.7, height: size * 0.42)
                .offset(y: size * 0.14)
            SaessagiAnimatedView(pose: .sleep, size: size, behavior: .sleeping)
        }
        .padding(.bottom, size * 0.14)
        .accessibilityHidden(true)
    }

    private func progress(_ info: VacationRestInfo) -> some View {
        VStack(spacing: 8) {
            Text(info.title)
                .font(.headline)
                .monospacedDigit()
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule().fill(Theme.accent).frame(width: max(8, proxy.size.width * info.progress))
                }
            }
            .frame(height: 8)
            Text(info.periodTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: 320)
        .background(Theme.cardBackground.opacity(0.88), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(info.title). \(info.periodTitle)")
    }
}

/// 휴가 중에 평소 화면을 보고 있을 때 머리말 아래에 두는 줄: 휴식 화면으로 돌아가는 길.
struct VacationRestReturnBar: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Label("휴가 중이에요. 평소 화면을 보고 있어요.", systemImage: "beach.umbrella.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("휴식 화면으로", action: action)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.vacationTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
