import CoreGraphics
import Foundation

/// 첫 동기화 화면의 세 가지 장면. 실제 첫 동기화와 설정의 미리보기가 같은 장면을 쓴다.
enum SyncSceneKind: String, CaseIterable, Identifiable, Sendable {
    /// 기록 받는 중: 구름에서 기록 카드가 내려오고 새싹이가 수첩에 정리한다.
    case receiving
    /// 준비 완료: 체크 표시가 통통 자리 잡고 새싹이가 수첩을 안고 두 번 뛴다.
    case ready
    /// 연결 문제: 회색 구름에서 빗방울이 몇 개 떨어지고 새싹이가 올려다보며 갸웃거린다.
    case trouble

    var id: String { rawValue }

    /// 화면에 보일 장면. 실제 첫 동기화에서는 기록을 찾은 순간 곧바로 오늘 화면으로 넘어가므로
    /// `ready`는 미리보기에서만 쓴다(완료를 추측해서 보여 주지 않는다).
    init(_ phase: FirstSyncPhase, isPreview: Bool) {
        switch phase {
        case .found where isPreview: self = .ready
        case .waiting, .found, .empty: self = .receiving
        case .unavailable, .stalled: self = .trouble
        }
    }
}

/// 새싹이 한 순간의 자세. 길이는 새싹이 키에 대한 비율, 각도는 도(오른쪽으로 기울면 양수).
struct SyncSaessagiPose: Equatable, Sendable {
    /// 바닥에서 뜬 높이.
    var lift = 0.0
    /// 발밑을 기준으로 한 가로·세로 배율(끄덕임·점프의 눌림).
    var squashX = 1.0
    var squashY = 1.0
    /// 숨쉬기: 발밑을 기준으로 한 세로 배율. 눌림과 주기가 달라 따로 둔다(화면에서는 곱해진다).
    var breath = 1.0
    /// 몸통(몸·얼굴·잎·수첩)이 다리 사이를 중심으로 기운 각도.
    var tilt = 0.0
    /// 잎이 더 기운 각도(행동에 따른 흔들림)와 늘 하는 살랑임. 화면에서는 더해진다.
    var leaf = 0.0
    var leafSway = 0.0
    /// 눈의 세로 배율(1 = 뜬 눈).
    var eyes = 1.0
    /// 눈과 입이 옮겨 간 거리(아래·오른쪽이 양수).
    var faceX = 0.0
    var faceY = 0.0
    /// 수첩이 몸에서 더 들린 높이.
    var bookLift = 0.0
}

/// 내려오는 기록 카드 한 장.
struct SyncFallingCard: Equatable, Sendable {
    enum Kind: Int, CaseIterable, Sendable { case check, calendar, routine, chart }
    var kind: Kind
    /// 0(구름 밑)…1(수첩).
    var progress: Double
    /// 출발할 때 가로 위치(장면 단위, 가운데 0).
    var startX: Double
}

/// 한 순간의 장면 전체.
struct SyncSceneFrame: Equatable, Sendable {
    var saessagi = SyncSaessagiPose()
    /// 구름의 위아래·좌우 흔들림(장면 단위)과 빛.
    var cloudX = 0.0
    var cloudY = 0.0
    var glow = 0.0
    /// 기록 받는 중: 내려오는 카드, 수첩의 반짝임(0…1), 넘어가는 쪽(0…1, 0이면 넘기지 않음).
    var cards: [SyncFallingCard] = []
    var bookSparkle = 0.0
    var pageFlip = 0.0
    /// 준비 완료: 체크 표시의 크기, 별의 크기와 밝기(각각 0…1).
    var check = 0.0
    var stars: [Double] = []
    /// 연결 문제: 떨어지는 빗방울(0…1)과 물음표의 크기·기울기.
    var drops: [Double] = []
    var question = 0.0
    var questionTilt = 0.0
}

