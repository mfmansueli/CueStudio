//
//  VoiceWaveform.swift
//  Cue Studio
//

import SwiftUI

/// Voice Following's live feedback: five bars that follow the microphone's level, each with its own weight so together they read as a
/// waveform, and that rest low while nothing is heard (the text is paused, or the voice is not being followed).
struct VoiceWaveform: View {
    /// 0...1
    let level: Double
    /// The text is moving and the voice is being followed.
    let isListening: Bool
    var height: CGFloat = 18
    var barWidth: CGFloat = 3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let weights = [0.55, 0.85, 1.0, 0.75, 0.6]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<Self.weights.count, id: \.self) { index in
                Capsule()
                    .fill(Palette.acc)
                    .frame(width: barWidth, height: height * scale(of: index))
            }
        }
        .frame(height: height)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: level)
        .accessibilityHidden(true)
    }

    private func scale(of index: Int) -> CGFloat {
        guard isListening else { return 0.3 }
        return CGFloat(max(0.25, min(1, level * Self.weights[index] * 1.4)))
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 24) {
        VoiceWaveform(level: 0, isListening: false)
        VoiceWaveform(level: 0.3, isListening: true)
        VoiceWaveform(level: 0.9, isListening: true, height: 22)
    }
    .padding()
    .background(Color.black)
}
#endif
