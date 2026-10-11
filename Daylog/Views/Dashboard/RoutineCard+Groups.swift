import SwiftUI

/// 그룹 한 칸의 그리기와 접기 상태.
extension RoutineCard {
    // MARK: - 그룹

    func sectionView(_ section: Section) -> some View {
        let color = GroupColor(key: section.group.colorKey)
        let isCollapsed = isCollapsed(section.id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                // 텍스트를 입력하는 중에는 화면이 움직이지 않게 애니메이션을 끄고, "동작 줄이기" 설정도 따른다.
                withAnimation(reduceMotion || focus != nil ? nil : .easeInOut(duration: 0.18)) {
                    toggleCollapsed(section.id)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    GroupBadge(title: section.group.title, color: color)
                    Text(section.group.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if !section.checks.isEmpty, !store.isVacation(on: store.selectedDay) {
                        Text("\(section.done)/\(section.checks.count)")
                            .font(.callout.weight(.medium))
                            .monospacedDigit()
                        ProgressBar(
                            ratio: Achievement.ratio(done: section.done, total: section.checks.count) ?? 0,
                            height: 6, tint: color.color
                        )
                        .frame(width: 72)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(color.wash, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(section.group.title) 그룹, \(section.checks.count)개 중 \(section.done)개 완료")
            .accessibilityValue(isCollapsed ? "접힘" : "펼침")
            .accessibilityHint("누르면 접거나 펼칩니다.")

            if !isCollapsed {
                let showsTime = section.checks.contains { !$0.timeLabel.isEmpty }
                ForEach(section.checks) { check in
                    checkRow(check, tint: color.color, showsTime: showsTime)
                    Divider().padding(.leading, 40)
                }
                if let target = section.target {
                    itemField(for: target, tint: color.color)
                }
            }
        }
    }

    func checkRow(_ check: CheckValue, tint: Color, showsTime: Bool) -> some View {
        Toggle(isOn: Binding(
            get: { check.isDone },
            set: { store.setDone(routineID: check.id, $0) }
        )) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(check.title)
                        .lineLimit(2)
                    if !check.note.isEmpty {
                        Text(check.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if showsTime {
                    Text(check.timeLabel)
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .toggleStyle(RoutineCheckStyle(tint: tint, routineTitle: check.title))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    func itemField(for group: RoutineGroup, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 19)
                .accessibilityHidden(true)
            TextField(
                "\(group.title)에 항목 추가",
                text: Binding(get: { itemDrafts[group.id] ?? "" }, set: { itemDrafts[group.id] = $0 }),
                prompt: Text("항목 추가")
            )
            .textFieldStyle(.plain)
            .focused($focus, equals: .item(group.id))
            .onSubmit { addItem(to: group) }
            .accessibilityLabel("\(group.title) 그룹에 새 항목")
            .accessibilityHint("Enter를 누르면 매일 하는 항목으로 추가됩니다.")
            if !(itemDrafts[group.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("추가") { addItem(to: group) }
                    .controlSize(.small)
                    .accessibilityLabel("\(group.title) 그룹에 항목 추가")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    func addItem(to group: RoutineGroup) {
        if store.addRoutine(title: itemDrafts[group.id] ?? "", in: group) {
            itemDrafts[group.id] = ""
        }
        focus = .item(group.id)
    }

    // MARK: - 접기

    var collapsed: Set<String> {
        Set(collapsedGroupIDs.split(separator: ",").map(String.init))
    }

    func isCollapsed(_ id: UUID) -> Bool {
        collapsed.contains(id.uuidString)
    }

    func toggleCollapsed(_ id: UUID) {
        setCollapsed(id, !isCollapsed(id))
    }

    func setCollapsed(_ id: UUID, _ isCollapsed: Bool) {
        var ids = collapsed
        if isCollapsed {
            ids.insert(id.uuidString)
        } else {
            ids.remove(id.uuidString)
        }
        collapsedGroupIDs = ids.sorted().joined(separator: ",")
    }
}
