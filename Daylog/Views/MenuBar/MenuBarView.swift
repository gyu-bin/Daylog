#if os(macOS)
import AppKit
import SwiftUI

/// 메뉴 막대에서 여는 오늘의 루틴. 대시보드와 같은 저장소·같은 동작을 쓰므로, 여기서 체크하면 창도 바로 바뀐다.
struct MenuBarView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let sections = store.todaySections
        let total = sections.reduce(0) { $0 + $1.total }
        let done = sections.reduce(0) { $0 + $1.done }

        VStack(alignment: .leading, spacing: 0) {
            header(done: done, total: total)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)
            Divider()

            if sections.isEmpty {
                Text(store.hasRoutines ? "오늘은 예정된 루틴이 없어요." : "아직 등록된 루틴이 없어요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
            } else {
                // 그룹과 항목이 많으면 이 안에서 스크롤한다. 스크롤 영역은 제 높이를 스스로 정하지 못하므로
                // (팝오버가 내용에 맞춰 줄어들어 목록이 사라진다) 줄 수로 어림한 높이를 준다.
                ScrollView {
                    VStack(alignment: .leading, spacing: Self.groupSpacing) {
                        ForEach(sections) { section in
                            groupView(section)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, Self.listPadding)
                }
                .frame(height: min(Self.listHeight(sections), Self.maxListHeight))
            }

            Divider()
            footer
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(width: 300)
        .onAppear {
            // 창을 닫아 둔 채 자정을 넘겼어도 열 때의 오늘을 보여 준다.
            store.refreshToday()
        }
    }

    private static let groupSpacing: CGFloat = 10
    private static let listPadding: CGFloat = 10
    private static let groupHeaderHeight: CGFloat = 30
    private static let rowHeight: CGFloat = 30
    private static let maxListHeight: CGFloat = 380

    /// 목록 전체의 어림 높이.
    static func listHeight(_ sections: [CheckSection]) -> CGFloat {
        let rows = sections.reduce(0) { $0 + $1.checks.count }
        return listPadding * 2
            + CGFloat(sections.count) * (groupHeaderHeight + 2)
            + CGFloat(rows) * (rowHeight + 2)
            + CGFloat(max(sections.count - 1, 0)) * groupSpacing
    }

    private func header(done: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Daylog")
                        .font(.headline)
                    Text(store.today.longTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 8)
                if let percent = Achievement.percent(done: done, total: total) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(percent)%")
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                        Text("\(done)/\(total) 완료")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            if total > 0 {
                ProgressBar(ratio: Achievement.ratio(done: done, total: total) ?? 0, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            total > 0
                ? "Daylog, \(store.today.longTitle), 달성률 \(Achievement.percent(done: done, total: total) ?? 0)%, \(total)개 중 \(done)개 완료"
                : "Daylog, \(store.today.longTitle)"
        )
    }

    private func groupView(_ section: CheckSection) -> some View {
        let color = GroupColor(key: section.group.colorKey)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                GroupBadge(title: section.group.title, color: color, size: 18)
                Text(section.group.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text("\(section.done)/\(section.total)")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .frame(height: Self.groupHeaderHeight)
            .background(color.wash, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(section.group.title) 그룹, \(section.total)개 중 \(section.done)개 완료")
            .accessibilityAddTraits(.isHeader)

            ForEach(section.checks) { check in
                Toggle(isOn: Binding(
                    get: { check.isDone },
                    set: { store.setDone(routineID: check.id, on: store.today, $0) }
                )) {
                    HStack(spacing: 8) {
                        Text(check.title)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !check.timeLabel.isEmpty {
                            Text(check.timeLabel)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .toggleStyle(RoutineCheckStyle(tint: color.color))
                .padding(.horizontal, 8)
                .frame(height: Self.rowHeight)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Button("Daylog 열기") {
                openMainWindow(section: .dashboard)
            }
            Button("설정") {
                openMainWindow(section: .settings)
            }
            Spacer(minLength: 6)
            Button("종료") {
                NSApplication.shared.terminate(nil)
            }
            .accessibilityLabel("Daylog 종료")
        }
        .controlSize(.small)
    }

    /// 닫아 둔 창이면 다시 열고, 앱을 앞으로 가져온다.
    private func openMainWindow(section: AppStore.Section) {
        if section == .dashboard {
            store.open(store.today)
        } else {
            store.section = section
        }
        openWindow(id: "main")
        NSApplication.shared.activate(ignoringOtherApps: true)
        dismiss()
    }
}
#endif
