//
//  GlowDot.swift
//  Cue Studio
//

import SwiftUI

/// A point of light: a disc with the glow the boards give every star, spark and core (`box-shadow: 0 0 6px colour`), never a flat circle.
/// Place it with `.motion(pose)` or `.position`.
struct GlowDot: View {
    let diameter: CGFloat
    var color: Color = .white
    /// The glow's colour (the dot's own, a little see-through, by default) and its blur radius.
    var glow: Color?
    var glowRadius: CGFloat = 6

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .shadow(color: glow ?? color.opacity(0.9), radius: glowRadius)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    GlowDot(diameter: 6, color: Palette.starCream)
        .padding(40)
        .background(Palette.flightNight)
}
#endif
