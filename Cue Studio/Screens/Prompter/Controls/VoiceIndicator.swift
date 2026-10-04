//
//  VoiceIndicator.swift
//  Cue Studio
//

import SwiftUI

/// Voice Following's status: a small waveform that moves with the mic level, and what it's doing.
/// In the Selfie toolbar it is the line under the mode switch, where the speed slider is in
/// Steady: "Scrolls when you talk, waits when you stop." while recognition follows the words, or
/// the longer status when the model is getting ready, downloading or the text scrolls at the set
/// speed while the creator talks. In Studio (`fillsWidth`) it is the waveform and a short status.
struct VoiceIndicator: View {
    /// 0...1
    let level: Double
    let isListening: Bool
    var status: VoiceFollowStatus = .followingWords
    /// The set speed, shown when the text moves at it.
    var speedLabel = ""
    var fillsWidth = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            bars(height: fillsWidth ? 20 : 14, width: fillsWidth ? 3 : 2.5)
            if fillsWidth {
                Text(status.shortLabel(isListening: isListening))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accText)
            } else {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, fillsWidth ? 16 : 10)
        .frame(maxWidth: fillsWidth ? nil : .infinity, minHeight: fillsWidth ? 44 : 36, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Voice Following"))
        .accessibilityValue(Text(status.accessibilityValue(isListening: isListening, speedLabel: speedLabel)))
        .accessibilityIdentifier("prompter.voiceIndicator")
    }

    /// What the line says: the habit when recognition follows the words, the status when it can't.
    private var hint: String {
        switch status {
        case .followingWords: String(localized: "Scrolls when you talk, waits when you stop.")
        case .scrollsWhileTalking, .preparing, .downloading: status.detail(speedLabel: speedLabel)
        }
    }

    private func bars(height: CGFloat, width: CGFloat) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(Palette.acc)
                    .frame(width: width, height: height * barScale(index))
            }
        }
        .frame(height: height)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: level)
    }

    /// Bars follow the level, each with its own weight so it reads as a waveform. Paused, they rest.
    private func barScale(_ index: Int) -> Double {
        guard isListening else { return 0.3 }
        let weights = [0.55, 0.85, 1.0, 0.75, 0.6]
        return max(0.25, min(1, level * weights[index] * 1.4))
    }
}

#if DEBUG
#Preview {
    VStack {
        VoiceIndicator(level: 0.7, isListening: true)
        VoiceIndicator(level: 0.4, isListening: true, status: .scrollsWhileTalking, speedLabel: "0.7×")
        VoiceIndicator(level: 0, isListening: false, status: .downloading(.thai, progress: 0.4), speedLabel: "0.7×")
        VoiceIndicator(level: 0.5, isListening: true, fillsWidth: true)
    }
    .padding()
    .background(Color.black)
}
#endif
