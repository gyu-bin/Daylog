import CoreGraphics
import Foundation

/// 피오 시범(검증용 앱에서만): `-DaylogDebugCharacter pio`로 실행하면 머리말·성장 카드·스플래시를 피오로 그린다.
///
/// 시범일 뿐 실제 교체가 아니다: Release 빌드에서는 늘 꺼져 있고, 새싹이 원화·애니메이션·저장 값·XP·레벨 계산은 그대로 둔다.
/// 기본 피오는 마스터 좌표의 부위 리그로 움직이고, 예전 그림 비교 모드만 한 장짜리 그림을 쓴다.
enum PioTrial {
    static var isEnabled: Bool {
        #if DEBUG
        UserDefaults.standard.string(forKey: "DaylogDebugCharacter") == "pio"
        #else
        false
        #endif
    }

    /// 비교용(검증용 앱에서만): `-DaylogDebugPioArt v2`면 예전 저해상도 피오(2.5D 키트 v2, 실제 디테일 약 342px)를 그린다.
    static var usesOldArt: Bool {
        #if DEBUG
        UserDefaults.standard.string(forKey: "DaylogDebugPioArt") == "v2"
        #else
        false
        #endif
    }

    /// 기본 피오 그림과 그림 안에서 피오가 차지하는 자리(1024 기준, 위에서 아래로).
    /// 새 마스터(Pio_Style_Locked_Kit, 실제 1254px)는 1536 캔버스의 141,215–1369,1355에 있다.
    static var base: (asset: String, content: CGRect) {
        usesOldArt
            ? ("pio_idle_v2", CGRect(x: 208, y: 192, width: 608, height: 656))
            : ("pio_idle", CGRect(x: 94, y: 143, width: 819, height: 760))
    }

    /// 그림이 준비된 성장 단계. 4단계 그림이 준비될 때까지 그 레벨에서도 3단계를 보여 준다.
    static let implementedStages = 3

    /// 그 레벨에서 보일 성장 단계 그림(1…`implementedStages`). XP·레벨 계산은 그대로 쓰고 경계만 본다.
    static func artStage(level: Int) -> Int { min(stage(forLevel: level).number, implementedStages) }

    /// 2단계 이후 같은 몸통 어깨를 쓴다(1536 원본: 왼쪽480,995 / 오른쪽1056,995).
    /// 4단계도 이 배치를 재사용할 수 있지만, 전용 원화가 없으므로 실제 그림은 여전히3단계까지다.
    static func wingAttachment(stage: Int) -> SaessagiWingAttachment? {
        guard stage >= 2 else { return nil }
        return SaessagiWingAttachment(
            leftShoulder: CGPoint(x: 320, y: 995.0 / 1.5),
            rightShoulder: CGPoint(x: 704, y: 995.0 / 1.5),
            scale: stage == 2 ? 0.78 : 0.72
        )
    }

    /// 마스터를 부위로 나눈 레이어(`Tools/pio-rig`로 만든다, 모두 1536 캔버스·마스터와 같은 좌표).
    /// 기준점은 1024 기준 좌표(마스터 픽셀 × 2/3): 볏 밑동, 두 눈의 가운데, 다리 사이, 양 어깨.
    /// 성장 2단계부터 날개는 공통 몸통 어깨 뒤에 놓는다. 얼굴·몸·발과 원화 뿌리 좌표는 그대로다.
    /// 3단계는 승인된 날개와 새 볏·꼬리를 쓰며, 볏과 꼬리의 부착부는 몸 뒤에 놓는다.
    static func rigLayers(stage: Int = 1) -> SaessagiLayerSet? {
        guard isEnabled, !usesOldArt else { return nil }
        var set = SaessagiLayerSet(
            body: "pio_rig_body", leaf: stage >= 3 ? "pio_stage3_crest" : "pio_rig_crest", eyes: "pio_rig_eyes", mouth: nil,
            footLeft: "pio_rig_foot_left", footRight: "pio_rig_foot_right",
            leafPivot: CGPoint(x: 496.7, y: 392), eyeCenter: CGPoint(x: 512.8, y: 564.5), hip: CGPoint(x: 512, y: 820)
        )
        let wings = stage >= 2 ? "_2" : ""
        set.wingLeft = "pio_rig_wing_left" + wings
        set.wingRight = "pio_rig_wing_right" + wings
        set.wingShadowLeft = "pio_rig_wing_left_shadow" + wings
        set.wingShadowRight = "pio_rig_wing_right_shadow" + wings
        if stage >= 3 {
            set.wingLeft = "pio_stage3_wing_left"
            set.wingRight = "pio_stage3_wing_right"
            set.wingShadowLeft = nil
            set.wingShadowRight = nil
            set.leafBehindBody = true
            set.tailLeft = "pio_stage3_tail_left"
            set.tailRight = "pio_stage3_tail_right"
        }
        set.wingLeftPivot = CGPoint(x: 321.3, y: 626.7)
        set.wingRightPivot = CGPoint(x: 702.7, y: 626.7)
        set.wingAttachment = wingAttachment(stage: stage)
        if set.wingAttachment?.showsContactShadow == false {
            // 앞쪽 날개용 그림자를 뒤쪽 부착부에 재사용하면 볼에 오래된 자국이 남는다.
            set.wingShadowLeft = nil
            set.wingShadowRight = nil
        }
        // 발: 뒤꿈치 쪽(몸에 붙은 위쪽 가운데)을 중심으로 굴린다.
        set.footLeftPivot = CGPoint(x: 410, y: 828)
        set.footRightPivot = CGPoint(x: 612, y: 828)
        set.lidClosed = "pio_rig_lid_closed"
        set.lidHappy = "pio_rig_lid_happy"
        set.lidSleepy = "pio_rig_lid_sleepy"
        return set
    }

