import Foundation
import Testing
@testable import Daylog

/// 첫 동기화 화면의 움직임: 장면마다 무엇이 언제 움직이는지.
struct SyncSceneTests {
    private let times = stride(from: 0.0, through: 30, by: 0.05)

    @Test func recordCardsFallOneByOneAndNeverCrowd() {
        var seenKinds = Set<Int>()
        var arrivals = 0
        var wasSparkling = false
        for t in times {
            let frame = SyncSceneMotion.receiving(t)
            // 동시에 두 장보다 많이 떠 있지 않고, 떠 있는 카드는 모두 구름과 수첩 사이에 있다.
            #expect(frame.cards.count <= 2)
            #expect(frame.cards.allSatisfy { $0.progress >= 0 && $0.progress < 1 })
            frame.cards.forEach { seenKinds.insert($0.kind.rawValue) }
            // 카드가 수첩에 닿을 때마다 수첩이 반짝인다.
            if frame.bookSparkle > 0 && !wasSparkling { arrivals += 1 }
            wasSparkling = frame.bookSparkle > 0
        }
        #expect(seenKinds == [0, 1, 2, 3])
        // 30초 동안 박자대로 꾸준히 내려온다(약 1.3초마다 한 장).
        #expect(arrivals >= 18 && arrivals <= 24)
        // 처음 나타난 순간에는 아직 카드가 없다.
        #expect(SyncSceneMotion.receiving(0).cards.isEmpty)
    }

    @Test func saessagiNodsWhenACardArrivesAndFlipsPagesSometimes() {
        let arrival = SyncSceneMotion.firstCard + SyncSceneMotion.cardFall
        let before = SyncSceneMotion.receiving(arrival - 0.05).saessagi
        let nod = SyncSceneMotion.receiving(arrival + 0.25).saessagi
        #expect(nod.squashY < before.squashY && nod.faceY > before.faceY && nod.bookLift > 0)
        #expect(times.contains { SyncSceneMotion.receiving($0).pageFlip > 0.5 })
        #expect(times.contains { SyncSceneMotion.receiving($0).saessagi.eyes < 0.3 })
    }

    @Test func readyCheckPopsAndSaessagiHopsTwiceThenCalmsDown() {
        // 체크는 처음엔 없고, 커졌다가 1로 자리 잡는다.
        #expect(SyncSceneMotion.ready(0).check == 0)
        #expect(SyncSceneMotion.ready(0.5).check > 1.1)
        #expect(abs(SyncSceneMotion.ready(1.05).check - 1) < 0.01)
        // 두 번 뛰고 두 번째가 더 높다. 내려앉을 때 눌린다.
        var peaks: [Double] = []
        var rising = false, last = 0.0
        for t in stride(from: 0.0, through: 4, by: 0.01) {
            let lift = SyncSceneMotion.ready(t).saessagi.lift
            if lift < last && rising { peaks.append(last) }
            rising = lift > last
            last = lift
        }
        #expect(peaks.count == 2 && peaks[1] > peaks[0])
        let landing = SyncSceneMotion.readyHops[0].start + 0.58
        #expect(SyncSceneMotion.ready(landing).saessagi.squashY < 0.9)
        // 그 뒤로는 뛰지 않고 잔잔하게 움직인다.
        for t in stride(from: 3.0, through: 20, by: 0.1) {
            let pose = SyncSceneMotion.ready(t).saessagi
            #expect(pose.lift == 0 && abs(pose.tilt) <= 2.6 && abs(pose.squashY - 1) < 0.02)
        }
        #expect(SyncSceneMotion.ready(2).stars.count == 6 && SyncSceneMotion.ready(10).stars.allSatisfy { $0 > 0 })
    }

    @Test func troubleRainsGentlyAndSaessagiLooksUpAndTilts() {
        var tilts = Set<Int>()
        var questionShown = false
        for t in times {
            let frame = SyncSceneMotion.trouble(t)
            // 빗방울은 셋뿐이고 한 번에 두 개 넘게 떨어지지 않는다.
            #expect(frame.drops.count == SyncSceneMotion.dropCount)
            #expect(frame.drops.filter { $0 > 0 }.count <= 2)
            // 늘 구름 쪽(위)을 올려다본다.
            #expect(frame.saessagi.faceY < 0 && frame.saessagi.lift == 0)
            tilts.insert(Int(frame.saessagi.tilt.rounded()))
            questionShown = questionShown || frame.question > 0.9
        }
        // 왼쪽으로도, 오른쪽으로도 갸웃거린다. 물음표가 나타난다.
        #expect(tilts.contains(-7) && tilts.contains(5) && questionShown)
        // 받는 중·완료와 움직임이 다르다: 카드도 체크도 없다.
        #expect(SyncSceneMotion.trouble(3).cards.isEmpty && SyncSceneMotion.trouble(3).check == 0)
    }

    @Test func reduceMotionShowsAStillMomentOfEachScene() {
        let still = SyncSceneMotion.frame(.receiving, at: SyncSceneMotion.stillTime(.receiving))
        #expect(still.cards.count == 1)
        #expect(SyncSceneMotion.frame(.ready, at: SyncSceneMotion.stillTime(.ready)).check > 0.9)
        #expect(SyncSceneMotion.frame(.trouble, at: SyncSceneMotion.stillTime(.trouble)).question > 0.9)
    }

    @Test func everyMovingValueRepeatsExactlyAsDeclared() {
        // Core Animation에는 처음 부분과 한 바퀴만 넘기고 되풀이한다. 그래서 선언한 대로 정확히 되풀이되어야 끊기거나 튀지 않는다.
        for kind in SyncSceneKind.allCases {
            for property in SyncSceneMotion.properties(kind) {
                let loop = SyncSceneMotion.loop(property, kind)
                for step in 0..<120 {
                    // 한 바퀴의 이음매(정확히 그 시각)는 피해서 잰다.
                    let t = loop.intro + 0.0007 + Double(step) * 0.073
                    let now = SyncSceneMotion.value(property, kind, at: t)
                    if let period = loop.period {
                        let later = SyncSceneMotion.value(property, kind, at: t + period)
                        #expect(abs(now - later) < 1e-6, "\(kind) \(property) t=\(t)")
                    } else {
                        let settled = SyncSceneMotion.value(property, kind, at: loop.intro)
                        #expect(abs(now - settled) < 0.01, "\(kind) \(property) t=\(t)")
                    }
                }
            }
        }
    }

    @Test func cardsPassBesideTheFaceAndEndInTheBook() {
        let book = CGPoint(x: 0, y: 296)
        for (index, startX) in SyncSceneMotion.cardStarts.enumerated() {
            // 중간에는 머리 옆(가운데에서 60 이상 떨어진 곳)을 지나고, 끝에는 수첩 가까이 와서 사라진다.
            let middle = SyncSceneMotion.cardPlacement(progress: 0.5, startX: startX, book: book)
            #expect(abs(middle.x) > 60 && middle.opacity == 1, "card \(index)")
            let end = SyncSceneMotion.cardPlacement(progress: 0.995, startX: startX, book: book)
            #expect(abs(end.x - book.x) < 1 && abs(end.y - book.y) < 10 && end.opacity < 0.05)
        }
        // 빗방울은 떨어지는 동안만 보인다.
        #expect(SyncSceneMotion.dropOpacity(0) == 0 && SyncSceneMotion.dropOpacity(0.4) > 0.8 && SyncSceneMotion.dropOpacity(1) == 0)
    }
}