/// 시각 `t`(초, 장면이 나타난 때가 0)의 장면을 계산한다. 화면은 이 값대로 그리기만 한다.
///
/// 기록 카드는 실제로 받은 기록의 수와 상관없는 그림이다. 같은 박자로 되풀이되고, 동시에 두 장보다 많이 떠 있지 않다.
enum SyncSceneMotion {
    /// 기록 카드: 이 간격으로 하나씩, 이만큼 걸려 내려온다.
    static let cardInterval = 1.3
    static let cardFall = 2.3
    static let firstCard = 0.4
    /// 카드가 출발하는 가로 위치(장면 단위). 차례대로 쓴다.
    static let cardStarts: [Double] = [-34, 28, -12, 40]
    /// 카드가 내려오는 길: 머리 옆으로 비켜 이 가로 거리(장면 단위)를 따라 내려온다(얼굴을 가리지 않는다).
    static let cardLane = 76.0
    /// 준비 완료에서 두 번 뛰는 시각과 한 번 뛰는 시간.
    static let readyHops: [(start: Double, height: Double)] = [(0.9, 0.17), (1.6, 0.24)]
    static let hopDuration = 0.72
    /// 연결 문제: 빗방울 세 개가 이 주기로 돌아가며 이만큼 걸려 떨어진다.
    static let dropPeriod = 2.7
    static let dropFall = 1.5
    static let dropCount = 3
    /// 움직임 줄이기: 이 시각의 장면을 멈춘 그림으로 보여 준다.
    static func stillTime(_ kind: SyncSceneKind) -> Double {
        switch kind {
        case .receiving: return firstCard + cardFall * 0.45
        case .ready: return 4
        case .trouble: return 1.4
        }
    }

    static func frame(_ kind: SyncSceneKind, at t: Double) -> SyncSceneFrame {
        switch kind {
        case .receiving: return receiving(t)
        case .ready: return ready(t)
        case .trouble: return trouble(t)
        }
    }

    // MARK: - 기록 받는 중

    static func receiving(_ t: Double) -> SyncSceneFrame {
        var frame = SyncSceneFrame()
        frame.cloudY = 4 * wave(t, 4.2)
        frame.glow = 0.6 + 0.3 * wave(t, 3)

        // 카드: 지금 떠 있는 것(출발했고 아직 수첩에 닿지 않은 것)만.
        let latest = Int(floor((t - firstCard) / cardInterval))
        var arrived: Double?
        if latest >= 0 {
            for index in max(0, latest - 2)...latest {
                let start = firstCard + Double(index) * cardInterval
                let progress = (t - start) / cardFall
                if progress >= 0 && progress < 1 {
                    frame.cards.append(SyncFallingCard(
                        kind: SyncFallingCard.Kind(rawValue: index % 4)!, progress: progress,
                        startX: cardStarts[index % cardStarts.count]
                    ))
                } else if progress >= 1 {
                    // 가장 최근에 수첩에 닿은 카드.
                    arrived = min(arrived ?? .infinity, t - (start + cardFall))
                }
            }
        }

        var pose = SyncSaessagiPose()
        // 수첩을 내려다본다. 내려오는 카드 쪽으로 눈이 조금 따라간다.
        pose.faceY = 0.012
        if let card = frame.cards.max(by: { $0.progress < $1.progress }) {
            pose.faceX = (card.startX >= 0 ? 1 : -1) * 0.02 * (1 - card.progress)
        }
        // 카드가 수첩에 닿으면 고개를 끄덕이고(살짝 눌리며 눈을 내림) 수첩을 들썩이며, 수첩이 반짝인다.
        if let since = arrived, since < 0.5 {
            let bump = sin(.pi * since / 0.5)
            pose.squashY -= 0.035 * bump
            pose.squashX += 0.015 * bump
            pose.faceY += 0.022 * bump
            pose.leaf += 7 * bump
            pose.bookLift = 0.025 * bump
        }
        if let since = arrived, since < 0.45 {
            frame.bookSparkle = since < 0.15 ? since / 0.15 : 1 - (since - 0.15) / 0.3
        }
        // 가끔 쪽을 넘긴다.
        let flip = (t - 2.2).truncatingRemainder(dividingBy: 4.8)
        frame.pageFlip = t > 2.2 && flip < 0.65 ? smooth(flip / 0.65) : 0
        pose.leafSway = 5 * wave(t, 2.6)
        pose.breath = 1 + 0.012 * wave(t, 3.2)
        pose.eyes = blink(t, period: 3.7, offset: 1.1)
        frame.saessagi = pose
        return frame
    }

