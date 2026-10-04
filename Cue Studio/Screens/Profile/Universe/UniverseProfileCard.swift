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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    /// The core: a breathing glow and a small star circling it (4 s and 12 s; still with Reduce Motion).
    private var core: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let breath = 1 + 0.08 * sin(time * 2 * .pi / 4)
            let angle = time * 2 * .pi / 12
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Palette.acc.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 28))
                    .frame(width: 56 * breath, height: 56 * breath)
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(hex: 0xFFFBEA), Palette.acc, Color(hex: 0xB88A00)], center: .init(x: 0.38, y: 0.34), startRadius: 0, endRadius: 12
                    ))
                    .frame(width: 20 * breath, height: 20 * breath)
                // The worlds' orbits around the core: one ring per color, then the creator's own star circling.
                Circle().strokeBorder(Palette.worldWarm.opacity(0.55), lineWidth: 1).frame(width: 28, height: 28)
                Circle().strokeBorder(Palette.worldMint.opacity(0.45), lineWidth: 1).frame(width: 36, height: 36)
                Circle().strokeBorder(Palette.worldPink.opacity(0.4), lineWidth: 1).frame(width: 44, height: 44)
                Circle().fill(.white).frame(width: 3, height: 3)
                    .offset(x: 22 * CGFloat(cos(angle)), y: 22 * CGFloat(sin(angle)))
            }
            .frame(width: 44, height: 44)
        }
        .accessibilityHidden(true)
    }
}
