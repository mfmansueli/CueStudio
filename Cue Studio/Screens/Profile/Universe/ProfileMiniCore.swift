//
//  ProfileMiniCore.swift
//  Cue Studio
//

import SwiftUI

/// The small core on Profile's "Your universe" row (9.1, the board's `pfCore`): a 14 pt ball of the core's colour in its glow, inside a thin ring of
/// 30 pt that carries a bead of light once round in 7 s; the ball swells and eases back every 6 s like the big one of 9.2. Still under Reduce Motion
/// (the bead at the top).
struct ProfileMiniCore: View {
    var color: CoreColor = .gold

    static let size: CGFloat = 30
    static let lap = 7.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                draw(in: &canvas, size: size, time: time)
            }
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityHidden(true)
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let glow = Color(hex: color.glow.hex, opacity: color.glow.opacity)
        let stops = color.stops
        // The ring, 1 pt, with its bead at the angle the lap has reached (it starts at the top).
        let ringRadius = size.width / 2 - 0.5
        canvas.stroke(
            Path(ellipseIn: CGRect(x: center.x - ringRadius, y: center.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)),
            with: .color(Palette.starGold.opacity(0.45)), lineWidth: 1
        )
        let angle = -Double.pi / 2 + 2 * .pi * time.truncatingRemainder(dividingBy: Self.lap) / Self.lap
        let bead = CGPoint(x: center.x + ringRadius * cos(angle), y: center.y + ringRadius * sin(angle))
        canvas.drawLayer { layer in
            layer.addFilter(.shadow(color: glow, radius: 3))
            layer.fill(Path(ellipseIn: CGRect(x: bead.x - 2, y: bead.y - 2, width: 4, height: 4)), with: .color(Palette.starGold))
        }
        // The ball: 14 pt, lit from the top left, with its glow, swelling a little.
        let swell = UniverseSphere.swell(at: time)
        let radius = 7 * (1 + 0.06 * swell)
        let ball = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        canvas.drawLayer { layer in
            layer.addFilter(.shadow(color: glow, radius: 5 + 2 * swell))
            layer.fill(ball, with: .color(Color(hex: stops.body)))
        }
        let highlight = CGPoint(x: center.x - radius * 0.32, y: center.y - radius * 0.4)
        canvas.fill(
            ball,
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(hex: stops.highlight), location: 0), .init(color: Color(hex: stops.light), location: 0.3),
                    .init(color: Color(hex: stops.body), location: 0.62), .init(color: Color(hex: stops.edge), location: 1),
                ]),
                center: highlight, startRadius: 0, endRadius: radius * 1.9
            )
        )
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 30) {
        ProfileMiniCore()
        ProfileMiniCore(color: .rose).scaleEffect(3)
    }
    .padding(60)
    .background(Palette.bg)
}
#endif
