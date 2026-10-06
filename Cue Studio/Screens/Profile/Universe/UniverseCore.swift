//
//  UniverseCore.swift
//  Cue Studio
//

import SwiftUI

/// The light at the centre of the creator's universe, "YOU" in small sizes (v30 · 9.1 and the core sheet; no photo, no initial). The big one of 9.2 is
/// `UniverseSphere`. Two sizes, from the boards:
/// - `.compact` (9.1, 44 pt): a 20 pt ball, a 68 pt glow and three still rings at 15, 19 and 23 pt.
/// - `.preview` (the core sheet): a 40 pt ball in a 120 pt glow.
/// The ball breathes (scale 1 → 1.04, 6 s). Still under Reduce Motion, and when `animates` is false (the share image).
struct UniverseCore: View {
    enum Style {
        case compact, preview
    }

    var color: CoreColor = .gold
    var style: Style = .compact
    var animates = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animates || reduceMotion)) { context in
            let time = (animates && !reduceMotion) ? context.date.timeIntervalSinceReferenceDate : 0
            // The breath is a swell and back: 0 → 1 → 0 over six seconds, eased.
            let swell = UniverseSphere.swell(at: time)
            ZStack {
                glow
                if style == .compact { rings }
                ball(swell: swell)
            }
            .frame(width: boxSize, height: boxSize)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Sizes

    private var boxSize: CGFloat { style == .compact ? 44 : 64 }

    private var ballSize: CGFloat { style == .compact ? 20 : 40 }

    private var glowSize: CGFloat { style == .compact ? 68 : 120 }

    // MARK: - Layers

    private var glowColor: Color {
        Color(hex: color.glow.hex, opacity: color.glow.opacity)
    }

    /// `radial-gradient(circle, glow 0%, transparent 62%)`: the glow reaches 62% of the way to the box's far corner.
    private var glow: some View {
        let reach = glowSize * 0.707 * 0.62
        return Circle()
            .fill(RadialGradient(colors: [glowColor, glowColor.opacity(0)], center: .center, startRadius: 0, endRadius: reach))
            .frame(width: glowSize, height: glowSize)
            .opacity(0.85)
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

    /// The three still rings the worlds' colours make (mint, amber, pink).
    private var rings: some View {
        Canvas { canvas, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for (radius, color) in [(15.0, Palette.World.mint), (19, Palette.World.warm), (23, Palette.World.pink)] {
                canvas.stroke(Self.circle(center, radius), with: .color(color.opacity(0.45)), lineWidth: 1)
            }
        }
        .frame(width: boxSize, height: boxSize)
    }

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 30) {
        UniverseCore(style: .compact)
        UniverseCore(color: .rose, style: .preview)
    }
    .padding(60)
    .background(Palette.bg)
}
#endif
