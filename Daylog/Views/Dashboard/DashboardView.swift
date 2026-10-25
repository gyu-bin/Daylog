import SwiftUI

struct DashboardView: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isEditing = false
    /// 휴가인 날에 [평소 화면 보기]를 눌렀다. 다른 메뉴에 다녀오거나 휴가가 끝나면 풀린다(저장하지 않는다).
    @State private var showsDashboardOnVacation = false

    /// 이 너비부터 두 열로 나눈다.
    static let wideBreakpoint: CGFloat = 880

    private var isOnVacation: Bool { store.isVacation(on: store.today) }

    var body: some View {
        Group {
            if isOnVacation, store.isViewingToday, !showsDashboardOnVacation {
                // 휴가인 날의 오늘 화면은 대시보드 대신 휴식 화면이다. 지난 날짜를 볼 때는 평소대로 그날의 기록을 보여 준다.
                VacationRestView(
                    onShowKeptRoutines: store.routinePolicy(on: store.today).keepsRoutines ? showKeptRoutines : nil,
                    onShowDashboard: { showsDashboardOnVacation = true }
                )
            } else if horizontalSizeClass == .compact {
                // 좁은 화면(iPhone, 좁은 iPad 창)은 오늘 할 일만 담은 짧은 화면을 쓴다. macOS는 늘 넓은 쪽이다.
                TodayCompactView(onShowVacationRest: vacationRestReturn)
            } else {
                wideDashboard
            }
        }
        .onChange(of: isOnVacation) { _, _ in showsDashboardOnVacation = false }
    }

    /// 휴가 중에 평소 화면을 보고 있을 때만 있는, 휴식 화면으로 돌아가는 길.
    private var vacationRestReturn: (() -> Void)? {
        guard isOnVacation, showsDashboardOnVacation else { return nil }
        return {
            store.goToToday()
            showsDashboardOnVacation = false
        }
    }

    /// 평소 화면으로 바꾸고, 그 화면이 뜬 뒤에 루틴 카드를 보여 준다(휴가인 날의 루틴 카드에는 유지하는 루틴만 있다).
    private func showKeptRoutines() {
        showsDashboardOnVacation = true
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            store.focusRoutineCard()
        }
    }

    private var wideDashboard: some View {
        GeometryReader { proxy in
            ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    DashboardHeader(isEditing: $isEditing)
                        .dashboardHeaderBackdrop()
                    if let vacationRestReturn {
                        VacationRestReturnBar(action: vacationRestReturn)
                    }
                    if isEditing {
                        DashboardEditBar(isEditing: $isEditing)
                    } else if !store.stats.hasStarted {
                        StartHint()
                    } else if let prompt = store.restartPrompt(dismissedDay: preferences.restartDismissedDay) {
                        RestartCard(prompt: prompt)
                    }
                    DashboardCards(compact: false, wide: proxy.size.width >= Self.wideBreakpoint, isEditing: isEditing)
                }
                .padding(Theme.pagePadding)
                // 카드가 자리를 옮기는 움직임. "동작 줄이기"를 켠 사람에게는 바로 바꿔 보여 준다.
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: preferences.cardOrder)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: preferences.leftCards)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: preferences.hiddenCards)
            }
            #if os(macOS)
            .onExitCommand { isEditing = false }
            #endif
            .onChange(of: store.section) { _, _ in isEditing = false }
            .onChange(of: store.routineCardFocusToken) { _, _ in
                RoutineCardFocus.scroll(scroll, reduceMotion: reduceMotion)
            }
            .onAppear {
                // 설정의 [대시보드 구성 편집]에서 넘어왔으면 바로 편집 모드로.
                if store.wantsDashboardEditing {
                    store.wantsDashboardEditing = false
                    isEditing = true
                }
            }
            }
        }
    }
}

/// 넓으면 가로 열(위쪽 맞춤), 좁으면 세로로 쌓는다.
/// 안의 카드가 `fillsHeight`면 가장 높은 카드에 맞춰 늘어나고, 아니면 각자 내용만큼만 차지한다.
struct AdaptiveRow<Content: View>: View {
    let isWide: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        if isWide {
            HStack(alignment: .top, spacing: Theme.spacing, content: content)
        } else {
            VStack(spacing: Theme.spacing, content: content)
        }
    }
}

