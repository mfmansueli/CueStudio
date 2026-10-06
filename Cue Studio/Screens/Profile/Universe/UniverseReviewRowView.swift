//
//  UniverseReviewRowView.swift
//  Cue Studio
//

import SwiftUI

/// "Your 2026 in review" (9.2): a glass row, 56 pt high with a 20 pt radius; the mini story card, the title and a mono line, and a glass "▶ Play" chip.
/// Tapping anywhere opens the story. Locked ("3 VIDEOS TO UNLOCK"): 62% opacity and no Play, and a tap says why.
struct UniverseReviewRowView: View {
    let row: UniverseReviewRow
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                UniverseMiniStory(count: row.count)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title).font(.system(size: 16.5, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                    Text(row.line).font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(0.8).foregroundStyle(Palette.ink2).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !row.isLocked {
                    Label("Play", systemImage: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .glassEffect(.regular, in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 56)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(row.isLocked ? 0.62 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(row.isLocked ? "Not available yet" : "Plays the story of your year"))
        .accessibilityIdentifier("universe.reviewRow")
    }
}
