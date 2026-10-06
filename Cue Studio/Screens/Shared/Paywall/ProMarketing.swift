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
        VStack(alignment: .leading, spacing: 46) {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: PaywallCopy.eyebrow(for: context))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
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
                    .font(.system(size: 13.5))
                    .foregroundStyle(Palette.ink.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
            .revealed(0, at: time)
            benefits
        }
        .padding(.horizontal, 16)
    }

    private var benefits: some View {
        let items = PaywallCopy.visibleBenefits(aiIsAvailable: aiIsAvailable)
        return VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, benefit in
                HStack(spacing: 10) {
                    Text(benefit.mark).foregroundStyle(Palette.accText)
                    Text(benefit.text)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(benefit.tag)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(tint(benefit.tone))
                }
                .frame(minHeight: 38)
                .overlay(alignment: .top) { if index > 0 { Rectangle().fill(Palette.separator).frame(height: 0.5) } }
                .revealed(index + 1, at: time)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
        // The card comes up with its first row, not before it: an empty box under the warp spoils the opening.
        .background {
            let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
            shape.fill(Palette.surface)
                .overlay(shape.strokeBorder(Palette.separator, lineWidth: 0.5))
                .revealed(1, at: time)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("paywall.benefits")
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
