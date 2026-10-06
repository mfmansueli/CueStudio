//
//  ProfileUniverseRow.swift
//  Cue Studio
//

import SwiftUI

/// 9.1 · "Your universe": the 30 pt core (a ball in a ring with a bead that goes round in 7 s), "Your universe" with "2026 · 3 topics" under it, the videos of the year on the right and a chevron. A new
/// account says "0 videos · Starts with your first share"; a new year, "0 videos · 2027 · last year 23 videos".
struct ProfileUniverseRow: View {
    let summary: ProfileUniverseSummary

    @Environment(PersonalizationService.self) private var personalization

    var body: some View {
        HStack(spacing: 14) {
            ProfileMiniCore(color: personalization.coreColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your universe")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(summary.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(summary.trailing)
                .font(.system(size: 15))
                .foregroundStyle(Palette.ink2)
                .lineLimit(1)
                .fixedSize()
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink3)
                .accessibilityHidden(true)
        }
        .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 14))
        .frame(minHeight: 56)
        .profileBlock()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.universeCard")
    }
}
