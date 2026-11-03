//
//  VoyageChip.swift
//  Cue Studio
//

import SwiftUI

/// A platform's chip in 1.3: a quiet glass chip 38 pt tall, its colour as a dot; picked, it takes a tint and an edge of that colour and its
/// name turns bright (as 1.2's topics do). The tap leaves a ripple in the platform's colour (a 34 pt disc that grows to ×4 and fades in
/// 0.55 s). The choice is single, so a chip never goes off by being tapped again.
struct VoyageChip: View {
    let platform: Platform
    let isPicked: Bool
    /// Seconds since this chip was picked, for its ripple; nil when it is not the picked one.
    let pickAge: Double?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Circle().fill(platform.tint).frame(width: 8, height: 8)
                Text(platform.label)
            }
            .cueFont(14.5, weight: .semibold)
            .foregroundStyle(isPicked ? Palette.ink : Palette.ink2)
            .padding(.leading, 11)
            .padding(.trailing, 13)
            .frame(height: 38)
            .background { Capsule().fill(Palette.fill) }
            .background { Capsule().fill(platform.tint.opacity(isPicked ? 0.22 : 0)) }
            .overlay { Capsule().strokeBorder(isPicked ? platform.tint.opacity(0.7) : Palette.glassBorder, lineWidth: isPicked ? 1 : 0.75) }
            .overlay { ripple }
            .shadow(color: platform.tint.opacity(isPicked ? 0.35 : 0), radius: 10)
            .animation(.easeOut(duration: 0.22), value: isPicked)
            // The 44 pt target is the chip with 3 pt above and below, which the rows overlap.
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(platform.label))
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("onboarding.platform.\(platform.rawValue)")
    }

    @ViewBuilder
    private var ripple: some View {
        if let pickAge, pickAge >= 0, pickAge < 0.6 {
            let progress = min(pickAge / 0.55, 1)
            Circle()
                .fill(platform.tint.opacity(0.55))
                .frame(width: 34, height: 34)
                .scaleEffect(0.4 + 3.6 * UnitCurve.easeOut.value(at: progress))
                .opacity(0.9 * (1 - progress))
                .allowsHitTesting(false)
        }
    }
}
