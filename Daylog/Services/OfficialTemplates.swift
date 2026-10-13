import Foundation

/// 앱에 든 공식 루틴 템플릿. 루틴 정의뿐이고, 인기 수치나 후기 같은 지어낸 정보는 두지 않는다.
enum OfficialTemplates {
    private typealias Routine = RoutineTemplate.Routine
    private typealias Group = RoutineTemplate.Group

    private static func template(
        _ id: String, _ title: String, _ summary: String, _ category: TemplateCategory, tags: [String],
        symbol: String, color: GroupColor, groups: [Group]
    ) -> RoutineTemplate {
        RoutineTemplate(
            id: "official.\(id)", title: title, summary: summary, category: category, tags: tags,
            thumbnail: TemplateThumbnail(symbol: symbol, colorKey: color.rawValue), groups: groups
        )
    }

    static let all: [RoutineTemplate] = [
        template(
            "morning-light", "가벼운 아침 시작", "물 한 잔과 스트레칭으로 부담 없이 하루를 열어요.", .morning,
            tags: ["아침", "기상", "스트레칭", "입문"], symbol: "sunrise.fill", color: .orange,
            groups: [Group(title: "아침 루틴", routines: [
                Routine(title: "기상 후 물 한 잔", time: "07:00"),
                Routine(title: "가벼운 스트레칭", time: "07:10", note: "5분"),
                Routine(title: "오늘 할 일 3가지 적기", time: "07:30")
            ])]
        ),
        template(
            "morning-miracle", "미라클 모닝", "일찍 일어나 명상·기록·독서로 나를 위한 시간을 먼저 써요.", .morning,
            tags: ["아침", "명상", "감사", "독서"], symbol: "sparkles", color: .yellow,
            groups: [Group(title: "미라클 모닝", routines: [
                Routine(title: "일찍 일어나기", time: "06:00"),
                Routine(title: "명상", time: "06:10", note: "10분"),
                Routine(title: "감사 일기 3줄", time: "06:25"),
                Routine(title: "아침 독서", time: "06:40", note: "20분")
            ])]
        ),
        template(
            "fitness-strength", "주 3회 근력 운동", "월·수·금 근력 운동과 매일의 마무리 스트레칭.", .fitness,
            tags: ["운동", "근력", "헬스", "스트레칭"], symbol: "dumbbell.fill", color: .coral,
            groups: [Group(title: "운동", routines: [
                Routine(title: "근력 운동", weekdays: [1, 3, 5], time: "19:00", note: "40분"),
                Routine(title: "마무리 스트레칭", time: "21:00", note: "10분"),
                Routine(title: "단백질 챙기기")
            ])]
        ),
        template(
            "fitness-walk", "걷기와 물 마시기", "하루 걸음과 물 섭취부터 챙기는 기본 건강 습관.", .fitness,
            tags: ["건강", "걷기", "물", "영양제"], symbol: "figure.walk", color: .mint,
            groups: [Group(title: "건강", routines: [
                Routine(title: "30분 걷기", time: "12:30"),
                Routine(title: "물 2L 마시기"),
                Routine(title: "영양제 먹기", time: "08:30")
            ])]
        ),
        template(
            "fitness-running", "러닝 입문", "화·목·토 30분 러닝으로 달리는 습관을 만들어요.", .fitness,
            tags: ["운동", "러닝", "달리기", "유산소"], symbol: "figure.run", color: .green,
            groups: [Group(title: "러닝", routines: [
                Routine(title: "러닝", weekdays: [2, 4, 6], time: "07:00", note: "30분"),
                Routine(title: "러닝 후 스트레칭", weekdays: [2, 4, 6], note: "5분")
            ])]
        ),
        template(
            "study-reading", "매일 독서 30분", "자기 전 30분 읽고 한 줄로 남겨요.", .study,
            tags: ["독서", "책", "기록"], symbol: "book.fill", color: .purple,
            groups: [Group(title: "독서", routines: [
                Routine(title: "독서", time: "21:30", note: "30분"),
                Routine(title: "읽은 내용 한 줄 기록")
            ])]
        ),
        template(
            "study-language", "외국어 공부", "평일에는 단어와 듣기, 주말에는 복습.", .study,
            tags: ["공부", "영어", "외국어", "단어"], symbol: "character.book.closed.fill", color: .blue,
            groups: [Group(title: "외국어 공부", routines: [
                Routine(title: "단어 20개 외우기", weekdays: Weekdays.workdays, time: "08:00"),
                Routine(title: "듣기 15분", weekdays: Weekdays.workdays, time: "20:00"),
                Routine(title: "한 주 복습", weekdays: [6], time: "10:00")
            ])]
        ),
        template(
            "focus-deepwork", "집중 작업 블록", "평일 오전·오후에 방해 없는 집중 시간을 정해 둬요.", .focus,
            tags: ["집중", "업무", "딥워크", "생산성"], symbol: "target", color: .blue,
            groups: [Group(title: "집중 작업", routines: [
                Routine(title: "오전 핵심 작업 집중", weekdays: Weekdays.workdays, time: "09:00", note: "90분"),
                Routine(title: "오후 작업", weekdays: Weekdays.workdays, time: "14:00", note: "90분"),
                Routine(title: "하루 마감 정리", weekdays: Weekdays.workdays, time: "18:00")
            ])]
        ),
        template(
            "focus-weekly", "주간 계획과 회고", "월요일에 계획하고 일요일에 돌아봐요.", .focus,
            tags: ["계획", "회고", "주간", "생산성"], symbol: "calendar.badge.checkmark", color: .purple,
            groups: [Group(title: "계획과 회고", routines: [
                Routine(title: "주간 계획 세우기", weekdays: [1], time: "09:00"),
                Routine(title: "내일 할 일 정리", time: "21:30"),
                Routine(title: "주간 회고", weekdays: [7], time: "20:00")
            ])]
        ),
        template(
            "life-evening", "저녁 마무리", "일기와 정리로 하루를 닫고 일찍 쉬어요.", .lifestyle,
            tags: ["저녁", "일기", "수면", "정리"], symbol: "moon.stars.fill", color: .purple,
            groups: [Group(title: "저녁 루틴", routines: [
                Routine(title: "일기 작성", time: "21:00"),
                Routine(title: "내일 할 일 정리", time: "21:30"),
                Routine(title: "휴대폰 내려놓기", time: "22:30")
            ])]
        ),
        template(
            "life-tidy", "정리하는 습관", "매일 10분 정리와 주 단위 집안일.", .lifestyle,
            tags: ["정리", "청소", "집안일", "가계부"], symbol: "house.fill", color: .mint,
            groups: [Group(title: "생활", routines: [
                Routine(title: "10분 정리", time: "20:30"),
                Routine(title: "빨래", weekdays: [3, 6]),
                Routine(title: "가계부 정리", weekdays: [7], time: "19:00")
            ])]
        )
    ]
}
