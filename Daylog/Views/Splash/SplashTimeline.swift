import Foundation

/// 스플래시의 장면 순서와 시간. 화면(`SplashView`)은 이 표대로만 움직인다.
///
/// 시스템 Launch Screen(정적: 배경색 + 한가운데의 작은 잎사귀)에서 이어진다. 첫 장면은 Launch Screen과 같은 그림이다.
/// 저장소는 화면이 뜨기 전에 이미 열려 있으므로(`AppLaunch.make`), 스플래시는 앱의 준비를 기다리게 하지 않는다.
/// 밑에서는 실제 화면이 이미 그려져 있고, 스플래시는 그 위를 덮었다가 걷힐 뿐이다.
struct SplashTimeline: Equatable {
    enum Stage: Int, CaseIterable, Comparable {
        /// Launch Screen과 같은 장면: 한가운데의 작은 잎사귀.
        case start
        /// 잎사귀가 살짝 커지고 잔잔한 원이 퍼진다.
        case grown
        /// 잎사귀가 자리를 잡고 "Daylog"와 한 줄 문구가 나타난다.
        case logo
        /// 잎사귀가 가볍게 흔들리다 멈춘다.
        case settled
        /// 스플래시가 걷히고 실제 화면이 드러난다.
        case leaving

        static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// 한 장면: 시작 시각(스플래시 시작부터, 초)과 그 장면으로 넘어가는 애니메이션의 길이.
    struct Step: Equatable {
        let stage: Stage
        let at: Double
        let duration: Double
    }

    let steps: [Step]
    /// 동작 줄이기: 커지거나 움직이지 않고, 글자만 나타났다가 화면째로 걷힌다.
    let reducesMotion: Bool

    static let standard = SplashTimeline(
        steps: [
            Step(stage: .grown, at: 0.02, duration: 0.26),
            Step(stage: .logo, at: 0.24, duration: 0.34),
            Step(stage: .settled, at: 0.58, duration: 0.20),
            // 이름과 문구가 다 보인 뒤(약 0.64초) 1.5초 더 두고 걷힌다.
            Step(stage: .leaving, at: 2.14, duration: 0.28)
        ],
        reducesMotion: false
    )

    static let reduced = SplashTimeline(
        steps: [
            Step(stage: .logo, at: 0.04, duration: 0.20),
            // 움직임은 없지만, 글자는 1초 넘게 읽고 걷힌다.
            Step(stage: .leaving, at: 1.50, duration: 0.22)
        ],
        reducesMotion: true
    )

    static func make(reduceMotion: Bool) -> SplashTimeline { reduceMotion ? reduced : standard }

    /// 스플래시가 완전히 걷히는 시각(초).
    var total: Double { steps.last.map { $0.at + $0.duration } ?? 0 }
    /// 잎사귀가 올라가기 시작한 뒤 이름이 나타나기 시작할 때까지의 간격.
    static let titleDelay: Double = 0.12
    /// 이름과 문구가 다 나타나 읽을 수 있는 시각.
    var logoVisibleAt: Double {
        guard let logo = steps.first(where: { $0.stage == .logo }) else { return 0 }
        return logo.at + (reducesMotion ? 0.06 : Self.titleDelay + 0.08) + 0.20
    }

    /// 화면이 보이지 않아(백그라운드) 시작하지 못한 스플래시를 기다려 주는 시간. 이 뒤에는 애니메이션 없이 걷는다
    /// (알림의 [완료]처럼 화면 없이 실행된 경우에 스플래시가 남아 다음 진입을 막지 않게).
    static let startGrace: Double = 1.5
}

/// 스플래시를 틀지 말지. 프로세스가 시작한 뒤 처음 뜨는 화면에서 한 번만 튼다.
/// 백그라운드에서 돌아올 때나 iPad의 두 번째 창에서는 틀지 않는다.
@MainActor
enum SplashPolicy {
    private(set) static var hasClaimed = false
    /// 첫 화면이 만들어진 시각(시스템 가동 시간, 초). 개발 중 시간 확인에 쓴다.
    private(set) static var claimedAt: TimeInterval = 0

    /// 이 화면이 스플래시를 틀 차례면 true. 한 번 true를 돌려준 뒤에는 늘 false다.
    static func claim(isRunningTests: Bool = RuntimeEnvironment.isRunningTests) -> Bool {
        #if DEBUG
        // 화면 검증·시간 비교용: `-DaylogDebugSplash off`로 실행하면 스플래시 없이 뜬다.
        if UserDefaults.standard.string(forKey: "DaylogDebugSplash") == "off" { return false }
        #endif
        guard !isRunningTests, !hasClaimed else { return false }
        hasClaimed = true
        claimedAt = ProcessInfo.processInfo.systemUptime
        return true
    }

    /// 테스트에서 처음 상태로 되돌린다.
    static func resetForTesting() { hasClaimed = false }
}
