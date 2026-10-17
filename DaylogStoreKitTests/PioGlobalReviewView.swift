import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import Daylog

/// Test-target-only controls around production views. The hosting test must
/// enable the Routimori DEBUG trial and acquire premium outfits through a real
/// local SKTestSession before presenting this view. No entitlement is injected.
@MainActor
struct PioGlobalReviewView: View {
    let store: AppStore
    @State private var preferences: DevicePreferences
    @State private var preferencesSuiteName: String
    @State private var scene: PioGlobalReviewScene
    @State private var isDark = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var inheritedScenePhase
    @State private var nativeScenePhase: ScenePhase = .inactive
    @State private var motionDiagnostic = ""
    @State private var characterSize: CGFloat = 220
    @State private var motion: PioOutfitMotion = .idle
    @State private var splashRun = 0
    @State private var selectionNotice: String?

    private let outfits: [PioOutfitID] = [.basic, .christmas, .halloween, .hanbok, .astronaut]

    init(store: AppStore, initialScene: PioGlobalReviewScene = .growth) {
        self.store = store
        // Welcome dismissal and dashboard preferences must never touch the
        // installed application's persistent defaults during UI review.
        let suiteName = "DaylogStoreKitTests.PioGlobalReview.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Cannot create isolated Pio review preferences")
        }
        _preferences = State(initialValue: DevicePreferences(defaults: defaults))
        _preferencesSuiteName = State(initialValue: suiteName)
        _scene = State(initialValue: initialScene)
    }

    private var wardrobe: PioWardrobeStore { .shared }
    private var outfitSelection: Binding<PioOutfitID> {
        Binding(get: { wardrobe.equippedOutfit }, set: { requested in
            selectionNotice = wardrobe.equip(requested)
                ? nil : "검증된 구매 권한이 없어 이 의상을 선택할 수 없어요."
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(store)
                .environment(preferences)
                .environment(\.colorScheme, isDark ? .dark : .light)
                // A manually hosted test view is not a SwiftUI App Scene. Derive
                // the phase from its actual native window, never force active.
                .environment(\.scenePhase, nativeScenePhase)
                .accessibilityIdentifier("globalReview.sceneContent")
            Divider()
            Text("TEST ONLY · \(wardrobe.equippedOutfit.title) · 성장 \(PioAppearanceCoordinator.shared.currentStage)단계 · \(scene.title)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.windowBackground)
        .background(PioReviewWindowLifecycle { phase in
            if nativeScenePhase != phase { nativeScenePhase = phase }
        }.frame(width: 0, height: 0).allowsHitTesting(false))
        .preferredColorScheme(isDark ? .dark : .light)
        .accessibilityIdentifier("globalReview.screen")
        .onDisappear {
            // Remove only the UUID-scoped domain created by this review view.
            UserDefaults(suiteName: preferencesSuiteName)?
                .removePersistentDomain(forName: preferencesSuiteName)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                Picker("의상", selection: outfitSelection) {
                    ForEach(outfits) { outfit in
                        Text(outfit.title + (wardrobe.owns(outfit) ? "" : " · 미보유"))
                            .tag(outfit)
                            .disabled(!wardrobe.owns(outfit))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("globalReview.outfit")
                Picker("장면", selection: $scene) {
                    ForEach(PioGlobalReviewScene.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("globalReview.scene")
            }
            HStack(spacing: 16) {
                Picker("화면", selection: $isDark) {
                    Text("라이트 / 낮").tag(false)
                    Text("다크 / 밤").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 250)
                .accessibilityIdentifier("globalReview.scheme")
                Text("시스템 동작 줄이기: \(reduceMotion ? "켜짐" : "꺼짐")")
                    .font(.caption)
                    .accessibilityIdentifier("globalReview.reduceMotion")
                Spacer(minLength: 0)
            }
            Text("동작 줄이기는 기기 설정 > 손쉬운 사용에서 변경해 주세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text("Scene: inherited \(phaseName(inheritedScenePhase)) / native \(phaseName(nativeScenePhase))")
                    .font(.caption2.monospaced())
                Button("동작 진단 읽기", action: readMotionDiagnostic)
                    .font(.caption)
                    .accessibilityIdentifier("globalReview.motionDiagnostic")
            }
            if !motionDiagnostic.isEmpty {
                Text(motionDiagnostic).font(.caption2.monospaced())
                    .accessibilityIdentifier("globalReview.motionDiagnosticResult")
            }
            if scene == .upright {
                Picker("캐릭터 크기", selection: $characterSize) {
                    Text("64 pt").tag(CGFloat(64))
                    Text("220 pt").tag(CGFloat(220))
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 250)
                .accessibilityIdentifier("globalReview.characterSize")
                Picker("요청 동작", selection: $motion) {
                    ForEach(PioOutfitMotion.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("globalReview.motion")
            }
            if scene == .splash {
                Button("스플래시 다시 보기") { splashRun += 1 }
                    .accessibilityIdentifier("globalReview.restartSplash")
            }
            if let selectionNotice {
                Text(selectionNotice).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }

    private func phaseName(_ phase: ScenePhase) -> String {
        switch phase {
        case .active: "active"
        case .background: "background"
        default: "inactive"
        }
    }

    private func readMotionDiagnostic() {
        #if DEBUG
        let snapshot = PioOutfitMotionDiagnostics.snapshot
        #if os(macOS)
        let systemReduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        let systemReduced = UIAccessibility.isReduceMotionEnabled
        #endif
        motionDiagnostic = "activeRigs=\(snapshot["activeRigs", default: 0]) tracks=\(snapshot["activeAnimationTracks", default: 0]) nativeReduce=\(systemReduced)"
        print("PIO_GLOBAL_MOTION scene=\(scene.rawValue) outfit=\(wardrobe.equippedOutfit.rawValue) requestedMotion=\(motion.rawValue) inherited=\(phaseName(inheritedScenePhase)) native=\(phaseName(nativeScenePhase)) environmentReduce=\(reduceMotion) \(motionDiagnostic) counters=\(snapshot)")
        #endif
    }

    @ViewBuilder private var content: some View {
        switch scene {
        case .upright:
            let appearance = PioAppearanceCoordinator.shared.resolve(
                level: store.growth.level, context: .dashboard, motion: motion)
            VStack(spacing: 16) {
                PioAppearanceView(appearance: appearance)
                    .frame(width: characterSize, height: characterSize)
                PioAppearanceNotice(appearance: appearance)
            }
            .padding(24)
            .frame(maxWidth: 500)
        case .growth:
            ScrollView {
                SaessagiGrowthCard()
                    .frame(maxWidth: 520)
                    .padding(24)
                    .frame(maxWidth: .infinity)
            }
        case .splash:
            // Preserve the production presentation timeline. For stable review,
            // the hosting test can set DaylogDebugSplashHold=routimori.
            RoutimoriSplashView(onFinish: {})
                .id(splashRun)
        case .vacation:
            if let info = VacationRestPreview.sampleInfo(today: store.today) {
                VacationRestView(preview: VacationRestPreview(
                    info: info, isNight: $isDark, onClose: { scene = .upright }))
            }
        case .cloudDownloading:
            cloud(.receiving)
        case .cloudCompleted:
            cloud(.ready)
        case .cloudFailed:
            cloud(.trouble)
        case .weeklyReview:
            WeeklyReviewSheet(review: store.weeklyReview(weekStart: .monday), stage: store.growth.stage)
        case .welcome:
            ScrollView {
                RestartCard(prompt: RestartPrompt(missedDays: 3, lastActiveDay: store.today.adding(days: -4)))
                    .padding(24)
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
            }
        case .wardrobe:
            NavigationStack { PioWardrobeView() }
        }
    }

    private func cloud(_ kind: SyncSceneKind) -> some View {
        GeometryReader { proxy in
            let side = min(340, max(140, proxy.size.width - 48), max(140, proxy.size.height - 180))
            ScrollView {
                VStack(spacing: 14) {
                    RoutimoriSyncBrand()
                    RoutimoriSyncScene(kind: kind, height: side)
                    PioAppearanceNotice(appearance: PioAppearanceCoordinator.shared.resolve(
                        level: store.growth.level, context: kind.pioAppearanceContext))
                }
                .padding(24)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .background(LinearGradient(colors: RoutimoriSyncStyle.background(dark: isDark),
                                       startPoint: .top, endPoint: .bottom))
        }
    }
}

// This bridge belongs only to the manually hosted QA view. Production views
// keep SwiftUI's own Scene lifecycle, Reduce Motion and viewport guards.
#if os(macOS)
private struct PioReviewWindowLifecycle: NSViewRepresentable {
    let onPhase: (ScenePhase) -> Void
    func makeNSView(context: Context) -> PioReviewLifecycleNativeView {
        let view = PioReviewLifecycleNativeView()
        view.onPhase = onPhase
        return view
    }
    func updateNSView(_ view: PioReviewLifecycleNativeView, context: Context) { view.onPhase = onPhase }
    static func dismantleNSView(_ view: PioReviewLifecycleNativeView, coordinator: ()) {
        NotificationCenter.default.removeObserver(view)
    }
}

private final class PioReviewLifecycleNativeView: NSView {
    var onPhase: (ScenePhase) -> Void = { _ in }
    init() {
        super.init(frame: .zero)
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.willResignActiveNotification,
                     NSApplication.didHideNotification, NSApplication.didUnhideNotification,
                     NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
                     NSWindow.didDeminiaturizeNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(lifecycleChanged(_:)), name: name, object: nil)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); publish(actualPhase) }
    private var actualPhase: ScenePhase {
        guard let window, window.isVisible, !window.isMiniaturized, !NSApplication.shared.isHidden else { return .background }
        return NSApplication.shared.isActive ? .active : .inactive
    }
    @objc private func lifecycleChanged(_ notification: Notification) {
        if let changedWindow = notification.object as? NSWindow, changedWindow !== window { return }
        publish(notification.name == NSApplication.willResignActiveNotification ? .inactive : actualPhase)
    }
    private func publish(_ phase: ScenePhase) {
        Task { @MainActor [weak self] in self?.onPhase(phase) }
    }
}
#else
private struct PioReviewWindowLifecycle: UIViewRepresentable {
    let onPhase: (ScenePhase) -> Void
    func makeUIView(context: Context) -> PioReviewLifecycleNativeView {
        let view = PioReviewLifecycleNativeView()
        view.onPhase = onPhase
        return view
    }
    func updateUIView(_ view: PioReviewLifecycleNativeView, context: Context) { view.onPhase = onPhase }
    static func dismantleUIView(_ view: PioReviewLifecycleNativeView, coordinator: ()) {
        NotificationCenter.default.removeObserver(view)
    }
}

private final class PioReviewLifecycleNativeView: UIView {
    var onPhase: (ScenePhase) -> Void = { _ in }
    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        for name in [UIScene.didActivateNotification, UIScene.willDeactivateNotification,
                     UIScene.willEnterForegroundNotification, UIScene.didEnterBackgroundNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(lifecycleChanged(_:)), name: name, object: nil)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func didMoveToWindow() { super.didMoveToWindow(); publish(actualPhase) }
    private var actualPhase: ScenePhase {
        guard let scene = window?.windowScene else { return .inactive }
        switch scene.activationState {
        case .foregroundActive: return .active
        case .background, .unattached: return .background
        default: return .inactive
        }
    }
    @objc private func lifecycleChanged(_ notification: Notification) {
        guard let ownScene = window?.windowScene,
              let changedScene = notification.object as? UIScene, changedScene === ownScene else { return }
        let phase: ScenePhase
        switch notification.name {
        case UIScene.didActivateNotification: phase = .active
        case UIScene.didEnterBackgroundNotification: phase = .background
        default: phase = .inactive
        }
        publish(phase)
    }
    private func publish(_ phase: ScenePhase) {
        Task { @MainActor [weak self] in self?.onPhase(phase) }
    }
}
#endif

enum PioGlobalReviewScene: String, CaseIterable, Identifiable {
    case upright, growth, splash, vacation, cloudDownloading, cloudCompleted, cloudFailed
    case weeklyReview, welcome, wardrobe
    var id: String { rawValue }
    var title: String {
        switch self {
        case .upright: "홈 캐릭터"
        case .growth: "성장 카드"
        case .splash: "앱 스플래시"
        case .vacation: "휴가 낮 / 밤"
        case .cloudDownloading: "iCloud 다운로드"
        case .cloudCompleted: "iCloud 완료"
        case .cloudFailed: "iCloud 실패"
        case .weeklyReview: "주간 회고"
        case .welcome: "복귀 안내"
        case .wardrobe: "옷장"
        }
    }
}
