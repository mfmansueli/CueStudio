//
//  ReviewTopBar.swift
//  Cue Studio
//

import SwiftUI

/// The top of a take's review (6.3): back, the pill "TAKE 2 OF 3 ✦" (a menu: the other takes of the video and ✦ Suggest best), the star that makes this
/// the best take and the bin. Four glass controls over the video, 34 pt high.
struct ReviewTopBar: View {
    let take: Take
    /// "TAKE 2 OF 3", or "TAKE 1" for a video with only this take.
    let placeLabel: String
    let onBack: () -> Void
    let onToggleBest: () -> Void
    let onDelete: () -> Void
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onSuggest: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onBack) { Image(systemName: "chevron.backward") }
                .buttonStyle(.cueIcon(.glass, diameter: 36))
                .accessibilityLabel(Text("Back"))
                .accessibilityIdentifier("review.backButton")
            takeMenu
            Spacer(minLength: 0)
            Button(action: onToggleBest) {
                Image(systemName: "star.fill")
            }
            .buttonStyle(.cueIcon(.glass, diameter: 36))
            .foregroundStyle(take.isBest ? Palette.acc : Palette.ink2)
            .accessibilityLabel(Text("Best take"))
            .accessibilityValue(Text(take.isBest ? "On" : "Off"))
            .accessibilityIdentifier("review.bestButton")
            Button(action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.cueIcon(.glass, diameter: 36))
                .accessibilityLabel(Text("Delete"))
                .accessibilityIdentifier("review.deleteButton")
        }
    }

    /// "TAKE 2 OF 3 ✦": the pill opens the neighbours (the swipe still goes to them too) and Suggest best.
    private var takeMenu: some View {
        Menu {
            if let onPrevious { Button("Previous take", systemImage: "chevron.backward", action: onPrevious) }
            if let onNext { Button("Next take", systemImage: "chevron.forward", action: onNext) }
            if let onSuggest { Button("Suggest best", systemImage: "sparkles", action: onSuggest) }
        } label: {
            HStack(spacing: 6) {
                Text(placeLabel)
                if onSuggest != nil { Text(verbatim: "✦").foregroundStyle(Palette.aiText) }
            }
            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .glassEffect(.regular, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.glassBorder, lineWidth: 0.5))
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .disabled(onPrevious == nil && onNext == nil && onSuggest == nil)
        .accessibilityLabel(Text(placeLabel))
        .accessibilityIdentifier("review.takeLabel")
    }
}
