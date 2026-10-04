//
//  UniverseProfileCard.swift
//  Cue Studio
//

import SwiftUI

/// On Profile: how many videos were shared and how far the next milestone is, with a small planet in orbit. Opens
/// "Your universe".
struct UniverseProfileCard: View {
    @Environment(MilestoneService.self) private var milestones

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR UNIVERSE · \(milestones.shares) SHARED")
                    .font(CueStudioFont.hud).tracking(1).foregroundStyle(Palette.accText)
                Text(message)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                ProgressView(value: milestones.progress).tint(Palette.acc)
            }
            planet
        }
        .padding(16)
        .background(Palette.surface, in: shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.universeCard")
    }

    private var message: String {
        guard let next = milestones.nextMilestone, let icon = AppIconChoice(milestone: next) else {
            return String(localized: "Every milestone is behind you")
        }
        if milestones.shares == 0 { return String(localized: "Share your first video to light your first star") }
        return String(localized: "\(next - milestones.shares) more videos to \(icon.title)")
    }

    private var planet: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle().fill(Palette.aiFill).frame(width: 52, height: 52)
                Circle().fill(Color(hex: 0xE4DEFF)).frame(width: 24, height: 24)
                ForEach(0..<5, id: \.self) { index in
                    let angle = Double(index) / 5 * 2 * .pi + time * 0.3
                    Circle()
                        .fill([Palette.worldWarm, Palette.worldMint, Palette.worldPink, Palette.acc, Color.white][index])
                        .frame(width: 5, height: 5)
                        .offset(x: cos(angle) * 40, y: sin(angle) * 30)
                }
            }
            .frame(width: 96, height: 80)
        }
        .accessibilityHidden(true)
    }
}
