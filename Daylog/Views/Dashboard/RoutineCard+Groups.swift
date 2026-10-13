import SwiftUI

/// 그룹 한 칸의 그리기와 접기 상태.
extension RoutineCard {
    // MARK: - 그룹

    func sectionView(_ section: Section) -> some View {
        let color = GroupColor(key: section.group.colorKey)
        let isCollapsed = isCollapsed(section.id)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
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
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        if !section.checks.isEmpty {
                            Text("\(section.done)/\(section.checks.count)")
                                .font(.callout.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(section.done == section.checks.count ? AnyShapeStyle(color.ink) : AnyShapeStyle(.secondary))
                                .fixedSize()
                            // 큰 글자 크기에서는 작은 막대를 빼고 그 자리를 그룹 이름에 준다(숫자가 같은 내용을 말해 준다).
                            if !dynamicTypeSize.isAccessibilitySize {
                                ProgressBar(
                                    ratio: Achievement.ratio(done: section.done, total: section.checks.count) ?? 0,
                                    height: 6, tint: color.color
                                )
                                .frame(width: 56)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(section.group.title) 그룹, \(section.checks.count)개 중 \(section.done)개 완료")
                .accessibilityValue(isCollapsed ? "접힘" : "펼침")
                .accessibilityHint("누르면 접거나 펼칩니다.")

                // 항목 추가는 여기서 연다. 평소에는 입력칸을 접어 두어 목록에 체크할 것만 남긴다.
                if let target = section.target {
                    Button {
                        setCollapsed(section.id, false)
                        beginAdding(to: target.id)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(color.ink)
                            // 터치 화면에서는 누르기 쉽게 넓힌다.
                            .frame(width: Self.addButtonWidth, height: Self.addButtonHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("\(section.group.title)에 항목 추가")
                    .accessibilityLabel("\(section.group.title) 그룹에 항목 추가")
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, section.target == nil ? 10 : 4)
            .padding(.vertical, 6)
            .background(color.wash, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            if !isCollapsed {
                let showsTime = section.checks.contains { !$0.timeLabel.isEmpty }
                ForEach(section.checks) { check in
                    checkRow(check, tint: color.color, showsTime: showsTime)
                    if check.id != section.checks.last?.id {
                        // 이름이 시작하는 자리에 맞춘다(체크 칸이 있던 때는 그 너비만큼 더 들어가 있었다).
                        Divider().padding(.leading, 12)
                    }
                }
                // 항목이 하나도 없는 그룹은 첫 항목을 넣을 수 있게 입력칸을 늘 보여 준다.
                if let target = section.target, showsItemField(for: target.id, isEmpty: section.checks.isEmpty) {
                    if !section.checks.isEmpty { Divider().padding(.leading, 12) }
                    itemField(for: target, tint: color.color)
                }
            }
        }
    }

    #if os(macOS)
    static let addButtonWidth: CGFloat = 26
    static let addButtonHeight: CGFloat = 24
    #else
    static let addButtonWidth: CGFloat = 44
    static let addButtonHeight: CGFloat = 34
    #endif

    /// 입력칸을 보여 줄지: 그룹이 비었거나, [+]로 열었거나, 적던 내용이 남아 있을 때.
    func showsItemField(for groupID: UUID, isEmpty: Bool) -> Bool {
        isEmpty || addingGroupID == groupID
            || !(itemDrafts[groupID] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 그 그룹의 입력칸을 열고 포커스를 준다.
    func beginAdding(to groupID: UUID) {
        addingGroupID = groupID
        DispatchQueue.main.async {
            focus = .item(groupID)
        }
    }

    func checkRow(_ check: CheckValue, tint: Color, showsTime: Bool) -> some View {
        RoutineCheckRow(
            check: check, tint: tint, showsTime: showsTime, isToday: store.isViewingToday,
            setDone: { store.setDone(routineID: check.id, $0) },
            setSkipped: { store.setSkipped(routineID: check.id, $0) }
        )
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
