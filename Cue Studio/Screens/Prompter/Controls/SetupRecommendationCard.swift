//
//  SetupRecommendationCard.swift
//  Cue Studio
//

import SwiftUI

/// "Recommended for TikTok · 1080p instead of your usual 4K", with a choice. Shown before the take
/// when the platform's setup differs from the Creator Setup; the creator's setup stays in use until
/// they pick, and picking only affects this video.
struct SetupRecommendationCard: View {
    let recommendation: SetupRecommendation
    let conflicts: [SetupConflict]
    /// The creator's usual values for the same fields: "9:16 · 4K · 30 fps".
    let usualSummary: String
    let onUseRecommended: () -> Void
    let onKeepSetup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Palette.acc)
                    .frame(width: 36, height: 36)
                    .background(Palette.accSoft, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(recommendation.title).font(.headline)
                    Text(recommendation.summary)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Palette.ink2)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .padding(.top, 2)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: 8) {
                Button(keepTitle, action: onKeepSetup)
                    .buttonStyle(.cueSecondary())
                    .accessibilityIdentifier("prompter.keepSetupButton")
                Button(useTitle, action: onUseRecommended)
                    .buttonStyle(.cuePrimary())
                    .accessibilityIdentifier("prompter.useRecommendedButton")
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 25, y: 20)
        .accessibilityIdentifier("prompter.recommendationCard")
    }

    /// One difference reads as a sentence; several show the whole usual setup.
    private var detail: String {
        if conflicts.count == 1, let conflict = conflicts.first { return conflict.sentence }
        return String(localized: "Your usual setup is \(usualSummary).")
    }

    private var useTitle: String {
        if conflicts.count == 1, let conflict = conflicts.first { return String(localized: "Use \(conflict.recommended)") }
        return String(localized: "Use Recommended")
    }

    private var keepTitle: String {
        if conflicts.count == 1, let conflict = conflicts.first { return String(localized: "Keep \(conflict.usual)") }
        return String(localized: "Keep My Setup")
    }
}

#if DEBUG
#Preview {
    let recommendation = SetupRecommendation(
        platform: .tiktok,
        values: SetupValues(resolution: .hd1080, frameRate: .fps30, aspect: .portrait),
        hasSafeZone: true
    )
    SetupRecommendationCard(
        recommendation: recommendation,
        conflicts: [SetupConflict(field: .quality, recommended: "1080p", usual: "4K")],
        usualSummary: "9:16 · 4K · 30 fps",
        onUseRecommended: {}, onKeepSetup: {}
    )
    .padding()
    .background(CameraFeedPlaceholder())
}
#endif
