//
//  ProMarketing.swift
//  Cue Studio
//

import SwiftUI

/// What the Pro screen says above its plans (11.4): "CUE PRO", the title, the line under it and the list of what Pro
/// offers. On the regular Pro each block comes up in its turn after the opening's light (`time`); the calm Pro shows it all at once.
struct ProMarketing: View {
    let context: PaywallContext
    var aiIsAvailable = true
    /// The second of the opening (`ProOpeningScript`); the end of it shows everything in place.
    var time = ProOpeningScript.settled

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: PaywallCopy.eyebrow(for: context))
                    .monoFont(size: 12, weight: .semibold)
                    .interfaceTracking(1.5)
                    .foregroundStyle(Palette.accText)
                Text(PaywallCopy.title(for: context))
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.56)
                    .foregroundStyle(Palette.ink)
                    // The calm title breaks after "your": "Keep sharing your / universe."
                    .frame(maxWidth: context == .export ? 250 : .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(PaywallCopy.subtitle(for: context))
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
            .revealed(0, at: time)
            benefits
        }
        .padding(.horizontal, 16)
    }

    /// Each line with its symbol in a tinted tile, the line in 16 pt and its tag.
    private var benefits: some View {
        let items = PaywallCopy.visibleBenefits(aiIsAvailable: aiIsAvailable)
        return VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, benefit in
                HStack(spacing: 12) {
                    Image(systemName: benefit.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(symbolTint(benefit.tone))
                        .frame(width: 32, height: 32)
                        .background(symbolTint(benefit.tone).opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Text(benefit.text)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(benefit.tag)
                        .monoFont(size: 10.5, weight: .bold)
                        .interfaceTracking(0.6)
                        .foregroundStyle(tint(benefit.tone))
                }
                .padding(.vertical, 8)
                .frame(minHeight: 50)
                .overlay(alignment: .top) { if index > 0 { Rectangle().fill(Palette.separator).frame(height: 0.5) } }
                .revealed(index + 1, at: time)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        // The card comes up with its first row, not before it: an empty box under the warp spoils the opening.
        .background {
            let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
            shape.fill(Palette.surface)
                .overlay(shape.strokeBorder(Palette.separator, lineWidth: 0.5))
                .revealed(1, at: time)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("paywall.benefits")
    }

    /// The symbol's colour: Cue's yellow, or the lilac of the AI.
    private func symbolTint(_ tone: ProBenefit.Tone) -> Color {
        tone == .ai ? Palette.aiText : Palette.accText
    }

    private func tint(_ tone: ProBenefit.Tone) -> Color {
        switch tone {
        case .plain: Palette.ink2
        case .ai: Palette.aiText
        case .universe: Palette.accText
        }
    }
}

extension View {
    /// Fades this block up 18 pt and out of the blur at its turn (`ProOpeningScript.reveal`).
    func revealed(_ index: Int, at time: Double) -> some View {
        let pose = ProOpeningScript.reveal(index).pose(at: time)
        return opacity(pose.opacity).offset(y: pose.y).blur(radius: pose.blur)
    }
}
