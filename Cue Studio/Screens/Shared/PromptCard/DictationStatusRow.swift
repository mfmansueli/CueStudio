//
//  DictationStatusRow.swift
//  Cue Studio
//

import SwiftUI

/// What dictation is doing, at the top of the idea field: a small waveform that moves with the
/// voice while it listens, and a word for it ("Listening…", "Getting ready", "Downloading 40%",
/// "Finishing…"). Quiet on purpose: the words in the field are what the eye should follow.
struct DictationStatusRow: View {
    let state: DictationState
    /// 0...1
    let level: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2.5) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(Palette.acc)
                        .frame(width: 2.5, height: 14 * barScale(index))
                }
            }
            .frame(height: 14)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: level)
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.accText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier("empty.dictationStatus")
    }

    var label: String {
        switch state {
        case .idle: ""
        case .preparing(.some(.downloading(_, progress: let progress?))): String(localized: "Downloading \(Self.percent(progress))")
        case .preparing(.some(.downloading(_, progress: nil))): String(localized: "Downloading")
        case .preparing: String(localized: "Getting ready")
        case .listening: String(localized: "Listening…")
        case .finishing: String(localized: "Finishing…")
        }
    }

    /// Bars follow the level, each with its own weight so it reads as a waveform; at rest they sit low.
    private func barScale(_ index: Int) -> Double {
        guard state == .listening else { return 0.3 }
        let weights = [0.55, 0.85, 1.0, 0.75, 0.6]
        return max(0.25, min(1, level * weights[index] * 1.4))
    }

    private static func percent(_ fraction: Double) -> String {
        min(1, max(0, fraction)).formatted(.percent.precision(.fractionLength(0)).locale(.interface))
    }
}

#if DEBUG
#Preview {
    VStack(alignment: .leading, spacing: 12) {
        DictationStatusRow(state: .listening, level: 0.7)
        DictationStatusRow(state: .preparing(.downloading(.thai, progress: 0.4)), level: 0)
        DictationStatusRow(state: .finishing, level: 0)
    }
    .padding()
    .background(Palette.bg)
}
#endif
