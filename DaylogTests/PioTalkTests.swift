import Foundation
import Testing
@testable import Daylog

/// 피오의 한마디 규칙(2026-10-25). 대사는 제목 줄 한 줄에 들어가야 하고, 상황마다 맞는 첫 대사가 나와야 한다.
struct PioTalkTests {
    private func today(done: Int, total: Int, streak: Int = 0, isToday: Bool = true, isVacation: Bool = false,
                       outfit: PioOutfitID = .basic, hour: Int = 9) -> [String] {
        PioLines.today(done: done, total: total, streak: streak, isToday: isToday, isVacation: isVacation, outfit: outfit, hour: hour)
    }

    @Test func firstLineFollowsTheSituation() {
        #expect(today(done: 0, total: 0).first == "첫 루틴, 같이 만들어요!")
        #expect(today(done: 0, total: 4, hour: 8).first == "좋은 아침! 하나씩 해요")
        #expect(today(done: 0, total: 4, hour: 20).first == "지금 해도 늦지 않아요")
        #expect(today(done: 1, total: 4).first == "3개 남았어요, 힘내요!")
        #expect(today(done: 2, total: 4).first == "절반 넘었어요! 좋아요")
        #expect(today(done: 3, total: 4).first == "하나만 더 하면 끝!")
        #expect(today(done: 4, total: 4).first == "오늘 다 해냈어요! 최고!")
        #expect(today(done: 4, total: 4, streak: 6).first == "6일 연속이에요! 최고!")
        #expect(today(done: 1, total: 4, isToday: false).first == "지난 기록을 보고 있어요")
        #expect(today(done: 0, total: 4, isVacation: true).first == "오늘은 푹 쉬어요")
    }

    @Test func outfitLineJoinsOnlyForPaidOutfits() {
        #expect(today(done: 1, total: 4).count == 1)
        let halloween = today(done: 1, total: 4, outfit: .halloween)
        #expect(halloween.contains("사탕 하나, 루틴 하나!"))
        for outfit in PioOutfitID.allCases {
            #expect((PioLines.outfit(outfit) == nil) == (outfit == .basic), "\(outfit)")
        }
    }

    /// 제목 줄 한 줄에 들어가는 길이(iPhone SE에서 확인한 약 14자, 여유 두고 16자).
    @Test func everyLineFitsOneTitleRow() {
        var lines = [PioLines.checked, PioLines.skipped, PioLines.settings, PioLines.calendar, PioLines.vacation,
                     PioLines.templates, PioLines.routines(count: 0), PioLines.routines(count: 12)]
        lines += [6, 12, 17, 23].map { PioLines.meals(hour: $0) }
        lines += PioOutfitID.allCases.compactMap(PioLines.outfit)
        for hour in [8, 13, 20, 2] {
            for (done, total) in [(0, 0), (0, 5), (1, 5), (3, 5), (4, 5), (5, 5)] {
                lines += today(done: done, total: total, streak: 12, outfit: .astronaut, hour: hour)
            }
        }
        for line in lines { #expect(line.count <= 16, "\(line) (\(line.count)자)") }
    }

    @Test func startIndexIsStableAndInRange() {
        let date = Date(timeIntervalSince1970: 1_792_900_000)
        for count in 1...3 {
            let index = PioLines.startIndex(count: count, date: date)
            #expect((0..<count).contains(index))
            #expect(index == PioLines.startIndex(count: count, date: date))
        }
        #expect(PioLines.startIndex(count: 1, date: date) == 0)
    }
}
