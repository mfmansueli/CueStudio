//
//  ProfileUniverseRow.swift
//  Cue Studio
//

import SwiftUI

/// 9.1 · "Your universe" (owner's redesign, 21/10/2026, kept short), on the solid surface of the other cards: the universe in small, live
/// (`ProfileMiniUniverse`: the core in the creator's light, a planet per network shared to), its title and one line ("2026 · 1 video",
/// `ProfileUniverseSummary`). Empty: "Your universe is waiting".
struct ProfileUniverseRow: View {
    let summary: ProfileUniverseSummary

    @Environment(PersonalizationService.self) private var personalization

    var body: some View {
        HStack(spacing: 14) {
            ProfileMiniUniverse(core: personalization.coreColor, networks: summary.networks)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: summary.title)
                    .font(.title3.bold())
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: summary.detail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink3)
                .accessibilityHidden(true)
        }
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14))
        .profileBlock()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.universeCard")
    }
}
