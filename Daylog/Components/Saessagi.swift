import SwiftUI

/// Daylog의 캐릭터 "새싹이"의 모습. 그림은 `Assets.xcassets/Saessagi`의 1024×1024 투명 PNG다(받은 원본 그대로).
/// idle·happy·rest는 작은 크기에서도 또렷하게 보이도록 선을 굵게 그린 판이고, 나머지는 v2다.
enum SaessagiPose: String, CaseIterable, Sendable {
    /// 기본: 웃으며 서 있다.
    case idle
    /// 기쁨: 두 팔을 들었다.
    case happy
    /// 응원: "파이팅!" 팻말.
    case cheer
    /// 휴식: 엎드려 쉰다.
    case rest
    /// 수면: 베개 위에서 잔다.
    case sleep
    /// 다시 시작: 손을 흔든다.
    case welcome

    var assetName: String { "saessagi_\(rawValue)" }

    /// 그림 안에서 캐릭터가 실제로 차지하는 자리(1024 기준 픽셀, 위에서 아래로. 반짝이·하트 같은 소품과 발밑 그림자 포함).
    /// 모습마다 캔버스 안의 위치와 크기가 달라서, 이 값으로 가운데·바닥을 맞춘다. 파일은 건드리지 않는다.
    var content: CGRect {
        switch self {
        case .idle: return CGRect(x: 179, y: 53, width: 664, height: 911)
        case .happy: return CGRect(x: 106, y: 50, width: 813, height: 915)
        case .cheer: return CGRect(x: 112, y: 110, width: 778, height: 804)
        case .rest: return CGRect(x: 55, y: 135, width: 915, height: 833)
        case .sleep: return CGRect(x: 110, y: 151, width: 804, height: 722)
        case .welcome: return CGRect(x: 128, y: 110, width: 768, height: 803)
        }
    }

    static let canvas: CGFloat = 1024
    /// 틀의 한 변에 맞출 길이(그림 픽셀): 캐릭터가 차지하는 자리의 긴 변. 그림마다 캔버스를 채우는 정도가 달라서
    /// (선이 굵은 판은 더 꽉 차 있다) 모습마다 따로 잡는다. 어느 모습이든 틀에 꼭 맞게 들어가 화면에서의 크기가 같다.
    var fitted: CGFloat { max(content.width, content.height) }
}

