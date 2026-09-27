//
//  VoiceIndicator.swift
//  Cue Studio
//

import SwiftUI

/// Live mic bars shown instead of the speed control in Voice follow.
struct VoiceIndicator: View {
    /// 0...1
    let level: Double
    let isActive: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
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
                Text("Voice")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.acc)
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Palette.accSoft, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Voice follow"))
        .accessibilityValue(Text(isActive ? "Scrolling with your voice" : "Waiting for you to speak"))
    }

    /// Bars follow the level, each with its own weight so it reads as a waveform.
    private func barScale(_ index: Int) -> Double {
        let weights = [0.55, 0.85, 1.0, 0.75, 0.6]
        return max(0.25, min(1, level * weights[index] * 1.4))
    }
}

#if DEBUG
#Preview {
    VoiceIndicator(level: 0.7, isActive: true, action: {})
        .padding()
        .background(Color.black)
}
#endif
