import Foundation
import Testing
@testable import Daylog

/// v1.4: 예정 시간(표시용 글자)과 오늘 화면의 "다음 루틴"
struct TimeLabelTests {
    @Test func readsClockTimes() {
        #expect(TimeLabel.minutes("07:30") == 450)
        #expect(TimeLabel.minutes("7:05") == 425)
        #expect(TimeLabel.minutes(" 23:59 ") == 1439)
        #expect(TimeLabel.minutes("00:00") == 0)
    }

    /// 예전에 자유롭게 적어 둔 글자는 시각으로 읽지 않는다(지우지도 않는다).
    @Test func leavesFreeTextAlone() {
        #expect(TimeLabel.minutes("") == nil)
        #expect(TimeLabel.minutes("아침 먹고") == nil)
        #expect(TimeLabel.minutes("24:00") == nil)
        #expect(TimeLabel.minutes("7:60") == nil)
        #expect(TimeLabel.minutes("7시 30분") == nil)
    }

    @Test func writesTwoDigitLabels() {
        #expect(TimeLabel.label(minutes: 450) == "07:30")
        #expect(TimeLabel.label(minutes: 0) == "00:00")
        #expect(TimeLabel.label(minutes: 1439) == "23:59")
    }

    /// 시간 선택 컨트롤을 거쳐도 값이 그대로다.
    @Test func roundTripsThroughDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Seoul"))
        for label in ["00:00", "07:30", "12:05", "23:59"] {
            let date = try #require(TimeLabel.date(label, calendar: calendar))
            #expect(TimeLabel.label(from: date, calendar: calendar) == label)
        }
        #expect(TimeLabel.date("아침 먹고", calendar: calendar) == nil)
    }
}

struct NextCheckTests {
    private let morning = GroupSnapshot(id: UUID(), title: "아침", colorKey: "mint", order: 0)
    private let evening = GroupSnapshot(id: UUID(), title: "저녁", colorKey: "purple", order: 1)

    private func check(_ title: String, _ time: String, done: Bool = false) -> CheckValue {
        CheckValue(id: UUID(), title: title, timeLabel: time, note: "", isDone: done)
    }

    private func sections() -> [CheckSection] {
        [
            CheckSection(group: morning, checks: [check("물", "07:00"), check("스트레칭", "07:30"), check("일기", "")]),
            CheckSection(group: evening, checks: [check("산책", "21:00"), check("정리", "저녁 먹고")]),
        ]
    }

    /// 지금 이후로 가장 이른 것을 고른다. 이미 지난 것이 남아 있어도 "다음"은 앞으로 올 것이다.
    @Test func picksTheEarliestUpcoming() throws {
        let next = try #require(NextCheck.pick(from: sections(), nowMinutes: 7 * 60 + 10))
        #expect(next.check.title == "스트레칭")
        #expect(next.group == morning)
        #expect(next.minutes == 450)
        #expect(!next.isOverdue)
    }

    /// 예정 시간과 지금이 같으면 아직 지나지 않은 것으로 본다.
    @Test func treatsTheCurrentMinuteAsUpcoming() throws {
        let next = try #require(NextCheck.pick(from: sections(), nowMinutes: 7 * 60))
        #expect(next.check.title == "물")
        #expect(!next.isOverdue)
    }

    /// 남은 것이 모두 지난 시간이면 가장 먼저 밀린 것을 알려 준다.
    @Test func fallsBackToTheEarliestOverdue() throws {
        let next = try #require(NextCheck.pick(from: sections(), nowMinutes: 22 * 60))
        #expect(next.check.title == "물")
        #expect(next.isOverdue)
    }

    /// 완료한 항목, 시간이 없는 항목, 시각으로 읽히지 않는 항목은 고르지 않는다.
    @Test func skipsDoneAndUntimedChecks() {
        let done = [
            CheckSection(group: morning, checks: [check("물", "07:00", done: true), check("일기", "")]),
            CheckSection(group: evening, checks: [check("정리", "저녁 먹고")]),
        ]
        #expect(NextCheck.pick(from: done, nowMinutes: 6 * 60) == nil)
        #expect(NextCheck.pick(from: [], nowMinutes: 6 * 60) == nil)
    }

    /// 같은 시각이면 목록에서 앞에 있는 것.
    @Test func keepsListOrderForTies() throws {
        let tied = [CheckSection(group: morning, checks: [check("가", "08:00"), check("나", "08:00")])]
        #expect(try #require(NextCheck.pick(from: tied, nowMinutes: 0)).check.title == "가")
    }
}
