#if DEBUG
import SwiftUI

/// Local, opt-in QA route. Does not read or change equipped outfit or growth data.
struct PioLayeredDiagnosticsView: View {
    static var isEnabled: Bool {
        PioLayeredTrial.isEnabled && UserDefaults.standard.bool(forKey: "DaylogDebugLayeredDiagnostics")
    }
    @State private var outfit: PioOutfitID
    @State private var motion: PioLayeredMotion
    @State private var size: Int
    @State private var animating: Bool
    @State private var visible: Bool
    @State private var flatReference: Bool
    @State private var switching: Bool
    @State private var dark: Bool
    @State private var reduceMotion = false
    @State private var switches = 0
    @State private var metrics = "측정값을 새로고침하세요."
    @State private var presentations = "[]"
    @State private var evidenceStatus = ""
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    init() {
        let defaults = UserDefaults.standard
        let selected = PioOutfitID(rawValue: defaults.string(forKey: "DaylogDebugLayeredOutfit") ?? "basic") ?? .basic
        _outfit = State(initialValue: PioLayeredTrial.approvedOutfits.contains(selected) ? selected : .basic)
        let requestedMotion = PioLayeredMotion(rawValue: defaults.string(forKey: "DaylogDebugLayeredMotion") ?? "idle") ?? .idle
        _motion = State(initialValue: PioLayeredTrial.supportedMotions(for: selected).contains(requestedMotion) ? requestedMotion : .idle)
        let points = defaults.integer(forKey: "DaylogDebugLayeredSize")
        _size = State(initialValue: [64,220].contains(points) ? points : 220)
        let test = defaults.string(forKey: "DaylogDebugLayeredCase") ?? "layeredStatic"
        _animating = State(initialValue: ["animated", "switching"].contains(test))
        _visible = State(initialValue: test != "offscreen")
        _flatReference = State(initialValue: test == "flatStatic")
        _switching = State(initialValue: test == "switching")
        _dark = State(initialValue: defaults.string(forKey: "DaylogDebugAppearance") == "dark")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("피오 부품 동작 검토").font(.title2.bold())
                Text("\(PioLayeredTrial.approvedOutfits.map(\.title).joined(separator: "·")) 각각 한 가지 체형의 시험용 리그예요. 성장 1–4단계와 다른 의상은 아직 지원하지 않아요.")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("의상", selection: $outfit) {
                    ForEach(PioLayeredTrial.approvedOutfits) { Text($0.title).tag($0) }
                }.accessibilityIdentifier("layeredQA.outfit")
                Picker("동작", selection: $motion) {
                    ForEach(PioLayeredTrial.supportedMotions(for: outfit)) { Text($0.title).tag($0) }
                }.accessibilityIdentifier("layeredQA.motion")
                Picker("크기", selection: $size) {
                    ForEach([64,220], id: \.self) { Text("\($0)pt").tag($0) }
                }.accessibilityIdentifier("layeredQA.size")
                HStack {
                    Toggle("동작 켜기", isOn: $animating).accessibilityIdentifier("layeredQA.animate")
                    Toggle("캐릭터 표시", isOn: $visible).accessibilityIdentifier("layeredQA.visible")
                }
                HStack {
                    Toggle("원본 한 장 비교", isOn: $flatReference).accessibilityIdentifier("layeredQA.flat")
                    Toggle("정지 요청 검토", isOn: $reduceMotion).accessibilityIdentifier("layeredQA.reduceMotion")
                }
                Toggle("어두운 배경", isOn: $dark).accessibilityIdentifier("layeredQA.dark")
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(dark ? Color(red:0.07,green:0.11,blue:0.10) : Color(red:0.98,green:0.96,blue:0.91))
                    if visible {
                        PioLayeredCharacterView(outfit: outfit, motion: motion, isAnimating: animating && !reduceMotion, flatReference: flatReference)
                            .frame(width: CGFloat(size), height: CGFloat(size))
                    }
                }.frame(height: 260).frame(maxWidth: .infinity)
                Text("\(outfit.title) · \(motion.title) · \(size)pt · \(flatReference ? "원본 정지" : "독립 부품")")
                    .font(.caption).accessibilityIdentifier("layeredQA.selection")
                Text("시스템 움직임 줄이기: \(systemReduceMotion ? "켜짐" : "꺼짐") · 화면: \(scenePhase == .active ? "활성" : "비활성")")
                    .font(.caption).accessibilityIdentifier("layeredQA.scene")
                Text("눈만·오른 날개만 모드에서는 몸통과 상위 레이어가 고정돼요. 크리스마스 모자와 새싹은 한 부품이며 선물은 왼손과 함께 움직여요. 크리스마스 펄럭임은 선물을 든 쪽 ±6°, 오른쪽 ±12°예요.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(switching ? "전환 멈추기" : "30회 의상 전환") { switching.toggle() }
                        .accessibilityIdentifier("layeredQA.switch")
                    Text("\(switches)회").monospacedDigit()
                }
                HStack {
                    Button("측정값 초기화") { PioLayeredMetrics.reset(); refresh(export: true) }
                        .accessibilityIdentifier("layeredQA.resetMetrics")
                    Button("측정값 새로고침") { refresh(export: true) }.accessibilityIdentifier("layeredQA.metrics")
                }
                Text(metrics).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    .accessibilityElement(children: .ignore).accessibilityLabel(metrics)
                    .accessibilityIdentifier("layeredQA.metricValues")
                Text(presentations).font(.system(.caption2, design: .monospaced)).textSelection(.enabled)
                    .accessibilityElement(children: .ignore).accessibilityLabel(presentations)
                    .accessibilityIdentifier("layeredQA.presentation")
                if !evidenceStatus.isEmpty {
                    Text(evidenceStatus).font(.caption2).textSelection(.enabled)
                        .accessibilityElement(children: .ignore).accessibilityLabel(evidenceStatus)
                        .accessibilityIdentifier("layeredQA.evidencePath")
                }
                Text("아래 여백으로 스크롤해 캐릭터가 화면 밖으로 나간 상태를 검토할 수 있어요.")
                    .font(.caption2).foregroundStyle(.secondary)
                Color.clear.frame(height: 900).accessibilityHidden(true)
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .preferredColorScheme(dark ? .dark : .light)
        .onAppear {
            for item in PioLayeredTrial.approvedOutfits {
                _ = PioLayeredResources.manifest(for: item)
                _ = PioLayeredResources.image(named: "pio_layered_\(item.rawValue)_reference")
            }
            refresh()
        }
        .onChange(of: outfit) { _, next in
            if !PioLayeredTrial.supportedMotions(for: next).contains(motion) { motion = .idle }
        }
        .task(id: switching) {
            guard switching else { return }
            switches = 0
            for index in 0..<30 {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard !Task.isCancelled else { return }
                let current = PioLayeredTrial.approvedOutfits.firstIndex(of: outfit) ?? 0
                outfit = PioLayeredTrial.approvedOutfits[(current + 1) % PioLayeredTrial.approvedOutfits.count]
                switches = index + 1
            }
            switching = false
        }
    }
    private func refresh(export: Bool = false) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let sampledPresentations = PioLayeredMetrics.presentations
        let snapshot = PioLayeredMetrics.snapshot
        if let data = try? JSONSerialization.data(withJSONObject: sampledPresentations, options: [.sortedKeys]),
           let json = String(data: data, encoding: .utf8) { presentations = json }
        metrics = snapshot.keys.sorted().map { "\($0)=\(snapshot[$0]!)" }.joined(separator: " · ")
        // Explicit launch opt-in, manual button only. Never writes on appear or
        // during animation. A filename is used inside the app's own sandbox temp.
        guard export, Self.isEnabled,
              ProcessInfo.processInfo.arguments.contains("-DaylogDebugLayeredEvidencePath"),
              let requested = UserDefaults.standard.string(forKey: "DaylogDebugLayeredEvidencePath"),
              !requested.isEmpty else { return }
        let filename = URL(fileURLWithPath: requested).lastPathComponent
        guard filename == "pio-layered-evidence.json" else {
            evidenceStatus = "검토 파일 이름은 pio-layered-evidence.json을 사용하세요."
            return
        }
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let phase = scenePhase == .active ? "active" : scenePhase == .background ? "background" : "inactive"
        let evidence: [String: Any] = [
            "timestamp": timestamp,
            "sampleUptime": ProcessInfo.processInfo.systemUptime,
            "metrics": snapshot,
            "presentations": sampledPresentations,
            "outfit": outfit.rawValue,
            "motion": motion.rawValue,
            "size": size,
            "scenePhase": phase,
            "systemReduceMotion": systemReduceMotion,
            "forcedStop": reduceMotion,
            "requestedAnimating": animating,
            "visible": visible,
            "flatReference": flatReference,
            "dark": dark,
            "switches": switches
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: destination, options: .atomic)
            evidenceStatus = destination.path
            NSLog("Pio layered evidence: %@", destination.path)
        } catch {
            evidenceStatus = "검토 파일 저장 실패: " + error.localizedDescription
        }
    }
}
#endif
