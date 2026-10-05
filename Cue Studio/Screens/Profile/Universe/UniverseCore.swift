//
//  UniverseCore.swift
//  Cue Studio
//

import SwiftUI

/// The light at the centre of the creator's universe, "YOU" (v30 · 9.1, 9.2; no photo, no initial). Three sizes, all from the boards:
/// - `.full` (9.2): a 34 pt ball that breathes (scale 1 → 1.04, 6 s), a 132 pt glow of the core colour that swells (opacity .78 → 1, 6 s), three rings
///   at 23, 29 and 35 pt (mint, amber, pink, 1 pt at 38%) each carrying a 2.3 pt dot that circles in 22, 31 and 40 s, and three small four-point stars.
/// - `.compact` (9.1, 44 pt): a 20 pt ball, a 68 pt glow and three still rings at 15, 19 and 23 pt.
/// - `.preview` (the core sheet): a 40 pt ball in a 120 pt glow.
/// Still under Reduce Motion, and when `animates` is false (the share image).
struct UniverseCore: View {
    enum Style {
        case full, compact, preview
    }

    var color: CoreColor = .gold
    var style: Style = .full
    var animates = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One orbit of the full core: its radius, its colour, the seconds a lap takes and the angle it starts at.
    private struct Ring {
        let radius: CGFloat
        let hex: UInt32
        let period: Double
        let start: Double
    }

    private static let rings = [
        Ring(radius: 23, hex: 0x7EE0B8, period: 22, start: 20),
        Ring(radius: 29, hex: 0xFFC46B, period: 31, start: 160),
        Ring(radius: 35, hex: 0xFF9BD2, period: 40, start: 280),
    ]

    /// The seconds of one breath of the ball and of the glow.
    static let breathPeriod = 6.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animates || reduceMotion)) { context in
            let time = (animates && !reduceMotion) ? context.date.timeIntervalSinceReferenceDate : 0
            // The breath is a swell and back: 0 → 1 → 0 over six seconds, eased.
            let swell = 0.5 - 0.5 * cos(time * 2 * .pi / Self.breathPeriod)
            ZStack {
                glow(swell: swell)
                if style != .preview { rings(time: time) }
                ball(swell: swell)
            }
            .frame(width: boxSize, height: boxSize)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Sizes

    private var boxSize: CGFloat {
        switch style {
        case .full: 80
        case .compact: 44
        case .preview: 64
        }
    }

    private var ballSize: CGFloat {
        switch style {
        case .full: 34
        case .compact: 20
        case .preview: 40
        }
    }

    private var glowSize: CGFloat {
        switch style {
        case .full: 132
        case .compact: 68
        case .preview: 120
        }
    }

    // MARK: - Layers

    private var glowColor: Color {
        Color(hex: color.glow.hex, opacity: color.glow.opacity)
    }

    /// `radial-gradient(circle, glow 0%, transparent 62%)`: the glow reaches 62% of the way to the box's far corner.
    private func glow(swell: Double) -> some View {
        let reach = glowSize * 0.707 * 0.62
        // Full: opacity .78 ↔ 1 (`coreGlow`); the others hold .85.
        let opacity = style == .full ? 0.78 + 0.22 * swell : 0.85
        return Circle()
            .fill(RadialGradient(colors: [glowColor, glowColor.opacity(0)], center: .center, startRadius: 0, endRadius: reach))
            .frame(width: glowSize, height: glowSize)
            .opacity(opacity)
    }

    private func ball(swell: Double) -> some View {
        let stops = color.stops
        let size = ballSize
        // `radial-gradient(circle at 38% 34%, …)`: the highlight sits up and to the left, and the gradient runs to the far corner.
        let reach = size * sqrt(0.62 * 0.62 + 0.66 * 0.66)
        return Circle()
            .fill(RadialGradient(
                stops: [
                    .init(color: Color(hex: stops.highlight), location: 0),
                    .init(color: Color(hex: stops.light), location: 0.30),
                    .init(color: Color(hex: stops.body), location: 0.62),
                    .init(color: Color(hex: stops.edge), location: 1),
                ],
                center: UnitPoint(x: 0.38, y: 0.34), startRadius: 0, endRadius: reach
            ))
            .overlay(Circle().strokeBorder(Color(hex: 0x281C00, opacity: 0.4), lineWidth: 1))
            .shadow(color: glowColor, radius: style == .compact ? 0 : 18)
            .frame(width: size, height: size)
            .scaleEffect(1 + 0.04 * swell)
    }

    /// The rings the worlds' colours make, and (full only) a dot on each going round, and three small stars.
    private func rings(time: Double) -> some View {
        Canvas { canvas, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            if style == .compact {
                for (radius, hex) in [(15.0, UInt32(0x7EE0B8)), (19, 0xFFC46B), (23, 0xFF9BD2)] {
                    canvas.stroke(Self.circle(center, radius), with: .color(Color(hex: hex, opacity: 0.45)), lineWidth: 1)
                }
                return
            }
            for ring in Self.rings {
                let colour = Color(hex: ring.hex)
                canvas.stroke(Self.circle(center, ring.radius), with: .color(colour.opacity(0.38)), lineWidth: 1)
                let angle = (ring.start + 360 * time / ring.period) * .pi / 180
                let dot = CGPoint(x: center.x + ring.radius * cos(angle), y: center.y + ring.radius * sin(angle))
                canvas.fill(Self.disc(dot, 2.3), with: .color(colour))
            }
            // Three four-point stars, still: two warm and one faint.
            Self.sparkle(&canvas, at: CGPoint(x: center.x - 27, y: center.y - 27), color: Color(hex: 0xFFE680))
            Self.sparkle(&canvas, at: CGPoint(x: center.x + 31, y: center.y - 20), color: Color(hex: 0xFFE680))
            Self.sparkle(&canvas, at: CGPoint(x: center.x - 36, y: center.y + 8), color: Color(hex: 0xE1E4F5, opacity: 0.3))
        }
        .frame(width: boxSize, height: boxSize)
    }

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    private static func disc(_ center: CGPoint, _ radius: CGFloat) -> Path {
        circle(center, radius)
    }

    /// A four-point star 6.4 pt across with pinched waists (the board's sparkle path).
    private static func sparkle(_ canvas: inout GraphicsContext, at c: CGPoint, color: Color) {
        let outer: CGFloat = 3.2
        let inner: CGFloat = 0.9
        var path = Path()
        let points: [CGPoint] = [
            CGPoint(x: 0, y: -outer), CGPoint(x: inner, y: -inner), CGPoint(x: outer, y: 0), CGPoint(x: inner, y: inner),
            CGPoint(x: 0, y: outer), CGPoint(x: -inner, y: inner), CGPoint(x: -outer, y: 0), CGPoint(x: -inner, y: -inner),
        ]
        path.move(to: CGPoint(x: c.x + points[0].x, y: c.y + points[0].y))
        for point in points.dropFirst() { path.addLine(to: CGPoint(x: c.x + point.x, y: c.y + point.y)) }
        path.closeSubpath()
        canvas.fill(path, with: .color(color))
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 30) {
        UniverseCore(style: .full)
        UniverseCore(style: .compact)
        UniverseCore(color: .rose, style: .preview)
    }
    .padding(60)
    .background(Palette.bg)
}
#endif
