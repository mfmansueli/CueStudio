//
//  ProPlanCard.swift
//  Cue Studio
//

import SwiftUI

/// A plan of the Pro screen (11.4): 72 pt tall and as wide as `ProPlanRow` gives it, the name in bold and its price under it; the chosen one has a
/// yellow ring and a wash of yellow, and Yearly wears "SAVE 58%" on its top edge.
struct ProPlanCard: View {
    let plan: ProPlan
    let detail: String
    let badge: String?
    let isSelected: Bool
    let action: () -> Void

    static let height: CGFloat = 72

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(plan == .annual ? String(localized: "Yearly") : plan.label).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink)
                Text(detail).font(.system(size: 13)).foregroundStyle(Palette.flightInk.opacity(0.75)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.height)
            .background(isSelected ? Palette.acc.opacity(0.12) : Palette.surface, in: shape)
            .overlay(shape.strokeBorder(isSelected ? Palette.acc : Palette.separator, lineWidth: isSelected ? 2 : 0.5))
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Palette.accInk)
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(Palette.acc, in: Capsule())
                        .offset(x: -10, y: -9)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("paywall.plan.\(plan.rawValue)")
    }
}