    // MARK: - 준비 완료

    static func ready(_ t: Double) -> SyncSceneFrame {
        var frame = SyncSceneFrame()
        // 체크: 작게 나타나 크게 부풀었다가 통통 자리 잡고, 그 뒤로는 천천히 숨 쉰다.
        frame.check = t < 1.05
            ? keys(t, [(0.15, 0), (0.5, 1.16), (0.68, 0.93), (0.86, 1.04), (1.05, 1)])
            : 1 + 0.025 * wave(t - 1.05, 2.8)
        frame.glow = min(1, max(0, (t - 0.2) / 0.6)) * (0.75 + 0.25 * wave(t, 3.4))
        // 별: 한 번 터지듯 나타났다가 잔잔하게 반짝인다.
        frame.stars = (0..<6).map { index in
            let appear = 0.45 + Double(index) * 0.09
            guard t > appear else { return 0 }
            let burst = keys(t - appear, [(0, 0), (0.3, 1.2), (0.55, 1)])
            let calm = 0.55 + 0.35 * wave(t + Double(index) * 0.7, 2.2)
            let settle = min(1, max(0, (t - appear - 0.9) / 0.8))
            return burst * (1 - settle) + calm * settle
        }
        var pose = SyncSaessagiPose()
        var hopping = false
        for hop in readyHops {
            let local = t - hop.start
            guard local >= 0, local < hopDuration else { continue }
            hopping = true
            pose.lift = keys(local, [(0.1, 0), (0.22, 0.65), (0.32, 1), (0.42, 0.65), (0.52, 0)]) * hop.height
            pose.squashX = keys(local, [(0, 1), (0.1, 1.07), (0.22, 0.95), (0.32, 1), (0.5, 0.98), (0.58, 1.1), (0.7, 1)])
            pose.squashY = keys(local, [(0, 1), (0.1, 0.9), (0.22, 1.08), (0.32, 1), (0.5, 1.03), (0.58, 0.87), (0.7, 1)])
            // 잎은 한 박자 늦게 따라 흔들린다.
            pose.leaf = keys(local, [(0.12, 0), (0.24, -9), (0.42, 4), (0.6, 14), (0.72, -6)])
            // 신나서 눈을 가늘게 뜬다.
            pose.eyes = 0.6
        }
        pose.leafSway = 4 * wave(t, 2.6)
        if !hopping {
            let after = t - (readyHops[readyHops.count - 1].start + hopDuration)
            if after > 0 {
                // 마지막 착지 뒤 잎이 잦아들고, 그 뒤로는 잔잔하게 몸을 흔들며 숨 쉰다.
                pose.leaf = -6 * exp(-after * 3) * cos(after * 9)
                pose.tilt = 2.5 * wave(t, 3.6) * min(1, after / 1.5)
                pose.breath = 1 + 0.012 * wave(t, 3) * min(1, after)
                pose.eyes = blink(t, period: 3.4, offset: 0.4)
            }
        }
        frame.saessagi = pose
        return frame
    }

    // MARK: - 연결 문제

