//
//  ProHighlightCard.swift
//  Cue Studio
//

import SwiftUI

/// One of the two things the Pro screen puts first (owner, 30/10/2026: the emphasis on unlimited exports and Ultra AI's 30 scripts, the rest
/// plain): a mono key, the big line in bold and a small one under it. The exports' card has a fine gold edge; Ultra AI's a violet and gold rim
/// going round it (`Palette.Scripts.ultraGlow`, a lap every 4 s, still under Reduce Motion) and its ✦ turns half round on the opening.
struct ProHighlightCard: View {
    enum Kind { case exports, ultra }

    let kind: Kind
    let height: CGFloat
    var isCompact = false
    /// The second of the opening (`ProOpeningScript`).
    var time = ProOpeningScript.settled

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let lap = 4.0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(alignment: .leading, spacing: 2) {
            key
            Text(kind == .exports ? String(localized: "Unlimited") : String(localized: "\(UsagePolicy.proUltraScriptsPerMonth) scripts"))
                .cueFont(isCompact ? 20 : 22, weight: .bold)
                .tracking(-0.3)
                .foregroundStyle(kind == .exports ? Palette.ink : Palette.aiTextStrong)
            Text(kind == .exports ? String(localized: "up to 4K") : String(localized: "every month"))
                .cueFont(isCompact ? 12.5 : 13)
                .foregroundStyle(Palette.ink2)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, isCompact ? 12 : 14)
        .padding(.vertical, isCompact ? 7 : 12)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
        .background {
            switch kind {
            case .exports:
                shape.fill(Palette.surface).overlay(shape.strokeBorder(Palette.acc.opacity(0.34), lineWidth: 1))
            case .ultra:
                shape.fill(Palette.surface)
                    .overlay(shape.fill(LinearGradient(
                        colors: [Palette.Scripts.ultraDust[0].opacity(0.2), Palette.Scripts.ultraDust[0].opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )))
                    .overlay(rim(shape))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(kind == .exports ? "paywall.highlight.exports" : "paywall.highlight.ultra")
    }

    private var key: some View {
        HStack(spacing: 5) {
            if kind == .ultra {
                let glyph = ProOpeningScript.ultraGlyph.pose(at: time)
                Text(verbatim: "✦")
                    .scaleEffect(glyph.scale)
                    .rotationEffect(.degrees(glyph.rotation))
                    .opacity(glyph.opacity)
                    .accessibilityHidden(true)
            }
            Text(kind == .exports ? String(localized: "EXPORTS") : String(localized: "ULTRA AI"))
        }
        .monoFont(size: isCompact ? 10.5 : 11, weight: .semibold)
        .interfaceTracking(1.2)
        .foregroundStyle(kind == .exports ? Palette.accText : Palette.aiText)
    }

    private func rim(_ shape: RoundedRectangle) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let turn = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.lap) / Self.lap * 360
            shape.strokeBorder(
                AngularGradient(colors: Palette.Scripts.ultraGlow, center: .center, angle: .degrees(turn)), lineWidth: 1.2
            )
            .opacity(0.85)
        }
        .allowsHitTesting(false)
    }
}
