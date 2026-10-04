//
//  StageBar.swift
//  Cue Studio
//

import SwiftUI

/// The video's pipeline as a row of steps (PICK · EDIT · READY · SHARED): the steps up to the current
/// one are filled in yellow, the current label is yellow, the rest wait in gray. It only draws what
/// it is given; which step a video is in is derived from its takes elsewhere, never set by hand.
/// Pass the labels and the VoiceOver title already localized.
struct StageBar: View {
    var labels: [String]
    /// Index of the current step in `labels`, or nil when the video isn't in the pipeline.
    var current: Int?
    /// What VoiceOver calls the bar; its value is the current step.
    var accessibilityTitle: String
    /// The color of the current step and of the steps up to it (the stage's, in the take review).
    var tint: Color = Palette.accText

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                let isReached = current.map { index <= $0 } ?? false
                VStack(spacing: 5) {
                    Text(label)
                        .font(CueStudioFont.hud)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(index == current ? tint : Palette.ink2)
                    Capsule()
                        .fill(isReached ? tint : Palette.fill)
                        .frame(height: 2)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityTitle))
        .accessibilityValue(Text(current.flatMap { labels.indices.contains($0) ? labels[$0] : nil } ?? ""))
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 20) {
        StageBar(labels: ["Pick", "Edit", "Ready", "Shared"], current: 1, accessibilityTitle: "Stage")
        StageBar(labels: ["Pick", "Edit", "Ready", "Shared"], current: 3, accessibilityTitle: "Stage")
        StageBar(labels: ["Pick", "Edit", "Ready", "Shared"], current: nil, accessibilityTitle: "Stage")
    }
    .padding()
    .background(Palette.bg)
}
#endif
