//
//  PracticeVoiceWave.swift
//  Cue Studio
//

import SwiftUI

/// The practice's waveform (1.6), in Voice Following's yellow: while the voice is heard its nine bars follow the microphone's level, each with
/// its own weight and a shimmer of its own, so it reads as a voice; while Cue listens and hears nothing a slow ripple runs across them, low,
/// so it is plain that it is listening. With Reduce Motion the bars only follow the level.
struct PracticeVoiceWave: View {
    /// 0...1, the microphone's level.
    let level: Double
    /// The voice is heard now.
    let isHearing: Bool
    var height: CGFloat = 24

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let weights: [Double] = [0.45, 0.7, 0.9, 1.0, 0.85, 1.0, 0.8, 0.6, 0.4]
    private static let barWidth: CGFloat = 3
    private static let gap: CGFloat = 2.5
    static var width: CGFloat { CGFloat(weights.count) * barWidth + CGFloat(weights.count - 1) * gap }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                for index in Self.weights.indices {
                    let bar = max(Self.barWidth, size.height * fill(of: index, at: time))
                    let rect = CGRect(
                        x: CGFloat(index) * (Self.barWidth + Self.gap), y: (size.height - bar) / 2, width: Self.barWidth, height: bar
                    )
                    canvas.fill(Path(roundedRect: rect, cornerRadius: Self.barWidth / 2), with: .color(Palette.acc.opacity(isHearing ? 1 : 0.75)))
                }
            }
        }
        .frame(width: Self.width, height: height)
        .accessibilityHidden(true)
    }

    /// How much of the height a bar takes (0...1).
    private func fill(of index: Int, at time: Double) -> CGFloat {
        let phase = Double(index) * 0.7
        if isHearing {
            let shimmer = reduceMotion ? 1 : 0.72 + 0.28 * sin(time * 11 + phase * 1.9)
            return CGFloat(min(1, max(0.18, (0.2 + level * 1.3) * Self.weights[index] * shimmer)))
        }
        guard !reduceMotion else { return 0.2 }
        // A ripple travelling left to right, once every 1.6 s.
        return CGFloat(0.16 + 0.22 * max(0, sin(time * 3.9 - phase)))
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 24) {
        PracticeVoiceWave(level: 0, isHearing: false)
        PracticeVoiceWave(level: 0.4, isHearing: true)
        PracticeVoiceWave(level: 0.9, isHearing: true)
    }
    .padding()
    .background(Color.black)
}
#endif