    static func trouble(_ t: Double) -> SyncSceneFrame {
        var frame = SyncSceneFrame()
        frame.cloudX = 14 * wave(t, 6.5)
        frame.cloudY = 3 * wave(t, 4)
        // 빗방울: 몇 개만 천천히. 떨어지지 않는 동안은 0.
        frame.drops = (0..<dropCount).map { index in
            let local = (t + dropPeriod - Double(index) * dropPeriod / Double(dropCount)).truncatingRemainder(dividingBy: dropPeriod)
            return local < dropFall ? local / dropFall : 0
        }
        var pose = SyncSaessagiPose()
        // 구름을 올려다보며 고개를 갸웃(왼쪽으로 한 번, 오른쪽으로 한 번).
        pose.faceY = -0.028
        pose.faceX = 0.006 * wave(t, 6.5)
        let cycle = t.truncatingRemainder(dividingBy: 5.2)
        pose.tilt = keys(cycle, [(0, 0), (0.6, -7), (1.8, -7), (2.4, 0), (3.0, 5), (3.9, 5), (4.5, 0)])
        // 잎이 축 처졌다가 톡 원래대로.
        let droop = (t + 4).truncatingRemainder(dividingBy: 5.2)
        pose.leaf = keys(droop, [(0, 0), (0.5, 17), (1.9, 17), (2.2, -6), (2.45, 3), (2.7, 0)])
        pose.leafSway = 2 * wave(t, 2.9)
        pose.breath = 1 + 0.01 * wave(t, 3.4)
        pose.eyes = blink(t, period: 3.3, offset: 0.7)
        frame.saessagi = pose
        // 물음표: 머리 위에 톡 나타나 흔들리다 사라진다.
        let ask = (t - 0.6 + 4.6).truncatingRemainder(dividingBy: 4.6)
        frame.question = t < 0.6 ? 0 : keys(ask, [(0, 0), (0.2, 1.15), (0.32, 1), (1.9, 1), (2.3, 0)])
        frame.questionTilt = ask < 2.3 ? 8 * wave(ask, 0.9) * max(0, 1 - ask / 2.3) : 0
        return frame
    }

    // MARK: - 되풀이(Core Animation으로 넘길 때)

    /// 장면의 값 하나. 화면은 값마다 레이어 애니메이션 하나(또는 둘)를 건다.
    enum Property: Hashable, Sendable {
        case cloudX, cloudY, glow, bookSparkle, pageFlip, check, question, questionTilt
        /// 기록 카드 한 종류(0…3)의 진행(내려오지 않을 때는 -1), 별 하나의 크기, 빗방울 하나의 진행.
        case card(Int), star(Int), drop(Int)
        case lift, squashX, squashY, breath, tilt, leaf, leafSway, eyes, faceX, faceY, bookLift
    }

    /// 값이 어떻게 되풀이되는가: 처음 `intro`초 뒤로는 `period`초마다 같은 값. `period`가 nil이면 그 뒤로 변하지 않는다.
    struct Loop: Equatable, Sendable {
        var intro: Double
        var period: Double?
    }

    /// 그 장면에서 움직이는 값들.
    static func properties(_ kind: SyncSceneKind) -> [Property] {
        let saessagi: [Property] = [.lift, .squashX, .squashY, .breath, .tilt, .leaf, .leafSway, .eyes, .faceX, .faceY]
        switch kind {
        case .receiving:
            return [.cloudY, .glow, .bookSparkle, .pageFlip, .bookLift] + (0..<4).map(Property.card) + saessagi
        case .ready:
            return [.glow, .check] + (0..<6).map(Property.star) + saessagi
        case .trouble:
            return [.cloudX, .cloudY, .question, .questionTilt] + (0..<dropCount).map(Property.drop) + saessagi
        }
    }

