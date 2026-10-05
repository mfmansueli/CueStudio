//
//  ScriptWritingPill.swift
//  Cue Studio
//

import SwiftUI

/// "✦ Writing in your voice" (v30 · 4.1): a 34 pt violet pill over the bottom of the page while the AI writes. Its edge glows every 2.4 s
/// (rim 36% → 50%, a 24 pt violet halo up to 45%) and a white shimmer runs across the words every 1.6 s. Still under Reduce Motion.
struct ScriptWritingPill: View {
    let inMyVoice: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            // `glow 2.4s`: 0 → 1 → 0, eased.
            let pulse = reduceMotion ? 0 : 0.5 - 0.5 * cos(time * 2 * .pi / 2.4)
            // `shimx 1.6s linear`: the highlight travels from the right edge to past the left one.
            let sweep = reduceMotion ? 0.5 : 1 - (time.truncatingRemainder(dividingBy: 1.6) / 1.6)
            HStack(spacing: 8) {
                Text("✦").font(.system(size: 14)).foregroundStyle(Palette.aiText)
                label(sweep: sweep)
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Color(hex: 0x9D8CFF, opacity: 0.2), in: Capsule())
            .overlay(Capsule().strokeBorder(Color(hex: 0xB4A7FF, opacity: 0.36 + 0.14 * pulse), lineWidth: 0.5))
            .shadow(color: Color(hex: 0x9D8CFF, opacity: 0.45 * pulse), radius: 24)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(inMyVoice ? "Writing in your voice" : "Writing…"))
        .accessibilityIdentifier("page.writingPill")
    }

    /// The words in `#E4DEFF` with a white band (38% → 62% of a gradient 2.4× as wide as the text) sliding across.
    private func label(sweep: Double) -> some View {
        let text = Text(inMyVoice ? "Writing in your voice" : "Writing…").font(.system(size: 13, weight: .semibold))
        return text
            .foregroundStyle(Color(hex: 0xE4DEFF))
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: max(0, sweep - 0.12)),
                        .init(color: .white, location: sweep),
                        .init(color: .clear, location: min(1, sweep + 0.12)),
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
                .mask(text)
            }
    }
}
