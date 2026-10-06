//
//  ImpactRing.swift
//  Cue Studio
//

import SwiftUI

/// The thin ring that opens where something lands (a star on a dot, a world in its orbit). It is a still ring; the scene scales and fades it
/// with `.motion(pose)` (the boards' 0.3 → 3 or 5 over 0.6–1.2 s, `cubic-bezier(.1,.7,.3,1)`).
struct ImpactRing: View {
    let diameter: CGFloat
    var color: Color = .white
    var lineWidth: CGFloat = 1.2

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: lineWidth)
            .frame(width: diameter, height: diameter)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
