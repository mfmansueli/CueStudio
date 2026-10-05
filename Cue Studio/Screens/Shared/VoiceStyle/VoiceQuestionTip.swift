//
//  VoiceQuestionTip.swift
//  Cue Studio
//

import SwiftUI
import TipKit

/// The My Cue Voice tip (08 §6, 09 §3): "Make scripts sound more like you · One quick question · voice nn%". TipKit keeps the logic —
/// whether it shows, and that a closed one is invalidated — and `VoiceQuestionScheduler` decides which question and when. Each
/// question, each time it comes back after a dismissal, is a tip of its own (`round`), because TipKit never shows an invalidated tip again.
struct VoiceQuestionTip: Tip {
    let question: VoiceQuestion
    /// How many times this question was dismissed before: a dismissed question that comes back is a new tip.
    let round: Int
    let strength: Int

    var id: String { "vq.tip.\(question.rawValue).\(round)" }

    var title: Text { Text("Make scripts sound more like you") }

    var message: Text? { Text("One quick question · voice \(strength)%") }

    var options: [any TipOption] {
        // The scheduler's caps (one a day, three a week) are the frequency.
        [Tips.IgnoresDisplayFrequency(true)]
    }
}

/// The look of the tip (09 §3): simulated glass in a 22 pt corner, a ✦ in a 30 pt violet circle, the title in 15 pt semibold, the message
/// in 13 pt at 70%, and the system's xmark at the end (44 pt to touch).
struct VoiceTipViewStyle: TipViewStyle {
    /// A tap on the tip (not on its ✕) opens the question.
    let onOpen: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            Button(action: onOpen) {
                content(configuration)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("voice.tip.open")
            closeButton(configuration)
        }
        .padding(.leading, 14)
        .padding(.trailing, 2)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func content(_ configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: "✦")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.tipGlyph)
                .frame(width: 30, height: 30)
                .background(Palette.tipGlyphFill, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                configuration.title
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                configuration.message?
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ink.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func closeButton(_ configuration: Configuration) -> some View {
        Button {
            configuration.tip.invalidate(reason: .tipClosed)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.ink.opacity(0.5))
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Close tip"))
        .accessibilityIdentifier("voice.tip.close")
    }
}
