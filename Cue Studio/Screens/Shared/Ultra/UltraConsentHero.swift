//
//  UltraConsentHero.swift
//  Cue Studio
//

import SwiftUI

/// The top of Ultra AI's permission sheet: its ✦ in a small galaxy. Two tilted orbits in Ultra AI's violet and gold (`Palette.Scripts.ultraGlow`)
/// turn slowly round it, each with a moon, and a few stars twinkle. As the sheet opens the ✦ ignites (`UltraMotion.ignite`, small and turned,
/// then past its size and back) with a glow that settles into a slow breath. Decorative. Under Reduce Motion everything stands still and only
/// fades in.
struct UltraConsentHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = false

    static let height: CGFloat = 156

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                Canvas { canvas, size in
                    Self.draw(in: &canvas, size: size, time: time)
                }
                star(breath: reduceMotion ? 0 : (sin(time * 1.6) + 1) / 2)
            }
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .opacity(lit ? 1 : 0)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : UltraMotion.ignite) { lit = true }
        }
        .accessibilityHidden(true)
    }

    /// The ✦, igniting, then breathing its glow.
    private func star(breath: Double) -> some View {
        Text(verbatim: "✦")
            .cueFont(46, weight: .bold)
            .foregroundStyle(Palette.aiTextStrong)
            .shadow(color: Palette.aiText.opacity(0.55 + 0.25 * breath), radius: 14 + 8 * breath)
            .scaleEffect(lit ? 1 : 0.2)
            .rotationEffect(.degrees(lit || reduceMotion ? 0 : -70))
    }

    /// Orbit `index`: its tilt, its size as a share of the hero's height, and how fast its moon goes (turns a second).
    private static let orbits: [(tilt: Double, width: CGFloat, height: CGFloat, speed: Double)] = [
        (-18, 1.55, 0.42, 0.07),
        (24, 1.15, 0.30, -0.1),
    ]

    /// Where the twinkling stars sit, as shares of the width and height, and their phase.
    private static let sparkles: [(x: CGFloat, y: CGFloat, phase: Double)] = [
        (0.18, 0.22, 0), (0.82, 0.18, 1.3), (0.27, 0.8, 2.1), (0.74, 0.84, 0.7), (0.9, 0.52, 2.8), (0.1, 0.55, 1.9),
    ]

    private static func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        // The glow the ✦ sits in.
        let glow = size.height * 0.62
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - glow, y: center.y - glow, width: glow * 2, height: glow * 2)),
            with: .radialGradient(
                Gradient(colors: [Palette.aiText.opacity(0.28), Palette.aiText.opacity(0)]),
                center: center, startRadius: 0, endRadius: glow
            )
        )
        for sparkle in sparkles {
            let twinkle = (sin(time * 2.2 + sparkle.phase) + 1) / 2
            let radius = 1 + 0.8 * twinkle
            let point = CGPoint(x: size.width * sparkle.x, y: size.height * sparkle.y)
            canvas.fill(
                Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Palette.aiTextStrong.opacity(0.35 + 0.5 * twinkle))
            )
        }
        for orbit in orbits {
            let radiusX = size.height * orbit.width / 2
            let radiusY = size.height * orbit.height / 2
            var ring = canvas
            ring.translateBy(x: center.x, y: center.y)
            ring.rotate(by: .degrees(orbit.tilt))
            let spin = time * orbit.speed * 2 * .pi
            ring.stroke(
                Path(ellipseIn: CGRect(x: -radiusX, y: -radiusY, width: radiusX * 2, height: radiusY * 2)),
                with: .conicGradient(Gradient(colors: Palette.Scripts.ultraGlow.map { $0.opacity(0.55) }), center: .zero, angle: .radians(spin)),
                lineWidth: 1.2
            )
            let moon = CGPoint(x: radiusX * cos(spin), y: radiusY * sin(spin))
            let moonRadius: CGFloat = 3.5
            ring.fill(
                Path(ellipseIn: CGRect(x: moon.x - moonRadius * 2.2, y: moon.y - moonRadius * 2.2, width: moonRadius * 4.4, height: moonRadius * 4.4)),
                with: .color(Palette.aiText.opacity(0.22))
            )
            ring.fill(
                Path(ellipseIn: CGRect(x: moon.x - moonRadius, y: moon.y - moonRadius, width: moonRadius * 2, height: moonRadius * 2)),
                with: .color(Palette.aiTextStrong)
            )
        }
    }
}

#if DEBUG
#Preview {
    UltraConsentHero()
        .background(Palette.bg)
}
#endif
