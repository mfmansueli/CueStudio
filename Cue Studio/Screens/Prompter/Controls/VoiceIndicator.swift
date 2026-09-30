//
//  VoiceIndicator.swift
//  Cue Studio
//

import SwiftUI

/// Voice Following's status: a small waveform that moves with the mic level, and what it's doing
/// ("Listening", "Paused", "Getting ready", "Downloading 40%"). In the Selfie toolbar it takes the
/// speed slider's place, led by "AUTO" while the voice sets the pace word by word, or by the speed
/// ("0.7×") while the text scrolls at it as the creator talks; in Studio it sits inline, without
/// its own background.
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
                Text(status.shortLabel(isListening: isListening))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.acc)
            } else {
                Text(status.tag(speedLabel: speedLabel))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .kerning(0.5)
                    .foregroundStyle(Palette.acc)
                    .fixedSize()
                Text(status.shortLabel(isListening: isListening))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, fillsWidth ? 16 : 14)
        .frame(maxWidth: fillsWidth ? nil : .infinity, minHeight: 44, alignment: .leading)
        .background(fillsWidth ? .clear : Palette.accSoft, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Voice Following"))
        .accessibilityValue(Text(status.accessibilityValue(isListening: isListening, speedLabel: speedLabel)))
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
    VStack {
        VoiceIndicator(level: 0.7, isListening: true)
        VoiceIndicator(level: 0.4, isListening: true, status: .scrollsWhileTalking, speedLabel: "0.7×")
        VoiceIndicator(level: 0, isListening: false, status: .downloading(.thai, progress: 0.4), speedLabel: "0.7×")
    }
    .padding()
    .background(Color.black)
}
#endif
