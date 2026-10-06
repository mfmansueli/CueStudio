//
//  BgWash.swift
//  Cue Studio
//

import SwiftUI

/// The night glow behind a screen: lights over a base colour. The navigation screens (v29) have a violet light from the top left and an
/// indigo one on the right over `bg` (`BgWash()`); each chapter of the first flight has its own (`BgWash.welcome`…, the boards' `.night`).
/// It is still (no motion of its own), the same on every screen of its kind, empty states included, so it needs no Reduce Motion or Low
/// Power version.
struct BgWash: View {
    /// One light: an ellipse (radii as fractions of the screen) centred at a point (fractions too)
    /// that fades to nothing at 70% of its radius, like the prototype's `radial-gradient`.
    struct Light {
        let color: Color
        let radiusX: Double
        let radiusY: Double
        let centerX: Double
        let centerY: Double
    }

    var lights: [Light] = BgWash.navigation
    var base: Color = Palette.bg

    var body: some View {
        Canvas { context, size in
            for light in lights {
                var layer = context
                layer.translateBy(x: size.width * light.centerX, y: size.height * light.centerY)
                layer.scaleBy(x: size.width * light.radiusX, y: size.height * light.radiusY)
                layer.fill(
                    Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)),
                    with: .radialGradient(
                        Gradient(colors: [light.color, light.color.opacity(0)]), center: .zero, startRadius: 0, endRadius: 0.7
                    )
                )
            }
        }
        .background(base)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    BgWash()
}
#endif
