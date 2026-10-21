//
//  ProfileMiniUniverse.swift
//  Cue Studio
//

import SwiftUI

/// The universe in small on the Profile's card (owner's redesign, 21/10/2026): the core in the creator's light, breathing in its halo, three
/// faint orbits, and one planet per network shared to this year (`networks`, the most shared nearest), each in its network's colour going
/// round at its own pace; the nearest carries a small moon. Empty, the orbits are dotted and drift, and one dashed planet waits on the
/// first. Reduce Motion: everything at rest. Decorative.
struct ProfileMiniUniverse: View {
    let core: CoreColor
    let networks: [Platform]

    static let size: CGFloat = 104
    /// Seconds for each orbit's planet to go round, nearest first.
    private static let laps: [Double] = [14, 22, 34]
    private static let radii: [CGFloat] = [0.23, 0.35, 0.47]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        AmbientTimeline { ambient in
            let time = reduceMotion ? 0 : ambient.seconds
            Canvas { canvas, size in
                draw(in: &canvas, size: size, time: time)
            }
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityHidden(true)
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let isEmpty = networks.isEmpty
        for (index, fraction) in Self.radii.enumerated() {
            let radius = size.width * fraction
            let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            if isEmpty {
                let style = StrokeStyle(lineWidth: 1, dash: [2, 5], dashPhase: -time * 4 * Double(index + 1))
                canvas.stroke(ring, with: .color(Palette.ink.opacity(0.16 - 0.04 * Double(index))), style: style)
            } else {
                canvas.stroke(ring, with: .color(Palette.ink.opacity(0.08 - 0.015 * Double(index))), lineWidth: 1)
            }
        }
        drawCore(in: &canvas, center: center, time: time)
        if isEmpty {
            // The first planet, waiting on the nearest orbit.
            let spot = point(center, radius: size.width * Self.radii[0], angle: 0)
            let box = CGRect(x: spot.x - 4.5, y: spot.y - 4.5, width: 9, height: 9)
            canvas.stroke(Path(ellipseIn: box), with: .color(Palette.ink.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            return
        }
        for (index, platform) in networks.prefix(Self.radii.count).enumerated() {
            let lap = Self.laps[index]
            let direction: Double = index.isMultiple(of: 2) ? 1 : -1
            let angle = Double(index) * 2.1 + direction * time / lap * 2 * .pi
            let spot = point(center, radius: size.width * Self.radii[index], angle: angle)
            let radius = CGFloat(6 - index)
            canvas.drawLayer { layer in
                layer.addFilter(.shadow(color: platform.tint.opacity(0.7), radius: 4))
                layer.fill(Path(ellipseIn: CGRect(x: spot.x - radius, y: spot.y - radius, width: radius * 2, height: radius * 2)), with: .color(platform.tint))
            }
            if index == 0 {
                let moon = point(spot, radius: radius + 4, angle: -angle * 3)
                canvas.fill(Path(ellipseIn: CGRect(x: moon.x - 1.6, y: moon.y - 1.6, width: 3.2, height: 3.2)), with: .color(Palette.ink.opacity(0.9)))
            }
        }
    }

    /// The core: its glow breathing every 3.6 s, and the ball lit from the top left in its four stops.
    private func drawCore(in canvas: inout GraphicsContext, center: CGPoint, time: Double) {
        let breath = (1 + sin(time / 3.6 * 2 * .pi)) / 2
        let glow = Color(hex: core.glow.hex)
        let halo = 22 + 6 * breath
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)),
            with: .radialGradient(
                Gradient(colors: [glow.opacity(core.glow.opacity * (0.7 + 0.3 * breath)), glow.opacity(0)]),
                center: center, startRadius: 0, endRadius: halo
            )
        )
        let stops = core.stops
        let ball = CGRect(x: center.x - 11, y: center.y - 11, width: 22, height: 22)
        canvas.fill(Path(ellipseIn: ball), with: .radialGradient(
            Gradient(stops: [
                .init(color: Color(hex: stops.highlight), location: 0),
                .init(color: Color(hex: stops.light), location: 0.3),
                .init(color: Color(hex: stops.body), location: 0.62),
                .init(color: Color(hex: stops.edge), location: 1),
            ]),
            center: CGPoint(x: ball.minX + ball.width * 0.38, y: ball.minY + ball.height * 0.34), startRadius: 0, endRadius: 15
        ))
    }

    private func point(_ center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }
}
