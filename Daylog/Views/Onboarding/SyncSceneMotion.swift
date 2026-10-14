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
    /// 발밑을 기준으로 한 가로·세로 배율.
    var squashX = 1.0
    var squashY = 1.0
    /// 몸통(몸·얼굴·잎·수첩)이 다리 사이를 중심으로 기운 각도.
    var tilt = 0.0
    /// 잎이 더 기운 각도.
    var leaf = 0.0
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
                    arrived = max(arrived ?? -1, t - (start + cardFall))
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
        pose.leaf += 5 * wave(t, 2.6)
        pose.squashY *= 1 + 0.012 * wave(t, 3.2)
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
        if !hopping {
            let after = t - (readyHops[readyHops.count - 1].start + hopDuration)
            if after > 0 {
                // 마지막 착지 뒤 잎이 잦아들고, 그 뒤로는 잔잔하게 몸을 흔들며 숨 쉰다.
                pose.leaf = -6 * exp(-after * 3) * cos(after * 9) + 4 * wave(t, 2.6) * min(1, after)
                pose.tilt = 2.5 * wave(t, 3.6) * min(1, after / 1.5)
                pose.squashY = 1 + 0.012 * wave(t, 3)
                pose.eyes = blink(t, period: 3.4, offset: 0.4)
            } else {
                pose.leaf = 4 * wave(t, 2.6)
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
        pose.leaf = keys(droop, [(0, 0), (0.5, 17), (1.9, 17), (2.2, -6), (2.45, 3), (2.7, 0)]) + 2 * wave(t, 2.9)
        pose.squashY = 1 + 0.01 * wave(t, 3.4)
        pose.eyes = blink(t, period: 3.3, offset: 0.7)
        frame.saessagi = pose
        // 물음표: 머리 위에 톡 나타나 흔들리다 사라진다.
        let ask = (t - 0.6 + 4.6).truncatingRemainder(dividingBy: 4.6)
        frame.question = t < 0.6 ? 0 : keys(ask, [(0, 0), (0.2, 1.15), (0.32, 1), (1.9, 1), (2.3, 0)])
        frame.questionTilt = ask < 2.3 ? 8 * wave(ask, 0.9) * max(0, 1 - ask / 2.3) : 0
        return frame
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
