//
//  ReviewTopBar.swift
//  Cue Studio
//

import SwiftUI

/// Back, "Take 3 · 0:44", best-take star and delete.
struct ReviewTopBar: View {
    let take: Take
    let onBack: () -> Void
    let onToggleBest: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) { Image(systemName: "chevron.backward") }
                .buttonStyle(.cueIcon(.glass, diameter: 40))
                .accessibilityLabel(Text("Back"))
                .accessibilityIdentifier("review.backButton")
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Text(take.label)
                Text(DurationText.clock(take.duration))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink2)
            }
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .glassEffect(.regular, in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("review.takeLabel")
            Spacer(minLength: 0)
            Button(action: onToggleBest) { Image(systemName: "star.fill") }
                .buttonStyle(.cueIcon(take.isBest ? .accent : .glass, diameter: 40))
                .accessibilityLabel(Text("Best take"))
                .accessibilityValue(Text(take.isBest ? "On" : "Off"))
                .accessibilityIdentifier("review.bestButton")
            Button(action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.cueIcon(.glass, diameter: 40))
                .accessibilityLabel(Text("Delete"))
                .accessibilityIdentifier("review.deleteButton")
        }
    }
}
