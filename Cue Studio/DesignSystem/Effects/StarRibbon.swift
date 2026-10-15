//
//  StarRibbon.swift
//  Cue Studio
//

import SwiftUI

/// A shooting star of the first flight, for a scene's `Canvas`: its tail is the path the head took in its last `length` seconds, one ribbon
/// that thins, fades and cools from the head to its end over a blurred wider copy of itself; the head is a white core with a halo and a
/// small turning cross of light. 1.1's star, 1.2's star and the light that carries a topic to its orbit are all drawn with it, so they leave
/// the same trail.
enum StarRibbon {
    /// Where the head is at a second (from the canvas's top left) and how visible.
    typealias Point = (point: CGPoint, opacity: Double)

    /// How many seconds of the path the tail shows.
    static let length = 0.32
    /// How many pieces the tail is drawn with: enough for its bends to stay round.
    static let samples = 36
    /// The star's colours from the head to the end of its tail.
    static let starlight: [Color] = [.white, Palette.Universe.starCream, Palette.Universe.starWarm, Palette.Universe.starGold]

    /// The tail, from the head back: where the head was each of `samples` steps of `length` before `time`.
    static func trail(at time: Double, length: Double = length, head: (Double) -> Point) -> [Point] {
        (0...samples).map { head(time - length * Double($0) / Double(samples)) }
    }

    /// The tail through `trail` (from the head back), `width` wide at the head, in `colors` from the head to its end.
    static func draw(_ trail: [Point], colors: [Color] = starlight, width: CGFloat = 4.4, in context: inout GraphicsContext) {
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 5))
            ribbon(trail, colors: colors, width: width * 2.5, opacity: 0.5, in: &layer)
        }
        ribbon(trail, colors: colors, width: width, opacity: 1, in: &context)
    }

    /// The head: a halo, a white core and a cross of light turning with `spin` (seconds).
    static func head(
        at centre: CGPoint, opacity: Double, spin: Double, radius: CGFloat = 4.4, halo: Color = Palette.Universe.starCream,
        in context: inout GraphicsContext
    ) {
        guard opacity > 0.01 else { return }
        let reach = radius * 3.6
        context.fill(
            LightFX.disc(centre, reach),
            with: .radialGradient(Gradient(colors: [halo.opacity(0.45 * opacity), halo.opacity(0)]), center: centre, startRadius: 0, endRadius: reach)
        )
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: halo.opacity(0.9 * opacity), radius: 8))
            layer.fill(LightFX.disc(centre, radius), with: .color(.white.opacity(opacity)))
        }
        LightFX.cross(
            at: centre, size: radius * 5, thickness: 1.1, verticalRatio: 0.72, pose: MotionPose(opacity: 0.8 * opacity, rot: spin * 60),
            color: .white, glow: .white.opacity(0.9), in: &context
        )
    }

    /// Short round-capped pieces, each a little thinner, fainter and cooler than the one before, so they read as one line.
    private static func ribbon(_ trail: [Point], colors: [Color], width: CGFloat, opacity: Double, in context: inout GraphicsContext) {
        let count = trail.count - 1
        guard count > 0 else { return }
        for step in 0..<count {
            let start = trail[step]
            let end = trail[step + 1]
            let along = Double(step) / Double(count)
            let alpha = pow(1 - along, 1.6) * min(start.opacity, end.opacity) * opacity
            guard alpha > 0.01, hypot(end.point.x - start.point.x, end.point.y - start.point.y) > 0.05 else { continue }
            var piece = Path()
            piece.move(to: start.point)
            piece.addLine(to: end.point)
            let thickness = width * pow(1 - along, 1.1) + 0.4
            context.stroke(piece, with: .color(color(along, in: colors).opacity(alpha)), style: StrokeStyle(lineWidth: thickness, lineCap: .round))
        }
    }

    /// The colour `along` (0...1) the tail, between evenly spaced `colors`.
    private static func color(_ along: Double, in colors: [Color]) -> Color {
        guard colors.count > 1 else { return colors.first ?? .white }
        let scaled = min(max(along, 0), 1) * Double(colors.count - 1)
        let index = min(Int(scaled), colors.count - 2)
        return colors[index].mix(with: colors[index + 1], by: scaled - Double(index))
    }
}