    /// 한 순간의 그 값.
    static func value(_ property: Property, _ kind: SyncSceneKind, at t: Double) -> Double {
        if case .card(let index) = property { return cardProgress(index, at: t) ?? -1 }
        let frame = frame(kind, at: t)
        let pose = frame.saessagi
        switch property {
        case .cloudX: return frame.cloudX
        case .cloudY: return frame.cloudY
        case .glow: return frame.glow
        case .bookSparkle: return frame.bookSparkle
        case .pageFlip: return frame.pageFlip
        case .check: return frame.check
        case .question: return frame.question
        case .questionTilt: return frame.questionTilt
        case .card: return -1
        case .star(let index): return index < frame.stars.count ? frame.stars[index] : 0
        case .drop(let index): return index < frame.drops.count ? frame.drops[index] : 0
        case .lift: return pose.lift
        case .squashX: return pose.squashX
        case .squashY: return pose.squashY
        case .breath: return pose.breath
        case .tilt: return pose.tilt
        case .leaf: return pose.leaf
        case .leafSway: return pose.leafSway
        case .eyes: return pose.eyes
        case .faceX: return pose.faceX
        case .faceY: return pose.faceY
        case .bookLift: return pose.bookLift
        }
    }

    /// 카드 한 종류(0…3)가 지금 내려오는 중이면 그 진행(0…1). 종류마다 `cardInterval` × 4초마다 한 번 내려온다.
    static func cardProgress(_ index: Int, at t: Double) -> Double? {
        let cycle = cardInterval * Double(cardStarts.count)
        let local = t - firstCard - Double(index) * cardInterval
        guard local >= 0 else { return nil }
        let progress = local.truncatingRemainder(dividingBy: cycle) / cardFall
        return progress < 1 ? progress : nil
    }

    /// 그 값이 되풀이되는 방식(테스트가 실제 값으로 확인한다).
    static func loop(_ property: Property, _ kind: SyncSceneKind) -> Loop {
        let arrival = firstCard + cardFall
        let cardCycle = cardInterval * Double(cardStarts.count)
        let settled = readyHops[readyHops.count - 1].start + hopDuration + 2.2
        switch (kind, property) {
        case (.receiving, .cloudY): return Loop(intro: 0, period: 4.2)
        case (.receiving, .glow): return Loop(intro: 0, period: 3)
        case (.receiving, .card(let index)): return Loop(intro: firstCard + Double(index) * cardInterval, period: cardCycle)
        case (.receiving, .bookSparkle), (.receiving, .bookLift), (.receiving, .squashX), (.receiving, .squashY),
             (.receiving, .faceY):
            return Loop(intro: arrival, period: cardInterval)
        case (.receiving, .leaf): return Loop(intro: arrival, period: cardInterval)
        case (.receiving, .faceX): return Loop(intro: firstCard + 3 * cardInterval, period: cardCycle)
        case (.receiving, .pageFlip): return Loop(intro: 2.2, period: 4.8)
        case (.receiving, .leafSway): return Loop(intro: 0, period: 2.6)
        case (.receiving, .breath): return Loop(intro: 0, period: 3.2)
        case (.receiving, .eyes): return Loop(intro: 0, period: 3.7)
        case (.ready, .check): return Loop(intro: 1.05, period: 2.8)
        case (.ready, .glow): return Loop(intro: 0.8, period: 3.4)
        case (.ready, .star(let index)): return Loop(intro: 0.45 + Double(index) * 0.09 + 1.7, period: 2.2)
        case (.ready, .leafSway): return Loop(intro: 0, period: 2.6)
        case (.ready, .tilt): return Loop(intro: settled, period: 3.6)
        case (.ready, .breath): return Loop(intro: settled, period: 3)
        case (.ready, .eyes): return Loop(intro: settled, period: 3.4)
        case (.ready, .leaf): return Loop(intro: settled + 1, period: nil)
        case (.ready, _): return Loop(intro: settled, period: nil)
        case (.trouble, .cloudX), (.trouble, .faceX): return Loop(intro: 0, period: 6.5)
        case (.trouble, .cloudY): return Loop(intro: 0, period: 4)
        case (.trouble, .drop): return Loop(intro: 0, period: dropPeriod)
        case (.trouble, .tilt), (.trouble, .leaf): return Loop(intro: 0, period: 5.2)
        case (.trouble, .leafSway): return Loop(intro: 0, period: 2.9)
        case (.trouble, .breath): return Loop(intro: 0, period: 3.4)
        case (.trouble, .eyes): return Loop(intro: 0, period: 3.3)
        case (.trouble, .question), (.trouble, .questionTilt): return Loop(intro: 0.6, period: 4.6)
        default: return Loop(intro: 0, period: nil)
        }
    }

