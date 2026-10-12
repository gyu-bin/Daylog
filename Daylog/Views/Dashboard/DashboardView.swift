import SwiftUI

struct DashboardView: View {
    @Environment(AppStore.self) private var store
    @Environment(DevicePreferences.self) private var preferences
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isEditing = false

    /// 이 너비부터 두 열로 나눈다.
    static let wideBreakpoint: CGFloat = 880

    var body: some View {
        // 좁은 화면(iPhone, 좁은 iPad 창)은 오늘 할 일만 담은 짧은 화면을 쓴다. macOS는 늘 넓은 쪽이다.
        if horizontalSizeClass == .compact {
            TodayCompactView()
        } else {
            wideDashboard
        }
    }

    private var wideDashboard: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    DashboardHeader(isEditing: $isEditing)
                    if isEditing {
                        DashboardEditBar(isEditing: $isEditing)
                    } else if !store.stats.hasStarted {
                        StartHint()
                    }
                    DashboardCards(compact: false, wide: proxy.size.width >= Self.wideBreakpoint, isEditing: isEditing)
                }
                .padding(Theme.pagePadding)
                .animation(.easeInOut(duration: 0.2), value: preferences.cardOrder)
                .animation(.easeInOut(duration: 0.2), value: preferences.leftCards)
                .animation(.easeInOut(duration: 0.2), value: preferences.hiddenCards)
            }
            #if os(macOS)
            .onExitCommand { isEditing = false }
            #endif
            .onChange(of: store.section) { _, _ in isEditing = false }
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

/// 편집 모드의 안내와 도구: 숨긴 카드 되살리기, 기본 배치 복원, 완료.
struct DashboardEditBar: View {
    @Environment(DevicePreferences.self) private var preferences
    @Binding var isEditing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 넓으면 한 줄, 좁으면(iPhone) 안내와 단추를 두 줄로.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    hint
                    Spacer(minLength: 8)
                    buttons
                }
                VStack(alignment: .leading, spacing: 8) {
                    hint
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        buttons
                    }
                }
            }
            if !preferences.hiddenChoices.isEmpty {
                HStack(spacing: 8) {
                    Text("숨긴 카드")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 6) {
                        ForEach(preferences.hiddenChoices) { card in
                            Button {
                                preferences.setVisible(true, card: card)
                            } label: {
                                Label(card.title, systemImage: "plus")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel("\(card.title) 카드 다시 보이기")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentWash, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var hint: some View {
        Label("손잡이를 길게 눌러 끌거나 ⋯ 메뉴로 옮기고 숨겨요.", systemImage: "hand.draw")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var buttons: some View {
        Button("기본 배치 복원") { preferences.restoreDashboard() }
            .controlSize(.small)
        Button("완료") { isEditing = false }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .controlSize(.small)
            .keyboardShortcut(.defaultAction)
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
    @Binding var isEditing: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                titles
                Spacer(minLength: 16)
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
    }

    /// 루틴 빠른 추가(⌘N과 같다): 마지막으로 쓴 그룹의 입력칸을 연다.
    private var addButton: some View {
        Button {
            store.requestQuickAddFocus()
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
        VStack(alignment: .leading, spacing: 3) {
            Text(store.selectedDay.longTitle)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text(store.isViewingToday ? "오늘도 좋은 하루예요" : "\(store.selectedDay.shortTitle)의 기록")
                    .font(.system(size: 24, weight: .bold))
                if store.isViewingToday {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(GroupColor.yellow.color)
                        .accessibilityHidden(true)
                }
            }
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct DateNavigator: View {
    @Environment(AppStore.self) private var store
    /// 가운데에 날짜를 적을지. 대시보드 머리말처럼 날짜가 따로 있으면 끈다.
    var showsDate = true

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                stepButton(symbol: "chevron.left", label: "이전 날짜", help: "이전 날짜 (⌘[)") {
                    store.goToPreviousDay()
                }
                if showsDate {
                    Text(store.selectedDay.longTitle)
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                        .frame(minWidth: 160)
                        .accessibilityLabel("선택한 날짜 \(store.selectedDay.longTitle)")
                } else {
                    Divider().frame(height: 16)
                }
                stepButton(symbol: "chevron.right", label: "다음 날짜", help: "다음 날짜 (⌘])") {
                    store.goToNextDay()
                }
                .disabled(!store.canGoToNextDay)
            }
            .frame(height: 32)
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
                    .frame(height: 32)
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
        .fixedSize()
    }

    private func stepButton(symbol: String, label: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 34, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(help)
    }
}
