//
//  FilterFanPeek.swift
//  Cue Studio
//

import SwiftUI

/// The dots after a folded `FilterFan`'s chosen chip, one for each hidden option (up to `FilterFanPlan.peekLimit`, in a network's colour,
/// a folder's grey, All's white), a little apart: they say the row holds more. Decorative: VoiceOver never
/// sees a folded row (`FilterFanPlan.folds`).
struct FilterFanPeek: View {
    let plan: FilterFanPlan
    let colors: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: FilterFanPlan.peekSpacing) {
            ForEach(colors.indices, id: \.self) { index in
                Circle()
                    .fill(colors[index])
                    .frame(width: FilterFanPlan.peekDot, height: FilterFanPlan.peekDot)
            }
        }
        .opacity(plan.isOpen ? 0 : 1)
        .offset(x: plan.peekX)
        .animation(FilterFanMotion.peek(in: plan, reduceMotion: reduceMotion), value: plan.key)
        .zIndex(200)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
