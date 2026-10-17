import SwiftUI

/// Shared presentation for replaceable character slots. Composed cloud/vacation
/// scenes keep their own renderer and consume the resolver plus the notice.
struct PioAppearanceView: View {
    let appearance: PioResolvedAppearance
    var isAnimating = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch appearance.artwork {
            case .outfitReference:
                character
            case .existingScene(let asset):
                Image(asset).resizable().scaledToFit()
            case .unavailable:
                VStack(spacing: 6) {
                    Image(systemName: "photo").font(.title2)
                    Text("원화 준비 중").font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(appearance.accessibilityDescription)
    }

    @ViewBuilder private var character: some View {
        #if DEBUG
        if appearance.renderer == .layeredPilot {
            PioLayeredCharacterView(outfit: appearance.outfit, motion: layeredMotion,
                                    isAnimating: isAnimating && !reduceMotion)
        } else {
            referenceCharacter
        }
        #else
        referenceCharacter
        #endif
    }

    private var referenceCharacter: some View {
        PioOutfitMotionView(outfit: appearance.outfit, stage: appearance.stage,
                           motion: appearance.motion, isAnimating: isAnimating && !reduceMotion)
    }

    #if DEBUG
    private var layeredMotion: PioLayeredMotion {
        if appearance.pose == .walking { return .walk }
        switch appearance.motion {
        case .wave: return .wave
        case .jump, .bounce: return .jump
        case .landing: return .landing
        case .celebration: return .celebration
        case .idle, .rest: return .idle
        }
    }
    #endif
}

/// A scene that cannot depict the selected costume must say so where it appears;
/// a correct default scene is preserved instead of an incorrect costume overlay.
struct PioAppearanceNotice: View {
    let appearance: PioResolvedAppearance

    var body: some View {
        if let note = appearance.compatibilityNote {
            Label(note, systemImage: appearance.isAwaitingVerification ? "clock" : "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pio.appearance.notice.\(appearance.context.rawValue)")
        }
    }
}
