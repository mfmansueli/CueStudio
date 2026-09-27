//
//  TakeTile.swift
//  Cue Studio
//

import SwiftUI

/// Portrait tile for a take: thumbnail, best badge, number and duration.
struct TakeTile: View {
    let take: Take
    var width: CGFloat = 104
    var height: CGFloat = 184

    var body: some View {
        TakeThumbnail(take: take)
            .frame(width: width, height: height)
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 70)
            }
            .overlay(alignment: .topLeading) {
                if take.isBest { BestBadge().padding(8) }
            }
            .overlay(alignment: .bottom) {
                HStack {
                    Text(take.label)
                    Spacer(minLength: 4)
                    Text(DurationText.clock(take.duration))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.8))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.bottom, 9)
            }
            .clipShape(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityText))
            .accessibilityAddTraits(.isButton)
    }

    private var accessibilityText: String {
        let base = "\(take.label), \(DurationText.clock(take.duration))"
        return take.isBest ? base + ", " + String(localized: "best take") : base
    }
}