struct StartHint: View {
    var body: some View {
        Label("그룹을 만들고 루틴을 추가하면 통계가 시작돼요.", systemImage: "sparkles")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accentWash, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// 제목과 날짜 이동을 한 줄에 둔다. 좁으면 두 줄로 내려간다.
struct DashboardHeader: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    @Environment(\.mobileUI) private var ui
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var isEditing: Bool
    /// 인사말 크기. 기본 24pt 그대로, 글자 크기 설정을 따라 커진다(날짜보다 작아지지 않게).
    @ScaledMetric(relativeTo: .title2) private var greetingSize: CGFloat = 24

    var body: some View {
        ViewThatFits(in: .horizontal) {
            // 제목과 단추 사이의 빈자리는 새싹이가 차지한다(빈칸 대신). 새싹이는 그 안에서만 걷고, 단추 쪽 끝으로 숨는다.
            HStack(alignment: .center, spacing: 8) {
                titles
                controls
            }
            VStack(alignment: .leading, spacing: 10) {
                titles
                controls
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            // 날짜는 제목 위에 적으므로 여기서는 앞뒤 이동만 둔다.
            DateNavigator(showsDate: false)
            editButton
            addButton
        }
        .fixedSize()
        .saessagiDebugFrame("controls")
    }

    /// 루틴 빠른 추가(⌘N과 같다): 마지막으로 쓴 그룹의 입력칸을 연다.
    private var addButton: some View {
        Button {
            store.requestQuickAddFocus(
                dashboardShowsRoutines: !preferences.hiddenCards.contains(.routines),
                isShowingSheet: Platform.isShowingSheet
            )
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 32)
                .background(GroupColor.blue.color, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("루틴 추가 (⌘N)")
        .accessibilityLabel("루틴 추가")
    }

    /// 대시보드 편집 켜기/끄기.
    private var editButton: some View {
        Button {
            isEditing.toggle()
        } label: {
            Image(systemName: isEditing ? "checkmark" : "square.grid.2x2")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isEditing ? AnyShapeStyle(Theme.onAccent) : AnyShapeStyle(.primary))
                .frame(width: 34, height: 32)
                .background(
                    isEditing ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.cardBackground),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: isEditing ? 0 : 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isEditing ? "편집 완료" : "대시보드 편집: 카드 순서·열·표시 바꾸기")
        .accessibilityLabel(isEditing ? "대시보드 편집 완료" : "대시보드 편집")
    }

    private var titles: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.selectedDay.longTitle)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(verbatim: store.isViewingToday ? ui.string(.dashboardGreeting) : "\(store.selectedDay.shortTitle)의 기록")
                        .font(.system(size: greetingSize, weight: .bold))
                    if store.isViewingToday, ui.showsGreetingIcon {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(GroupColor.yellow.color)
                            .accessibilityHidden(true)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            // 큰 글자(iPad)에서는 줄을 바꿀 수 있게 가로 고정을 푼다. 고정하면 날짜 한 줄이 화면보다 넓어져 아래 카드까지 옆으로 밀렸다.
            .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
            .saessagiDebugFrame("title")
            // 인사말 옆의 새싹이. 날짜와 인사말 두 줄의 높이 안에 들어가 머리말이 높아지지 않는다.
            // 단추까지 남는 자리를 모두 걸어 다닐 자리로 쓴다(넓은 창에서는 멀리 산책하고 단추 쪽 끝으로 숨는다).
            PioHeaderCompanion(size: 64)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 48)
                .layoutPriority(-1)
        }
    }
}

struct DateNavigator: View {
    @Environment(AppStore.self) private var store
    /// 가운데에 날짜를 적을지. 대시보드 머리말처럼 날짜가 따로 있으면 끈다.
    var showsDate = true
    /// Compact headers request44pt targets; wide layouts keep existing dimensions.
    var minimumTouchTarget: CGFloat = 32
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if showsDate && dynamicTypeSize.isAccessibilitySize {
            // 큰 글자: 날짜를 칸 안에 줄여 넣으면 "2026년 10월…"로 잘렸다. 날짜는 위에 온전히 적고 단추는 아래 줄에 둔다.
            VStack(alignment: .leading, spacing: 6) {
                Text(store.selectedDay.longTitle)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("선택한 날짜 \(store.selectedDay.longTitle)")
                DateNavigator(showsDate: false, minimumTouchTarget: max(minimumTouchTarget, 44))
            }
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                stepButton(symbol: "chevron.left", label: "이전 날짜", help: "이전 날짜 (⌘[)") {
                    store.goToPreviousDay()
                }
                if showsDate {
                    Text(store.selectedDay.longTitle)
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                        // 글자 크기를 키워도 화면 너비를 넘기지 않게, 자리가 모자라면 날짜 글자를 줄인다.
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(minWidth: 120, idealWidth: 160)
                        .accessibilityLabel("선택한 날짜 \(store.selectedDay.longTitle)")
                } else {
                    Divider().frame(height: 16)
                }
                stepButton(symbol: "chevron.right", label: "다음 날짜", help: "다음 날짜 (⌘])") {
                    store.goToNextDay()
                }
                .disabled(!store.canGoToNextDay)
            }
            .frame(height: minimumTouchTarget)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.cardBorder, lineWidth: 1))

            // 오늘을 보고 있으면 눌러도 할 일이 없다: 흐리게 비활성화하고, 과거를 볼 때는 눈에 띄게 한다.
            Button {
                store.goToToday()
            } label: {
                Text("오늘")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(store.isViewingToday ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Theme.onAccent))
                    .padding(.horizontal, 14)
                    .frame(minHeight: minimumTouchTarget)
                    .background(
                        store.isViewingToday ? AnyShapeStyle(Theme.track) : AnyShapeStyle(Theme.accent),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(store.isViewingToday)
            .help("오늘로 이동 (⌘T)")
            .accessibilityLabel("오늘로 이동")
        }
        // 날짜를 함께 보여 줄 때는 가로로 줄어들 수 있어야 한다(큰 글자 크기에서 화면 밖으로 밀려나지 않게).
        .fixedSize(horizontal: !showsDate, vertical: true)
    }

    private func stepButton(symbol: String, label: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: max(34, minimumTouchTarget), height: minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(help)
    }
}
