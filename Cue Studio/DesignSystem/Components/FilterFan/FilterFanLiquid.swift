//
//  FilterFanLiquid.swift
//  Cue Studio
//

import SwiftUI

/// The chips' fill under a `FilterFan`, as one liquid: where two chips are close (one leaving the chosen one, or coming home), a neck of
/// the fill joins them and stretches until it breaks. At rest it is exactly the chips' capsules.
///
/// The classic metaball: the capsules in white on black, blurred, the contrast pushed so the blur's half-way line becomes a hard edge,
/// then the brightness taken as the mask of `Palette.fill`. The capsules themselves are added to the mask sharp, so a capsule's round ends
/// never shrink. The text sits above this layer, never blurred. Two chips `spacing` apart at rest stay apart: the blur reaches half way
/// only under ~3 pt.
struct FilterFanLiquid: View {
    let plan: FilterFanPlan
    let chipHeight: CGFloat
    let boxWidth: CGFloat
    /// The chip a finger is on: its fill sinks with it (`PressResponse`).
    let pressed: Int?

    static let blur: CGFloat = 4
    /// Room around the chips for the blur, and for a chip running a little past its place.
    private static let margin: CGFloat = 16

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let width = max(plan.openWidth, boxWidth) + 2 * Self.margin
        let height = chipHeight + 2 * Self.margin
        Palette.fill
            .frame(width: width, height: height)
            .mask {
                ZStack {
                    capsules
                    capsules
                        .background(Color.black)
                        .compositingGroup()
                        .blur(radius: Self.blur)
                        .contrast(12)
                        .luminanceToAlpha()
                }
                .frame(width: width, height: height)
            }
            .padding(-Self.margin)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var capsules: some View {
        ZStack(alignment: .leading) {
            ForEach(plan.widths.indices, id: \.self) { index in
                Capsule()
                    .fill(.white)
                    .frame(width: plan.widths[index], height: chipHeight)
                    .scaleEffect(pressed == index && !reduceMotion ? PressResponse.compactDepth : 1)
                    .animation(pressed == index ? CueMotion.pressIn : CueMotion.pressRelease, value: pressed == index)
                    .modifier(FilterFanPlacing(index: index, plan: plan, layer: .fill, boxWidth: boxWidth))
            }
        }
        .frame(width: max(plan.openWidth, boxWidth), height: chipHeight, alignment: .leading)
        .padding(Self.margin)
    }
}
