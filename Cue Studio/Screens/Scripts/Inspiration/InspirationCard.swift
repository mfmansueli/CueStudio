//
//  InspirationCard.swift
//  Cue Studio
//

import SwiftUI

/// The featured idea of Find inspiration, one brief read top to bottom: the topic's bar and a small mono line ("PERSONAL FINANCE ·
/// EXPLAINER"), the video's title (the strongest line), then "YOUR POINT OF VIEW" and "OPENING LINE", each a label over a comfortable line
/// of text, apart by a hairline. A softly rounded violet night with a light from its top corner and the cards' depth (`cardDepth`).
/// An idea without a brief is its title alone. A new card's lines rise in one after the other and a light crosses it once; Reduce Motion:
/// they are simply there.
struct InspirationCard: View {
    let content: InspirationCardContent
    let worldColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The lines have risen into place.
    @State private var isRevealed = false
    /// The light has crossed the card.
    @State private var hasSwept = false

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
                    .hudFont()
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(Palette.aiText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("inspiration.card.category")
            }
            .rises(isRevealed, step: 0)
            Text(content.title)
                .font(.title2.weight(.bold))
                .tracking(-0.3)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("inspiration.card.title")
                .rises(isRevealed, step: 1)
            if let angle = content.angle {
                // The creator's own way into the subject: what they think, show or have lived that others don't.
                section(label: "Your point of view", identifier: "inspiration.card.angle") {
                    Text(angle)
                }
                .rises(isRevealed, step: 2)
            }
            if let opening = content.openingLine {
                section(label: "Opening line", identifier: "inspiration.card.opening") {
                    // The quotes are the card's: a line to say, never a claim the creator made.
                    Text(verbatim: "“\(opening)”")
                        .italic()
                }
                .rises(isRevealed, step: 3)
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
        .overlay { sweep }
        .overlay { Self.shape.strokeBorder(Palette.Scripts.inspirationCardBorder, lineWidth: 0.5) }
        .cardDepth(Self.shape, edge: nil)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inspiration.card")
        .onAppear {
            guard !reduceMotion else {
                // Simply there: no line rises, no light crosses.
                var still = Transaction()
                still.disablesAnimations = true
                withTransaction(still) {
                    isRevealed = true
                    hasSwept = true
                }
                return
            }
            isRevealed = true
            withAnimation(CueMotion.inspirationSweep.delay(0.08)) { hasSwept = true }
        }
    }

    /// A soft band of light that crosses the new card once, from its leading edge to past its trailing one, then is gone (clipped).
    private var sweep: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(
                colors: [.clear, Palette.Scripts.inspirationSweep, .clear], startPoint: .leading, endPoint: .trailing
            )
            .frame(width: width * 0.5, height: proxy.size.height * 1.6)
            .rotationEffect(.degrees(16))
            .position(x: hasSwept ? width * 1.35 : -width * 0.35, y: proxy.size.height / 2)
        }
        .blendMode(.plusLighter)
        .clipShape(Self.shape)
        .opacity(hasSwept && reduceMotion ? 0 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func section(label: LocalizedStringKey, identifier: String, @ViewBuilder text: () -> Text) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Palette.separator)
                .frame(height: 0.5)
                .padding(.bottom, 10)
                .accessibilityHidden(true)
            // VoiceOver reads the label with its text, as one line ("Your point of view, …").
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .monoFont(.caption2, weight: .semibold)
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

private extension View {
    /// A line of a new idea rising into place: from a little lower, blurred and clear, a beat after the line above it (`step`).
    func rises(_ isRevealed: Bool, step: Int) -> some View {
        opacity(isRevealed ? 1 : 0)
            .offset(y: isRevealed ? 0 : 8)
            .blur(radius: isRevealed ? 0 : 4)
            .animation(CueMotion.inspirationLine.delay(0.05 + Double(step) * CueMotion.inspirationLineStagger), value: isRevealed)
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
