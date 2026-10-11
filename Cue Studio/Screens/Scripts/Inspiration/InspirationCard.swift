//
//  InspirationCard.swift
//  Cue Studio
//

import SwiftUI

/// The featured idea of Find inspiration, one brief read top to bottom: the topic's bar and a small mono line ("PERSONAL FINANCE ·
/// EXPLAINER"), the video's title (the strongest line), then "YOUR ANGLE" and "OPENING LINE", each a label over a comfortable line of
/// text, apart by a hairline. A softly rounded violet night with a light from its top corner and the cards' depth (`cardDepth`).
/// An idea without a brief is its title alone.
struct InspirationCard: View {
    let content: InspirationCardContent
    let worldColor: Color

    private static let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if content.isLogbookNote {
                    CueIconView(.logbook, size: 13)
                        .foregroundStyle(Palette.aiText)
                        .accessibilityHidden(true)
                } else {
                    ThemeRail(color: worldColor, size: .chip)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                }
                Text(content.category)
                    .font(CueStudioFont.hud)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(Palette.aiText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("inspiration.card.category")
            }
            Text(content.title)
                .font(.title2.weight(.bold))
                .tracking(-0.3)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("inspiration.card.title")
            if let angle = content.angle {
                section(label: "Your angle", identifier: "inspiration.card.angle") {
                    Text(angle)
                }
            }
            if let opening = content.openingLine {
                section(label: "Opening line", identifier: "inspiration.card.opening") {
                    // The quotes are the card's: a line to say, never a claim the creator made.
                    Text(verbatim: "“\(opening)”")
                        .italic()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            Self.shape.fill(Palette.Scripts.inspirationCard)
                .overlay {
                    Self.shape.fill(RadialGradient(
                        colors: [Palette.Scripts.inspirationCardGlow, .clear], center: .topLeading, startRadius: 0, endRadius: 260
                    ))
                }
        }
        .overlay { Self.shape.strokeBorder(Palette.Scripts.inspirationCardBorder, lineWidth: 0.5) }
        .cardDepth(Self.shape, edge: nil)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inspiration.card")
    }

    private func section(label: LocalizedStringKey, identifier: String, @ViewBuilder text: () -> Text) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Palette.separator)
                .frame(height: 0.5)
                .padding(.bottom, 10)
                .accessibilityHidden(true)
            // VoiceOver reads the label with its text, as one line ("Your angle, …").
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1)
                    // `ink2`, not `inkHint`: under the card's light, `inkHint` falls to about 4.2:1.
                    .foregroundStyle(Palette.ink2)
                text()
                    .font(.body)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
        }
        .padding(.top, 14)
    }
}

#if DEBUG
#Preview {
    InspirationCard(
        content: InspirationCardContent(idea: InspirationSamples.finance, topics: [], logbookLabel: "From your Logbook"), worldColor: Palette.World.warm
    )
    .padding()
    .background(Palette.sheetNight)
}
#endif
