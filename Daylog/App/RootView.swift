import AppKit
import Combine
import CoreData
import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            Group {
                switch store.section {
                case .dashboard: DashboardView()
                case .routines: RoutineManagementView()
                case .statistics: StatisticsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.windowBackground)
        }
        .alert("문제가 발생했어요", isPresented: errorIsPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification).first()) { notification in
            // 실행 직후 첫 입력 칸이 전체 선택된 채 포커스를 받으면 실수로 덮어쓰기 쉽다.
            let window = notification.object as? NSWindow
            DispatchQueue.main.async {
                window?.makeFirstResponder(nil)
            }
        }
        .onReceive(Self.todayMayHaveChanged) { _ in
            store.refreshToday()
        }
        .onReceive(Self.storeMayHaveChanged) { _ in
            store.handleExternalChanges()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            store.flush()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            store.flush()
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }

    /// 다른 기기의 변경이 iCloud를 통해 저장소에 들어왔을 수 있는 시점: 저장소 변경 알림과 앱 활성화.
    /// 자체 폴링은 하지 않는다. 가져오기 자체는 시스템이 알아서 한다.
    private static let storeMayHaveChanged: AnyPublisher<Notification, Never> = {
        let center = NotificationCenter.default
        return Publishers.Merge(
            center.publisher(for: .NSPersistentStoreRemoteChange),
            center.publisher(for: NSApplication.didBecomeActiveNotification)
        )
        .debounce(for: .milliseconds(700), scheduler: RunLoop.main)
        .eraseToAnyPublisher()
    }()

    /// 자정, 앱 활성화, 잠자기 해제, 시계·시간대 변경.
    private static let todayMayHaveChanged: AnyPublisher<Notification, Never> = {
        let center = NotificationCenter.default
        return Publishers.MergeMany([
            center.publisher(for: .NSCalendarDayChanged),
            center.publisher(for: .NSSystemTimeZoneDidChange),
            center.publisher(for: .NSSystemClockDidChange),
            center.publisher(for: NSApplication.didBecomeActiveNotification),
            NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification),
        ])
        .receive(on: RunLoop.main)
        .eraseToAnyPublisher()
    }()
}

/// 사이드바. 선택한 메뉴는 옅은 민트 바탕과 민트색 글자·아이콘으로 표시한다(굵기도 달라 색만으로 구분하지 않는다).
private struct SidebarView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.accent)
                    Text("Daylog")
                        .font(.system(size: 20, weight: .bold))
                }
                Text("작은 반복이 큰 변화를 만든다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 14)
            .accessibilityElement(children: .combine)

            ForEach(Array(AppStore.Section.allCases.enumerated()), id: \.element) { index, section in
                SidebarRow(section: section, isSelected: store.section == section, shortcut: index + 1) {
                    store.section = section
                }
            }

            Spacer(minLength: 12)

            Label("오늘도, 더 나은 내일을 위해.", systemImage: "leaf")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct SidebarRow: View {
    let section: AppStore.Section
    let isSelected: Bool
    let shortcut: Int
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: section.symbol)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .frame(width: 20)
                Text(section.title)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.primary))
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                isSelected ? AnyShapeStyle(Theme.accentWash) : AnyShapeStyle(isHovered ? Theme.track : Color.clear),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("\(section.title) (⌘\(shortcut))")
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
