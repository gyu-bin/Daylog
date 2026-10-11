import CoreGraphics
import Foundation
import Testing
@testable import Daylog

/// Phase 4-A: 실제 화면 점검에서 찾은 문제의 회귀 테스트
struct QualityAuditTests {
    private let padScreen = CGSize(width: 834, height: 1210)

    /// iPad 창 모드에서만 창 조절 단추만큼 내용을 내린다.
    @Test func windowedPadClearsTheWindowControls() {
        let windowed = WindowControls.topClearance(
            window: CGSize(width: 655, height: 1034), screen: padScreen, isPad: true, systemHasWindowControls: true
        )
        #expect(windowed == WindowControls.clearance)
        #expect(windowed > 0)
        // 너비는 같고 높이만 줄어든 창도 창 모드다.
        #expect(WindowControls.topClearance(
            window: CGSize(width: 834, height: 900), screen: padScreen, isPad: true, systemHasWindowControls: true
        ) == WindowControls.clearance)
    }

    /// 전체 화면, iPhone, 창 조절 단추가 없는 예전 iPadOS에서는 여백을 더하지 않는다.
    @Test func fullScreenPhoneAndOlderSystemsAreUnchanged() {
        #expect(WindowControls.topClearance(window: padScreen, screen: padScreen, isPad: true, systemHasWindowControls: true) == 0)
        // 소수점 반올림 차이는 전체 화면으로 본다.
        #expect(WindowControls.topClearance(
            window: CGSize(width: 833.5, height: 1209.5), screen: padScreen, isPad: true, systemHasWindowControls: true
        ) == 0)
        #expect(WindowControls.topClearance(
            window: CGSize(width: 320, height: 600), screen: CGSize(width: 402, height: 874), isPad: false, systemHasWindowControls: true
        ) == 0)
        // iPadOS 25 이하의 Split View: 창은 작지만 창 조절 단추가 없다.
        #expect(WindowControls.topClearance(
            window: CGSize(width: 417, height: 1210), screen: padScreen, isPad: true, systemHasWindowControls: false
        ) == 0)
    }

    /// 화면 키보드에만 [완료] 막대를 띄운다. 외장 키보드의 낮은 보조 막대나 키보드가 없을 때는 띄우지 않는다.
    @Test func doneBarFollowsTheSoftwareKeyboardOnly() {
        #expect(KeyboardVisibility.isSoftwareKeyboard(height: 336))
        #expect(KeyboardVisibility.isSoftwareKeyboard(height: KeyboardVisibility.minimumSoftwareKeyboardHeight))
        #expect(!KeyboardVisibility.isSoftwareKeyboard(height: 55))
        #expect(!KeyboardVisibility.isSoftwareKeyboard(height: 0))
    }

    /// 가져오기 미리보기는 요일을 파일의 숫자가 아니라 루틴 화면과 같은 말로 보여 준다.
    @Test func importPreviewDescribesWeekdaysInWords() {
        #expect(DataTransferView.scheduleLabel(weekdays: Weekdays.all, time: "") == "매일 · 시간 없음")
        #expect(DataTransferView.scheduleLabel(weekdays: [1, 2, 3, 4, 5], time: "08:00") == "평일 · 08:00")
        #expect(DataTransferView.scheduleLabel(weekdays: [6, 7], time: "저녁") == "주말 · 저녁")
        #expect(DataTransferView.scheduleLabel(weekdays: [2, 4, 6], time: "19:30") == "화·목·토 · 19:30")
    }
}
