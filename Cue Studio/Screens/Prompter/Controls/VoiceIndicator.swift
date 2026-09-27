//
//  VoiceIndicator.swift
//  Cue Studio
//

import SwiftUI

/// Voice Following's status in the toolbar: a small waveform that moves with the mic level, and
/// "Listening" or "Paused".
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
            Text(isListening ? "Listening" : "Paused")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.acc)
        }
        .padding(.horizontal, 16)
        .frame(minWidth: fillsWidth ? nil : 140, maxWidth: fillsWidth ? nil : 140, minHeight: 44)
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
