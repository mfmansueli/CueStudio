//
//  VoiceIndicator.swift
//  Cue Studio
//

import SwiftUI

/// Voice Following's status: a small waveform that moves with the mic level, and "Listening" or
/// "Paused". In the Selfie toolbar it takes the speed slider's place, led by "AUTO" (the voice sets
/// the speed); in Studio it sits inline, without its own background.
struct VoiceIndicator: View {
    /// 0...1
    let level: Double
    let isListening: Bool
    var fillsWidth = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(Palette.acc)
                        .frame(width: 3, height: 20 * barScale(index))
                }
            }
            .frame(height: 20)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: level)
            if fillsWidth {
                Text(isListening ? "Listening" : "Paused")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.acc)
            } else {
                Text("AUTO")
                    .font(.subheadline.weight(.bold))
                    .kerning(0.5)
                    .foregroundStyle(Palette.acc)
                Text(isListening ? "Listening" : "Paused")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, fillsWidth ? 16 : 14)
        .frame(maxWidth: fillsWidth ? nil : .infinity, minHeight: 44, alignment: .leading)
        .background(fillsWidth ? .clear : Palette.accSoft, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Voice Following"))
        .accessibilityValue(Text(isListening ? "Listening" : "Paused"))
        .accessibilityIdentifier("prompter.voiceIndicator")
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
    VoiceIndicator(level: 0.7, isListening: true)
        .padding()
        .background(Color.black)
}
#endif
