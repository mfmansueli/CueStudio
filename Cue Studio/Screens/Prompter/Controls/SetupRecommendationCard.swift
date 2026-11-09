//
//  SetupRecommendationCard.swift
//  Cue Studio
//

import SwiftUI

/// "Recommended for YouTube Shorts", with each change against what is on screen ("Frame rate 30 fps → 60 fps", "Safe zone Custom →
/// Shorts", the creator's own choices for this take marked "This take") and a choice: **Keep as is** changes nothing, **Use Recommended**
/// applies exactly those lines. Small, just above the controls (it hugs its lines and never reaches the text window); shown before the
/// take only while something would change.
struct SetupRecommendationCard: View {
    let recommendation: SetupRecommendation
    let changes: [SetupChange]
    let onUseRecommended: () -> Void
    let onKeepAsIs: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text(recommendation.title).cueFont(.subheadline, weight: .semibold)
                } icon: {
                    Image(systemName: "sparkles").foregroundStyle(Palette.Camera.recommendationIcon)
                }
                SetupChangeList(changes: changes)
            }
            // Side by side while both names fit whole; otherwise one over the other, the recommended first (owner, 02/11/2026: no name is
            // ever cut).
            ViewThatFits(in: .horizontal) {
                FairShareLayout(spacing: 8) {
                    keepButton
                    useButton
                }
                VStack(spacing: 8) {
                    useButton
                    keepButton
                }
            }
            // The row is as tall as its buttons (the layout would take all the height it is offered).
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .background(
            LinearGradient(
                colors: [Palette.Camera.recommendationTop, Palette.Camera.recommendationBottom],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).strokeBorder(Palette.Camera.recommendationRim, lineWidth: 0.5))
        .shadow(color: Palette.Camera.recommendationShadow, radius: 25, y: 20)
        .fixedSize(horizontal: false, vertical: true)
        // A container of its own, so the card's identifier doesn't replace the buttons'.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("prompter.recommendationCard")
    }

    private var keepButton: some View {
        Button(String(localized: "Keep as is"), action: onKeepAsIs)
            .buttonStyle(.cueGlass(.compact))
            .accessibilityIdentifier("prompter.keepSetupButton")
    }

    private var useButton: some View {
        Button(String(localized: "Use Recommended"), action: onUseRecommended)
            .buttonStyle(.cuePrimary(.compact))
            .accessibilityIdentifier("prompter.useRecommendedButton")
    }
}

#if DEBUG
#Preview {
    let recommendation = SetupRecommendation(
        platform: .shorts,
        values: SetupValues(resolution: .hd1080, frameRate: .fps60, aspect: .portrait),
        hasSafeZone: true
    )
    VStack {
        Spacer()
        SetupRecommendationCard(
            recommendation: recommendation,
            changes: [
                SetupChange(item: .field(.format), current: "4:5", recommended: "9:16", isManual: true),
                SetupChange(item: .field(.frameRate), current: "30 fps", recommended: "60 fps", isManual: false),
                SetupChange(item: .safeZone, current: "Custom", recommended: "Shorts", isManual: true),
            ],
            onUseRecommended: {}, onKeepAsIs: {}
        )
        .padding()
    }
    .background(CameraFeedPlaceholder())
}
#endif
