//
//  InterstellarSkyPainter.swift
//  Cue Studio
//

import SwiftUI

/// What only the Interstellar sky draws besides the nebulae: the Milky Way, a soft diagonal band of light with a dust of tiny stars in it, drifting
/// slowly across itself. The numbers are `StarfieldMath`'s (`bandAngle`, `bandWidth`…).
enum InterstellarSkyPainter {
    static func drawBand(in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval, dust: [StarfieldMath.BandStar]) {
        let diagonal = hypot(size.width, size.height)
        let width = StarfieldMath.bandWidth
        let peak = StarfieldMath.bandPeakOpacity
        let light = Palette.interstellarBand

        var layer = canvas
        layer.translateBy(x: size.width / 2, y: size.height * 0.46)
        layer.rotate(by: .radians(StarfieldMath.bandAngle))
        layer.translateBy(x: 0, y: StarfieldMath.bandOffset(at: time))

        // The glow: as long as the screen's diagonal, brightest along its middle line and gone at both edges.
        layer.fill(
            Path(CGRect(x: -diagonal / 2, y: -width, width: diagonal, height: width * 2)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: light.opacity(0), location: 0),
                    .init(color: light.opacity(peak * 0.45), location: 0.3),
                    .init(color: light.opacity(peak), location: 0.5),
                    .init(color: light.opacity(peak * 0.45), location: 0.7),
                    .init(color: light.opacity(0), location: 1),
                ]),
                startPoint: CGPoint(x: 0, y: -width), endPoint: CGPoint(x: 0, y: width)
            )
        )

        // The dust: the nearer a grain is to the middle of the band, the brighter.
        for grain in dust {
            let point = CGPoint(x: grain.along * diagonal, y: grain.across * width * 0.7)
            let fade = 1 - abs(grain.across) * 0.6
            layer.fill(
                Path(ellipseIn: CGRect(x: point.x - grain.size / 2, y: point.y - grain.size / 2, width: grain.size, height: grain.size)),
                with: .color(Color.white.opacity(grain.opacity * fade))
            )
        }
    }
}
