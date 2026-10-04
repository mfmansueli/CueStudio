//
//  ReviewTopBar.swift
//  Cue Studio
//

import SwiftUI

/// Back, "TAKE 3  1:02", the best-take star (a yellow ring, filled once it is the best) and delete,
/// on glass over the video.
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
                Text(take.label).textCase(.uppercase)
                Text(DurationText.clock(take.duration))
                    .foregroundStyle(Palette.ink2)
            }
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
            .tracking(0.6)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .glassEffect(.regular, in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("review.takeLabel")
            Spacer(minLength: 0)
            Button(action: onToggleBest) {
                Image(systemName: take.isBest ? "star.fill" : "star")
            }
            .buttonStyle(.cueIcon(take.isBest ? .accent : .glass, diameter: 40))
            .overlay {
                if !take.isBest { Circle().strokeBorder(Palette.acc, lineWidth: 1.5) }
            }
            .foregroundStyle(take.isBest ? Palette.accInk : Palette.accText)
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
