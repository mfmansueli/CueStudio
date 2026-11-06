//
//  FilterFanPlacing.swift
//  Cue Studio
//

import SwiftUI

/// Puts one chip of a `FilterFan` where the plan says, with its own delay: the chip itself and its shape in the liquid under it
/// (`FilterFanLiquid`) both use it, so the two always move as one.
struct FilterFanPlacing: ViewModifier {
    let index: Int
    let plan: FilterFanPlan
    let layer: FilterFanMotion.Layer
    /// The box every chip sits in (`FilterFanPlan.maxChipWidth`), from the start of the fan.
    let boxWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let placement = plan.placement(at: index)
        content
            .opacity(placement.opacity)
            .animation(FilterFanMotion.fade(at: index, in: plan, layer: layer, reduceMotion: reduceMotion), value: plan.key)
            .scaleEffect(placement.scale)
            .frame(width: boxWidth, alignment: .leading)
            .offset(x: placement.x)  // mirrored by SwiftUI in a right-to-left language
            .animation(FilterFanMotion.move(at: index, in: plan, reduceMotion: reduceMotion), value: plan.key)
            .zIndex(placement.zIndex)
    }
}
