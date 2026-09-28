//
//  TrimHandleView.swift
//  Cue Studio
//

import SwiftUI

/// One yellow trim handle. Thin to look at; the strip gives it a 38 pt reach for the finger.
/// While dragged it turns white and its grip grows.
struct TrimHandleView: View {
    let edge: TrimHandle
    let isActive: Bool

    var body: some View {
        let isStart = edge == .start
        UnevenRoundedRectangle(
            topLeadingRadius: isStart ? 6 : 0, bottomLeadingRadius: isStart ? 6 : 0,
            bottomTrailingRadius: isStart ? 0 : 6, topTrailingRadius: isStart ? 0 : 6,
            style: .continuous
        )
        .fill(isActive ? Palette.ink : Palette.acc)
        .overlay {
            Capsule()
                .fill(Palette.accInk.opacity(isActive ? 0.9 : 0.5))
                .frame(width: 2, height: isActive ? 24 : 16)
        }
        .shadow(color: isActive ? Palette.accBorder : .clear, radius: 6)
        .frame(width: TimelineLayout.handleWidth)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
