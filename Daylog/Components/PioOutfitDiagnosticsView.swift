#if DEBUG
import SwiftUI

/// Opt-in, isolated renderer QA. It bypasses dashboard/shop content so cases
/// share one fixed host and no hidden animated character contaminates CPU samples.
struct PioOutfitDiagnosticsView: View {
    static var isEnabled: Bool {
        RoutimoriSplashTrial.isEnabled && UserDefaults.standard.bool(forKey: "DaylogDebugOutfitDiagnostics")
    }
    @State private var outfit: PioOutfitID = .basic
    @State private var motion: PioOutfitMotion = .idle
    @State private var size = 220
    @State private var stage = 1
    @State private var animating = false
    @State private var showCharacter = true
    @State private var forcedReduceMotion = false
    @State private var dark = false
    @State private var switching = false
    @State private var switches = 0
    @State private var metrics = "측정값을 새로고침하세요."
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private let outfits: [PioOutfitID] = [.basic, .christmas, .hanbok, .astronaut]

    init() {
        let test = UserDefaults.standard.string(forKey: "DaylogDebugOutfitCase") ?? "baseStatic"
        let selected: PioOutfitID = test.hasPrefix("christmas") ? .christmas
            : test.hasPrefix("hanbok") ? .hanbok : test.hasPrefix("astronaut") ? .astronaut : .basic
        _outfit = State(initialValue: selected)
        _motion = State(initialValue: test.hasSuffix("Jump") || test == "switching" ? .jump : .idle)
        _animating = State(initialValue: !test.hasSuffix("Static"))
        _showCharacter = State(initialValue: test != "offscreen")
        _switching = State(initialValue: test == "switching")
        let requestedSize = UserDefaults.standard.integer(forKey: "DaylogDebugOutfitSize")
        _size = State(initialValue: [64,120,220].contains(requestedSize) ? requestedSize : 220)
        let requestedStage = UserDefaults.standard.integer(forKey: "DaylogDebugOutfitStage")
        _stage = State(initialValue: (1...4).contains(requestedStage) ? requestedStage : 1)
        _dark = State(initialValue: UserDefaults.standard.string(forKey: "DaylogDebugAppearance") == "dark")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("피오 동작 검토").font(.title2.bold())
                Text("개발 검토 전용 · 원화와 실제 보유 내역을 바꾸지 않아요.")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("의상", selection: $outfit) {
                    ForEach(outfits) { Text($0.title).tag($0) }
                }.accessibilityIdentifier("outfitQA.outfit")
                Picker("동작", selection: $motion) {
                    ForEach(PioOutfitCapabilities(outfit: outfit).supportedMotions) { Text($0.title).tag($0) }
                }.accessibilityIdentifier("outfitQA.motion")
                HStack {
                    Picker("크기", selection: $size) {
                        ForEach([64,120,220], id: \.self) { Text("\($0)pt").tag($0) }
                    }.accessibilityIdentifier("outfitQA.size")
                    Picker("단계", selection: $stage) {
                        ForEach(1...4, id: \.self) { Text("\($0)단계").tag($0) }
                    }.accessibilityIdentifier("outfitQA.stage")
                }
                HStack {
                    Toggle("동작 켜기", isOn: $animating).accessibilityIdentifier("outfitQA.animate")
                    Toggle("캐릭터 표시", isOn: $showCharacter).accessibilityIdentifier("outfitQA.visible")
                }
                HStack {
                    Toggle("정지 요청 검토", isOn: $forcedReduceMotion).accessibilityIdentifier("outfitQA.reduceMotion")
                    Toggle("어두운 배경", isOn: $dark).accessibilityIdentifier("outfitQA.dark")
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(dark ? Color(red:0.06,green:0.12,blue:0.1) : Color(red:0.98,green:0.97,blue:0.94))
                    if showCharacter {
                        PioOutfitMotionView(outfit: outfit, stage: stage, motion: motion, isAnimating: animating && !forcedReduceMotion)
                            .frame(width: CGFloat(size), height: CGFloat(size))
                    }
                }.frame(height: 270).frame(maxWidth: .infinity)
                Text("\(outfit.title) · \(motion.title) · \(size)pt · \(stage)단계")
                    .font(.caption).accessibilityIdentifier("outfitQA.selection")
                Text("시스템 움직임 줄이기: \(systemReduceMotion ? "켜짐" : "꺼짐") · 화면: \(scenePhase == .active ? "활성" : "비활성")")
                    .font(.caption).accessibilityIdentifier("outfitQA.systemReduceMotion")
                Text("세 의상은 한 장의 원화예요. 눈·날개·소품의 독립 동작과 단계별 외형은 지원하지 않아요.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(switching ? "전환 멈추기" : "30회 의상 전환") { switching.toggle() }
                        .accessibilityIdentifier("outfitQA.switch")
                    Text("\(switches)회").monospacedDigit()
                }
                HStack {
                    Button("측정값 초기화") { PioOutfitMotionDiagnostics.reset(); refreshMetrics() }
                        .accessibilityIdentifier("outfitQA.resetMetrics")
                    Button("측정값 새로고침") { refreshMetrics() }
                        .accessibilityIdentifier("outfitQA.metrics")
                }
                Text(metrics).font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled).accessibilityIdentifier("outfitQA.metricValues")
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .preferredColorScheme(dark ? .dark : .light)
        .onAppear {
            // Preload the same four images before every comparison. This counts
            // successful CGImage retrieval, not physical decoder work.
            for item in outfits { _ = PioOutfitMotionImageCache.image(for: item) }
            refreshMetrics()
        }
        .onChange(of: outfit) { _, next in
            if !PioOutfitCapabilities(outfit: next).supportedMotions.contains(motion) { motion = .idle }
        }
        .task(id: switching) {
            guard switching else { return }
            switches = 0
            for index in 0..<30 {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard !Task.isCancelled else { return }
                outfit = [.christmas, .hanbok, .astronaut][index % 3]
                switches = index + 1
            }
            switching = false
        }
    }

    private func refreshMetrics() {
        let counters = PioOutfitMotionDiagnostics.snapshot
        metrics = counters.keys.sorted().map { "\($0)=\(counters[$0]!)" }.joined(separator: " · ")
    }
}
#endif
