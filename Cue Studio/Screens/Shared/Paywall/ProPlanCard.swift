//
//  ProPlanCard.swift
//  Cue Studio
//

import SwiftUI

/// A plan of the Pro screen (11.4): as tall as `ProLayout` says and as wide as `ProPlanRow` gives it, the name in bold and its price under it.
/// Yearly wears "SAVE 58%" beside its name, inside the card (owner, 30/10/2026: on its top edge the ring cut it). The chosen one has a wash of
/// yellow, and the yellow ring glides to it on a spring (`selection`, matched between the two cards).
struct ProPlanCard: View {
    let plan: ProPlan
    let detail: String
    let badge: String?
    let isSelected: Bool
    var height: CGFloat = 72
    var isCompact = false
    /// The ring that glides between the plans.
    let selection: Namespace.ID
    /// The second of the opening (`ProOpeningScript`): the badge pops as it settles.
    var time = ProOpeningScript.settled
    let action: () -> Void

    private var title: some View {
        Text(plan == .annual ? String(localized: "Yearly") : plan.label)
            .cueFont(isCompact ? 16.5 : 17, weight: .bold)
            .foregroundStyle(Palette.ink)
            .fixedSize()
    }

    @ViewBuilder
    private var badgeView: some View {
        if let badge {
            Text(badge)
                .monoFont(size: 10, weight: .bold)
                .interfaceTracking(0.5)
                .foregroundStyle(Palette.accInk)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Palette.acc, in: Capsule())
                .fixedSize()
                .scaleEffect(ProOpeningScript.badge.pose(at: time).scale)
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                // The badge beside the name while both fit whole, else under it ("Annuale" / "RISPARMIA IL 17%" in a half-width
                // card): never cut (owner, 02/11/2026).
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        title
                        badgeView
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        title
                        badgeView
                    }
                }
                .lineLimit(1)
                Text(detail).cueFont(isCompact ? 13.5 : 14).foregroundStyle(Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: height)
            .background(isSelected ? Palette.acc.opacity(0.08) : Palette.surface, in: shape)
            .overlay(shape.strokeBorder(Palette.separator, lineWidth: 1))
            .overlay {
                if isSelected {
                    shape.strokeBorder(Palette.acc, lineWidth: 2).matchedGeometryEffect(id: "selection", in: selection)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.cuePressCard)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("paywall.plan.\(plan.rawValue)")
    }
}
