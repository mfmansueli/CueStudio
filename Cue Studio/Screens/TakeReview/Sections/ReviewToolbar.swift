//
//  ReviewToolbar.swift
//  Cue Studio
//

import SwiftUI

/// The top of a take's review (6.3), in the system's navigation bar over the video: back, the title "TAKE 2 OF 3 ✦" (a menu: the
/// other takes of the video and ✦ Suggest best), and the star that makes this the best take with the bin, grouped in one glass
/// capsule as the system does.
struct ReviewToolbar: ToolbarContent {
    let take: Take
    /// "TAKE 2 OF 3", or "TAKE 1" for a video with only this take.
    let placeLabel: String
    let onBack: () -> Void
    let onToggleBest: () -> Void
    let onDelete: () -> Void
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onSuggest: (() -> Void)?

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: onBack) { Image(systemName: "chevron.backward") }
                .accessibilityLabel(Text("Back"))
                .accessibilityIdentifier("review.backButton")
        }
        ToolbarItem(placement: .principal) {
            takeMenu
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: onToggleBest) {
                Image(systemName: take.isBest ? "star.fill" : "star")
                    .foregroundStyle(take.isBest ? Palette.acc : Palette.ink)
            }
            .accessibilityLabel(Text("Best take"))
            .accessibilityValue(Text(take.isBest ? "On" : "Off"))
            .accessibilityIdentifier("review.bestButton")
            Button(action: onDelete) { Image(systemName: "trash") }
                .accessibilityLabel(Text("Delete"))
                .accessibilityIdentifier("review.deleteButton")
        }
    }

    /// "TAKE 2 OF 3 ✦" as the bar's title: it opens the neighbours (the swipe still goes to them too) and Suggest best.
    private var takeMenu: some View {
        Menu {
            if let onPrevious { Button("Previous take", systemImage: "chevron.backward", action: onPrevious) }
            if let onNext { Button("Next take", systemImage: "chevron.forward", action: onNext) }
            if let onSuggest { Button("Suggest best", systemImage: "sparkles", action: onSuggest) }
        } label: {
            HStack(spacing: 5) {
                Text(placeLabel)
                if onSuggest != nil { Text(verbatim: "✦").foregroundStyle(Palette.aiText) }
                if hasChoices {
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Palette.ink2)
                }
            }
            .font(.system(.subheadline, design: .monospaced, weight: .bold))
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(minHeight: Metrics.hitTarget)
            // Glass like the bar's other controls: the title stays readable over any frame of the video.
            .glassEffect(.regular.interactive(), in: Capsule())
            .contentShape(Capsule())
        }
        .disabled(!hasChoices)
        .accessibilityLabel(Text(placeLabel))
        .accessibilityIdentifier("review.takeLabel")
    }

    private var hasChoices: Bool {
        onPrevious != nil || onNext != nil || onSuggest != nil
    }
}