    /// 머리말 피오가 이번 실행에서 날개로 인사했는가(처음 나타날 때 한 번).
    @MainActor static var hasWaved = false
    /// 날개가 있는 피오의 머리말 제자리 동작: 새싹이의 비중에 날개로 인사하기·퍼덕이기를 더한다.
    static func flourishes(adding base: [SaessagiBehavior.Choice]) -> [SaessagiBehavior.Choice] {
        base + [SaessagiBehavior.Choice(action: .flap, weight: 3), SaessagiBehavior.Choice(action: .wave, weight: 2)]
    }

    /// 그 모습 대신 그릴 피오 그림. 시범이 꺼져 있으면 nil.
    /// 표정·자세 편집본은 품질이 모자라 쓰지 않는다: 인사·기쁨·휴식도 모두 기본 피오 한 장으로 그린다.
    static func art(for pose: SaessagiPose) -> (asset: String, content: CGRect)? {
        guard isEnabled else { return nil }
        switch pose {
        case .idle, .happy, .cheer, .welcome, .rest, .sleep: return base
        case .growthSprout, .growthLeaf, .growthFlower: return nil
        }
    }

    /// 성장 4단계(제안 경계, 시범에서만 보여 준다): Lv.1~9 기본, 10~24 활발, 25~49 든든, 50+ 특별. XP와 레벨 계산은 그대로다.
    struct Stage: Equatable {
        let number: Int
        let title: String
        let firstLevel: Int
        var asset: String { String(format: "pio_growth_%02d", number) }
    }

    static let stages = [
        Stage(number: 1, title: "기본 피오", firstLevel: 1),
        Stage(number: 2, title: "활발한 피오", firstLevel: 10),
        Stage(number: 3, title: "든든한 피오", firstLevel: 25),
        Stage(number: 4, title: "특별한 피오", firstLevel: 50),
    ]

    static func stage(forLevel level: Int) -> Stage {
        stages.last { level >= $0.firstLevel } ?? stages[0]
    }

    /// 성장 카드에 적는 단계 이름. 그림이 아직 없는 단계는 그렇다고 적는다.
    static func stageTitle(level: Int) -> String {
        let current = stage(forLevel: level)
        return current.number > implementedStages ? "\(current.title) · 그림 준비 중" : current.title
    }

    /// 다음 단계까지의 안내.
    static func nextStageNote(level: Int) -> String {
        let current = stage(forLevel: level)
        guard let next = stages.first(where: { $0.number == current.number + 1 }) else { return "피오가 가장 특별한 모습이에요." }
        return "Lv.\(next.firstLevel)에 \(next.title)가 돼요 · \(next.firstLevel - level)레벨 남음"
    }

    /// 한 장짜리 피오에서 레이어가 있어야 하는 제자리 동작을 대신할 동작(두리번 → 좌우로 흔들기 등).
    static func wholeImageSubstitute(for action: SaessagiAction) -> SaessagiAction {
        switch action {
        case .lookAround: return .sway
        case .leafShake: return .wave
        case .doze: return .wiggle
        default: return action
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI

/// 피오 시범의 스플래시(검증용 앱에서만): 키트의 전체 화면 그림(라이트·다크)을 잠시 보여 주고 걷힌다.
/// iPhone·iPad는 원래 스플래시 자리에, Mac은 실행할 때 한 번 창 위에 띄운다.
struct PioTrialSplash: View {
    var onLeaving: () -> Void = {}
    let onFinish: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isLeaving = false

    private var asset: String {
        let mode = colorScheme == .dark ? "dark" : "light"
        #if os(macOS)
        return "pio_splash_mac_\(mode)"
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? "pio_splash_ipad_\(mode)" : "pio_splash_iphone_\(mode)"
        #endif
    }

    var body: some View {
        GeometryReader { proxy in
            Image(asset)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .opacity(isLeaving ? 0 : 1)
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .seconds(1.8))
            onLeaving()
            withAnimation(.easeOut(duration: 0.45)) { isLeaving = true }
            try? await Task.sleep(for: .seconds(0.45))
            onFinish()
        }
    }
}

#if os(macOS)
/// Mac에서 실행할 때 한 번 창 위에 피오 스플래시를 띄운다(시범이 켜져 있을 때만).
struct PioTrialMacSplashOverlay: View {
    @State private var isShowing = PioTrial.isEnabled && !Self.hasShown

    private static var hasShown = false

    var body: some View {
        if isShowing {
            PioTrialSplash { isShowing = false }
                .onAppear { Self.hasShown = true }
        }
    }
}
#endif
#endif

#if canImport(SwiftUI)
/// 화면 검증용(Debug 빌드만): `-DaylogDebugPioStage 220`처럼 주면 머리말과 같은 무대·같은 동작의 피오를 크게 띄운다.
/// 부위 경계와 움직임을 크게 보고 영상으로 남기려는 것이다(앱 화면에는 나오지 않는다).
struct PioTrialStagePreview: View {
    @Environment(AppStore.self) private var store
    private var size: CGFloat {
        #if DEBUG
        CGFloat(UserDefaults.standard.double(forKey: "DaylogDebugPioStage"))
        #else
        0
        #endif
    }

    var body: some View {
        if PioTrial.isEnabled, size > 0 {
            SaessagiAnimatedView(
                pose: .idle, size: size, behavior: .today, fillsLane: true, maxRange: .infinity,
                pioStage: PioTrial.artStage(level: store.growth.level)
            )
                .frame(width: size * 3.2, height: size * 1.25, alignment: .bottomLeading)
                .padding(24)
                .background(Theme.windowBackground, in: RoundedRectangle(cornerRadius: 18))
                .allowsHitTesting(false)
        }
    }
}
#endif
