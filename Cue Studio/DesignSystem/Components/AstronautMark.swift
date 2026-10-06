//
//  AstronautMark.swift
//  Cue Studio
//

import SwiftUI

/// A small astronaut for what has no name or photo yet (the empty profile): a pale helmet with a dark visor, a glint on the glass, a collar and a
/// suit, an antenna with a yellow light, and two stars beside it, in the colours of the universe. Drawn in a 100 × 100 space, so it scales to any size.
struct AstronautMark: View {
    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height) / 100
            var layer = context
            layer.scaleBy(x: unit, y: unit)
            Self.draw(in: &layer)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private static func draw(in layer: inout GraphicsContext) {
        let suit = Gradient(colors: [Palette.flightCoreMid, Palette.flightCoreEdge])
        // Two stars beside it.
        for (point, radius) in [(CGPoint(x: 16, y: 26), 1.6), (CGPoint(x: 86, y: 52), 1.3)] {
            let star = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            layer.fill(Path(ellipseIn: star), with: .color(Palette.starCream.opacity(0.9)))
        }
        // The antenna and its light.
        var antenna = Path()
        antenna.move(to: CGPoint(x: 66, y: 19))
        antenna.addLine(to: CGPoint(x: 73, y: 8))
        layer.stroke(antenna, with: .color(Palette.flightLilac), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        layer.drawLayer { glow in
            glow.addFilter(.shadow(color: Palette.acc.opacity(0.9), radius: 3))
            glow.fill(Path(ellipseIn: CGRect(x: 69.8, y: 4.8, width: 6.4, height: 6.4)), with: .color(Palette.acc))
        }
        // The suit, behind the helmet: shoulders, a chest panel with two lights.
        let shoulders = Path(roundedRect: CGRect(x: 22, y: 70, width: 56, height: 40), cornerRadius: 18)
        layer.fill(shoulders, with: .linearGradient(suit, startPoint: CGPoint(x: 50, y: 70), endPoint: CGPoint(x: 50, y: 110)))
        layer.fill(Path(roundedRect: CGRect(x: 39, y: 82, width: 22, height: 11), cornerRadius: 4), with: .color(Palette.lensRingDark.opacity(0.6)))
        layer.fill(Path(ellipseIn: CGRect(x: 44, y: 85.5, width: 4, height: 4)), with: .color(Palette.acc))
        layer.fill(Path(ellipseIn: CGRect(x: 52, y: 85.5, width: 4, height: 4)), with: .color(Palette.flightLilac))
        // The collar.
        layer.stroke(
            Path(ellipseIn: CGRect(x: 33, y: 63, width: 34, height: 12)), with: .color(Palette.flightLilac.opacity(0.8)), lineWidth: 2.4
        )
        // The helmet, lit from the top left.
        let helmet = Path(ellipseIn: CGRect(x: 19, y: 14, width: 62, height: 62))
        layer.fill(
            helmet,
            with: .radialGradient(
                Gradient(colors: [.white, Palette.flightCoreMid, Palette.flightCoreEdge]), center: CGPoint(x: 38, y: 32), startRadius: 0, endRadius: 56
            )
        )
        layer.stroke(helmet, with: .color(Palette.flightLilac.opacity(0.7)), lineWidth: 1.6)
        // The visor and the light on its glass.
        let visor = Path(roundedRect: CGRect(x: 29, y: 33, width: 42, height: 29), cornerRadius: 14)
        let glass = Gradient(colors: [Palette.lensGlassLight, Palette.lensRingDark])
        layer.fill(visor, with: .linearGradient(glass, startPoint: CGPoint(x: 38, y: 33), endPoint: CGPoint(x: 62, y: 62)))
        layer.stroke(visor, with: .color(.white.opacity(0.35)), lineWidth: 1)
        var glare = Path()
        glare.addArc(center: CGPoint(x: 50, y: 50), radius: 17, startAngle: .degrees(200), endAngle: .degrees(255), clockwise: false)
        layer.stroke(glare, with: .color(.white.opacity(0.4)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        var glint = Path()
        let star = CGPoint(x: 61, y: 42)
        glint.move(to: CGPoint(x: star.x, y: star.y - 4.5))
        glint.addQuadCurve(to: CGPoint(x: star.x + 4.5, y: star.y), control: CGPoint(x: star.x + 0.6, y: star.y - 0.6))
        glint.addQuadCurve(to: CGPoint(x: star.x, y: star.y + 4.5), control: CGPoint(x: star.x + 0.6, y: star.y + 0.6))
        glint.addQuadCurve(to: CGPoint(x: star.x - 4.5, y: star.y), control: CGPoint(x: star.x - 0.6, y: star.y + 0.6))
        glint.addQuadCurve(to: CGPoint(x: star.x, y: star.y - 4.5), control: CGPoint(x: star.x - 0.6, y: star.y - 0.6))
        layer.fill(glint, with: .color(Palette.starGold))
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 20) {
        AstronautMark().frame(width: 44)
        AstronautMark().frame(width: 96)
        AstronautMark().frame(width: 160)
    }
    .padding()
    .background(Palette.bg)
}
#endif