    /// 내려오는 카드 한 장의 자리(장면 단위, 가운데 위가 원점, 카드의 가운데)와 기울기·크기·불투명도.
    /// 구름 밑에서 출발해 머리 옆(출발한 쪽)으로 비켜 살랑이며 내려오다가, 끝에 수첩 쪽으로 들어가며 작아지고 사라진다(얼굴 앞을 지나지 않는다).
    static func cardPlacement(progress p: Double, startX: Double, book: CGPoint)
        -> (x: Double, y: Double, rotation: Double, scale: Double, opacity: Double) {
        guard p >= 0, p < 1 else { return (startX, cardTop, 0, 1, 0) }
        let side = (startX >= 0 ? 1.0 : -1.0) * cardLane
        let x: Double = if p < 0.3 {
            startX + (side - startX) * smooth(p / 0.3)
        } else if p < 0.72 {
            side + sin(p * 2 * .pi * 1.5) * 7
        } else {
            side + (Double(book.x) - side) * smooth((p - 0.72) / 0.28)
        }
        let top = cardTop + (Double(book.y) - 24 - cardTop) * pow(p, 1.15)
        let fadeIn = min(1, p / 0.12)
        let fadeOut = p > 0.84 ? max(0, 1 - (p - 0.84) / 0.16) : 1
        let scale = p > 0.78 ? 1 - (p - 0.78) / 0.22 * 0.5 : 1
        return (x, top + cardHeight / 2, sin(p * 2 * .pi * 1.1) * 12 * (1 - p), scale, fadeIn * fadeOut)
    }

    /// 카드가 출발하는 높이(카드 위쪽)와 카드의 높이(장면 단위).
    static let cardTop = 112.0
    static let cardHeight = 36.0
    /// 빗방울이 떨어지는 거리(장면 단위)와 불투명도.
    static let dropDistance = 72.0
    static func dropOpacity(_ progress: Double) -> Double {
        guard progress > 0 else { return 0 }
        let fade = progress < 0.15 ? progress / 0.15 : max(0, 1 - (progress - 0.6) / 0.4)
        return min(fade, 1) * 0.85
    }

    // MARK: - 도움 함수

    /// 사인 파: 주기 `period`초, -1…1.
    static func wave(_ t: Double, _ period: Double) -> Double { sin(2 * .pi * t / period) }

    /// 부드럽게 0에서 1로.
    static func smooth(_ x: Double) -> Double {
        let x = min(max(x, 0), 1)
        return x * x * (3 - 2 * x)
    }

    /// 키프레임 사이를 부드럽게 잇는다. 첫 시각 전은 첫 값, 마지막 시각 뒤는 마지막 값.
    static func keys(_ t: Double, _ points: [(Double, Double)]) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }
        if t <= first.0 { return first.1 }
        if t >= last.0 { return last.1 }
        for index in 1..<points.count where t <= points[index].0 {
            let (t0, v0) = points[index - 1], (t1, v1) = points[index]
            return v0 + (v1 - v0) * smooth((t - t0) / (t1 - t0))
        }
        return last.1
    }

    /// 눈 깜빡임: 주기마다 0.16초 동안 감았다 뜬다.
    static func blink(_ t: Double, period: Double, offset: Double) -> Double {
        let local = (t + period - offset).truncatingRemainder(dividingBy: period)
        guard local < 0.16 else { return 1 }
        return 1 - 0.9 * sin(.pi * local / 0.16)
    }
}
