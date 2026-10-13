import Foundation

/// 내 루틴에서 게시할 내용을 만든다. 들어오는 값이 그룹 이름·색과 루틴의 이름·요일·시각·설명뿐이라,
/// 체크·건너뛰기·식사·휴가·통계·기기 식별자·사진 같은 것은 처음부터 실릴 자리가 없다.
enum TemplatePublishing {
    /// 게시 화면에서 고르는 그룹 하나.
    struct GroupSource: Identifiable, Equatable {
        struct RoutineSource: Equatable {
            var title: String
            var weekdays: [Int]
            var timeLabel: String
            var note: String
        }

        /// 화면에서 고르는 데만 쓴다. 게시 내용에는 들어가지 않는다.
        let id: UUID
        var title: String
        var colorKey: String
        var routines: [RoutineSource]
    }

    /// 지금 쓰는 그룹과 루틴(보관·삭제한 것은 뺀다). 루틴이 없는 그룹은 게시할 것이 없어 뺀다.
    @MainActor
    static func sources(groups: [RoutineGroup], routines: [RoutineItem]) -> [GroupSource] {
        groups.filter { !$0.isArchived && !$0.isRemoved }.compactMap { group in
            let items = routines
                .filter { $0.effectiveGroupID == group.id && !$0.isArchived && !$0.isRemoved }
                .map { GroupSource.RoutineSource(title: $0.title, weekdays: $0.weekdays, timeLabel: $0.timeLabel, note: $0.note) }
            return items.isEmpty ? nil : GroupSource(id: group.id, title: group.title, colorKey: group.colorKey, routines: items)
        }
    }

    /// 고른 그룹을 공개할 모양으로 옮긴다. 루틴의 설명은 사용자가 포함하겠다고 했을 때만 싣는다.
    static func groups(from sources: [GroupSource], includesNotes: Bool) -> [RoutineTemplate.Group] {
        sources.map { source in
            RoutineTemplate.Group(
                title: source.title,
                colorKey: GroupColor(rawValue: source.colorKey)?.rawValue,
                routines: source.routines.map {
                    RoutineTemplate.Routine(
                        title: $0.title, weekdays: $0.weekdays.sorted(), time: $0.timeLabel, note: includesNotes ? $0.note : ""
                    )
                }
            )
        }
    }

    /// 공개될 내용을 사람이 읽을 수 있는 JSON으로. 게시 전 확인 화면이 그대로 보여 준다.
    static func previewJSON(_ draft: TemplateDraft) -> String {
        let data = try? JSONSerialization.data(withJSONObject: draft.payload(), options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        return data.map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    /// 썸네일로 고를 수 있는 기호.
    static let symbols = [
        "sunrise.fill", "sparkles", "dumbbell.fill", "figure.walk", "figure.run", "book.fill", "character.book.closed.fill",
        "target", "calendar.badge.checkmark", "moon.stars.fill", "house.fill", "heart.fill", "leaf.fill", "cup.and.saucer.fill",
        "pencil", "music.note"
    ]
}