/// 새싹이 한 장. `size`의 정사각형 안에 가로 가운데·바닥 정렬로 그린다. 꾸밈이라 접근성 요소에서 뺀다.
///
/// 오늘 화면의 인사말 옆에서 쓰고, 앞으로 주간 성장·다시 시작 같은 화면에서도 이 뷰를 그대로 쓴다.
///
/// 그림은 1024픽셀인데 화면에서는 36~60pt로 작다. 그릴 때마다 큰 그림을 그대로 줄이면 선이 빠져 외곽선이 끊겨 보인다
/// (1배율 Mac 화면에서 특히). 그래서 표시 크기와 화면 배율에 딱 맞는 그림을 한 번 만들어 두고(`SaessagiRenderer`) 픽셀 그대로 그린다.
struct SaessagiView: View {
    let pose: SaessagiPose
    var size: CGFloat = 48
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Group {
            if let image = SaessagiRenderer.image(pose: pose, size: size, displayScale: displayScale) {
                // 만들어 둔 그림은 틀보다 사방으로 `padding`만큼 크다. 가운데에 두면 캐릭터의 발밑이 틀의 바닥에 온다.
                Image(decorative: image, scale: displayScale)
            } else {
                resized
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// 그림을 만들지 못했을 때만 쓰는 예전 방식: 원본을 그리는 자리에서 줄인다.
    private var resized: some View {
        let scale = size / pose.fitted
        let content = pose.content
        let center = SaessagiPose.canvas / 2
        return Image(pose.assetName)
            .resizable()
            .interpolation(.high)
            .frame(width: SaessagiPose.canvas * scale, height: SaessagiPose.canvas * scale)
            // 캐릭터의 가로 가운데를 틀의 가운데로, 발밑을 틀의 바닥으로 옮긴다.
            .offset(x: (center - content.midX) * scale, y: size / 2 - (content.maxY - center) * scale)
    }
}

/// 오늘 화면의 새싹이가 잠깐 보이는 반응.
enum SaessagiReaction: Equatable, Sendable {
    /// 루틴을 완료했다: 기뻐하며 한 번 통통 뛴다.
    case completed
    /// 루틴을 건너뛰었다: 잠깐 쉬는 모습이 된다.
    case skipped

    var pose: SaessagiPose {
        switch self {
        case .completed: return .happy
        case .skipped: return .rest
        }
    }

    /// 반응한 모습으로 머무는 시간(초).
    var duration: Double {
        switch self {
        case .completed: return 1.6
        case .skipped: return 2.0
        }
    }
}

/// 보고 있는 날짜의 진행 상황 가운데 새싹이가 보는 값. 저장하지 않고 화면의 체크 목록에서 그때그때 센다.
struct SaessagiProgress: Equatable, Sendable {
    var day: Day
    var done: Int
    var skipped: Int
}

/// 새싹이가 어떤 모습을 할지 정하는 규칙. 이미 있는 값(휴가 여부, 완료·건너뜀 개수)에서 계산만 한다.
enum SaessagiMood {
    /// 평소의 모습: 휴가인 날은 쉬고, 그 밖에는 웃으며 서 있다.
    static func base(isVacation: Bool) -> SaessagiPose {
        isVacation ? .rest : .idle
    }

    /// 진행 상황이 바뀌었을 때의 반응. 날짜를 옮겨서 개수가 달라진 것에는 반응하지 않는다.
    static func reaction(from old: SaessagiProgress, to new: SaessagiProgress) -> SaessagiReaction? {
        guard old.day == new.day else { return nil }
        if new.done > old.done { return .completed }
        if new.skipped > old.skipped { return .skipped }
        return nil
    }
}

/// 오늘 화면 인사말 옆의 새싹이: 평소에는 숨 쉬고 깜빡이다가 가끔 걷거나 두리번거리거나 폴짝 뛰거나 졸고,
/// 루틴을 완료하거나 건너뛰면 하던 것을 멈추고 잠깐 반응한다.
///
/// 가로로 `walkRange`만큼까지 늘어나는 자리를 차지한다(자리가 남을 때만). 그 안에서만 걸어 다닌다.
/// 놓는 쪽에서 `.layoutPriority(-1)`을 주어 글자나 단추의 자리를 빼앗지 않게 한다.
struct TodaySaessagi: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var size: CGFloat = 48
    /// 걸어 다닐 수 있는 최대 거리(pt).
    var walkRange: CGFloat = 60
    /// 줄에 남는 가로 자리를 모두 차지할지. 빈칸(Spacer) 대신 놓을 때 켠다: 걷는 거리는 그래도 `walkRange`까지다.
    var fillsWidth = false
    /// 서 있던 자리. 반응 그림을 그 자리에 놓고, 끝나면 평소 모습도 거기서 다시 시작한다.
    @State private var awayX: CGFloat = 0
    @State private var link = SaessagiStageLink()
    @State private var reaction: SaessagiReaction?
    /// 통통 뛸 때 위로 뜬 높이.
    @State private var lift: CGFloat = 0
    @State private var pending: Task<Void, Never>?

    private var progress: SaessagiProgress {
        SaessagiProgress(
            day: store.selectedDay,
            done: store.checkSections.reduce(0) { $0 + $1.done },
            skipped: store.checkSections.reduce(0) { $0 + $1.skipped }
        )
    }

    private var pose: SaessagiPose {
        reaction?.pose ?? SaessagiMood.base(isVacation: store.isVacation(on: store.selectedDay))
    }

    /// 걸어 다니는 날인가: 움직임 줄이기를 켰거나 휴가인 날(쉬는 모습)에는 자리를 늘리지 않는다.
    private var canWalk: Bool {
        !reduceMotion && !store.isVacation(on: store.selectedDay)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Group {
                // 평소 모습일 때만 살아 움직인다. 반응(기쁨·휴식)이 시작되면 그 그림으로 바뀌며 움직임도 멈춘다.
                if pose == .idle {
                    SaessagiAnimatedView(
                        pose: .idle, size: size, behavior: .today, fillsLane: true, maxRange: walkRange,
                        startX: canWalk ? awayX : 0, link: link
                    )
                } else {
                    // 기쁨은 통통 뛰고, 휴식(건너뛰기·휴가)은 느리게 숨 쉬며 가끔 꿈틀한다.
                    SaessagiAnimatedView(pose: pose, size: size)
                        .offset(x: canWalk ? awayX : 0)
                }
            }
            .id(pose)
            .transition(reduceMotion ? .identity : .opacity)
        }
        .offset(y: lift)
        .frame(
            minWidth: size, idealWidth: size, maxWidth: fillsWidth ? .infinity : size + (canWalk ? walkRange : 0),
            alignment: .leading
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: pose)
        .onChange(of: progress) { old, new in
            if let next = SaessagiMood.reaction(from: old, to: new) { react(next) }
        }
        .onDisappear { pending?.cancel() }
    }

    private func react(_ next: SaessagiReaction) {
        pending?.cancel()
        // 걷던 중이었으면 그 자리에서 반응한다(평소 모습이 떠 있을 때만 위치를 알 수 있다).
        if let offset = link.currentOffset() { awayX = max(offset, 0) }
        reaction = next
        // 앞의 반응이 뛰던 중이었으면 제자리에서 다시 시작한다.
        lift = 0
        pending = Task {
            if next == .completed, !reduceMotion {
                // 한 번 통통: 살짝 떴다가 제자리로 튕겨 내려온다.
                withAnimation(.easeOut(duration: 0.14)) { lift = -size * 0.16 }
                try? await Task.sleep(for: .milliseconds(140))
                guard !Task.isCancelled else { return }
                withAnimation(.interpolatingSpring(stiffness: 320, damping: 11)) { lift = 0 }
            }
            try? await Task.sleep(for: .seconds(next.duration))
            guard !Task.isCancelled else { return }
            reaction = nil
        }
    }
}
