//
//  PaywallBenefitsCard.swift
//  Cue Studio
//

import SwiftUI

/// What Pro changes, and what stays free, as rows in one card: an icon tile, the line and a mono tag.
/// Only exporting is Pro's; the rest says it stays open.
struct PaywallBenefitsCard: View {
    private struct Benefit: Identifiable {
        let id: Int
        let systemImage: String
        let text: String
        let tag: String
        let isAI: Bool
    }

    private var benefits: [Benefit] {
        PaywallCopy.features.enumerated().map { index, text in
            Benefit(id: index, systemImage: PaywallCopy.featureImages[index], text: text, tag: PaywallCopy.featureTags[index], isAI: index == 1)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(benefits) { benefit in
                HStack(spacing: 12) {
                    Image(systemName: benefit.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(benefit.isAI ? Palette.aiText : Palette.accText)
                        .frame(width: 34, height: 34)
                        .background(benefit.isAI ? Palette.aiFill : Palette.accSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text(benefit.text)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(benefit.tag)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(benefit.isAI ? Palette.aiText : Palette.ink2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                if benefit.id < benefits.count - 1 {
                    Rectangle().fill(Palette.separator).frame(height: 0.5).padding(.leading, 60)
                }
            }
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous).strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("paywall.benefits")
    }
}
