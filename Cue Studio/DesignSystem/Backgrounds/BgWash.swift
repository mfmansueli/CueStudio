//
//  BgWash.swift
//  Cue Studio
//

import SwiftUI

/// The night glow behind the navigation screens (v29): a violet light from the top left and an indigo
/// one on the right, over `bg`. It is still (no motion of its own), the same on every screen, empty
/// states included, so it needs no Reduce Motion or Low Power version.
struct BgWash: View {
    /// One light: an ellipse (radii as fractions of the screen) centred at a point (fractions too)
    /// that fades to nothing at 70% of its radius, like the prototype's `radial-gradient`.
    private struct Light {
        let color: Color
        let radiusX: Double
        let radiusY: Double
        let centerX: Double
        let centerY: Double
    }

    private let lights = [
        Light(color: Palette.bgWashViolet, radiusX: 0.7, radiusY: 0.3, centerX: 0.2, centerY: 0.06),
        Light(color: Palette.bgWashIndigo, radiusX: 0.55, radiusY: 0.28, centerX: 0.85, centerY: 0.6),
    ]

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
        .background(Palette.bg)
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
