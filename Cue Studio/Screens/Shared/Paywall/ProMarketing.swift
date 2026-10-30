//
//  ProMarketing.swift
//  Cue Studio
//

import SwiftUI

/// What the Pro screen says above its plans (11.4, with the owner's hierarchy of 30/10/2026): the eyebrow, the title and the line under it; the
/// two highlights (unlimited exports and, where Ultra AI is offered, its 30 scripts a month: `ProHighlightCard`), side by side, Ultra AI's
/// first in its own calm Pro; then the rest in plain lines. On the regular Pro each block rises in its turn as the galaxy unfurls (`time`); the
/// calm Pro shows it all at once.
struct ProMarketing: View {
    let context: PaywallContext
    var layout = ProLayout.regular
    var aiIsAvailable = true
    /// Ultra AI is offered on this iPhone: its free scripts and Pro's monthly ones are said.
    var ultraIsOffered = false
    /// The second of the opening (`ProOpeningScript`); the end of it shows everything in place.
    var time = ProOpeningScript.settled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading
            highlights.padding(.top, layout.cardsGap)
            plainList.padding(.top, layout.listGap)
        }
        .padding(.horizontal, 16)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: PaywallCopy.eyebrow(for: context))
                    .monoFont(size: layout.isCompact ? 11.5 : 12, weight: .semibold)
                    .interfaceTracking(1.5)
                    .foregroundStyle(context == .ultra ? Palette.aiText : Palette.accText)
                Text(PaywallCopy.title(for: context))
                    .cueFont(layout.isCompact ? 27 : 28, weight: .bold)
                    .tracking(-0.56)
                    .foregroundStyle(Palette.ink)
                    // The calm title breaks after "your": "Keep sharing your / universe."
                    .frame(maxWidth: context == .export ? 250 : .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .revealed(.title, at: time)
            Text(PaywallCopy.subtitle(for: context, ultraIsOffered: ultraIsOffered))
                .cueFont(layout.isCompact ? 14 : 15)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .revealed(.subtitle, at: time)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var showsUltra: Bool { context == .ultra || ultraIsOffered }

    private var highlights: some View {
        HStack(spacing: 8) {
            if context == .ultra { ultraCard }
            ProHighlightCard(kind: .exports, height: layout.cardHeight, isCompact: layout.isCompact, time: time)
                .revealed(.exports, at: time)
            if context != .ultra, showsUltra { ultraCard }
        }
    }

    private var ultraCard: some View {
        ProHighlightCard(kind: .ultra, height: layout.cardHeight, isCompact: layout.isCompact, time: time)
            .revealed(.ultra, at: time)
    }

    /// The rest of what Pro offers: a faint ✓ and the line, plain.
    private var plainList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(PaywallCopy.visibleBenefits(aiIsAvailable: aiIsAvailable).enumerated()), id: \.offset) { index, benefit in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.fixed(11, weight: .semibold))
                        .foregroundStyle(Palette.ink2)
                        .accessibilityHidden(true)
                    Text(benefit.text)
                        .cueFont(layout.isCompact ? 14 : 15)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: layout.rowHeight)
                .revealed(.list, line: index, at: time)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("paywall.benefits")
    }
}

extension View {
    /// Rises this block 18 pt and out of the blur at its turn (`ProOpeningScript.reveal`).
    func revealed(_ block: ProOpeningScript.Block, line: Int = 0, at time: Double) -> some View {
        let pose = ProOpeningScript.reveal(block, line: line).pose(at: time)
        return opacity(pose.opacity).offset(y: pose.y).blur(radius: pose.blur)
    }
}
