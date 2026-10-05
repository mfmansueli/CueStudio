//
//  UniverseProfileCard.swift
//  Cue Studio
//

import SwiftUI

/// 9.1 · "Your universe" in one row: the animated core "YOU", how many videos were shared, how many topics and how far the next
/// milestone is. Opens "Your universe".
struct UniverseProfileCard: View {
    @Environment(MilestoneService.self) private var milestones
    @Environment(CreatorProfileService.self) private var profile
    @Environment(PersonalizationService.self) private var personalization

    var body: some View {
        HStack(spacing: 14) {
            core
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink3)
        }
        .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 14))
        .frame(minHeight: 80)
        .profileBlock(glow: RadialGradient(colors: [Palette.acc.opacity(0.12), .clear], center: .leading, startRadius: 0, endRadius: 220))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.universeCard")
    }

    private var headline: String {
        milestones.shares == 0 ? String(localized: "Your first star is one video away") : String(localized: "\(milestones.shares) videos shared")
    }

    private var detail: String {
        let topics = profile.profile.niches.count + profile.profile.customTopics.count
        guard let next = milestones.nextMilestone else { return String(localized: "Every milestone is behind you") }
        return String(localized: "\(topics) topics · \(next - milestones.shares) to your next milestone")
    }

    /// The core (9.1): the 44 pt version, with the colour the creator chose.
    private var core: some View {
        UniverseCore(color: personalization.coreColor, style: .compact)
    }
}
