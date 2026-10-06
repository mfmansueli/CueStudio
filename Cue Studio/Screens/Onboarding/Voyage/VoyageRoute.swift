//
//  VoyageRoute.swift
//  Cue Studio
//

import SwiftUI

/// The route a pick sends a light along in 1.3: from the creator's galaxy at the bottom left to the chosen one. The board draws it for TikTok as
/// `M78 478 C 120 420, 200 470, 298 296`: out of "YOU" a little above the straight line, then sweeping under it and up into the galaxy.
/// For any other galaxy the same shape is kept relative to the straight line between the two (its controls are at fixed fractions of the
/// distance along and across it), so the route always leaves and arrives the same way.
struct VoyageRoute {
    /// The creator's galaxy, where every route starts (its place once it has pulled back).
    static let origin = CGPoint(x: 78, y: 478)

    let from: CGPoint
    let to: CGPoint

    init(to: CGPoint) {
        from = Self.origin
        self.to = to
    }

    /// The controls, as fractions of the chord: (along, across) of the first and of the second.
    private static let controls = (first: (along: 0.2428, across: -0.0628), second: (along: 0.3471, across: 0.2508))

    var path: Path {
        var path = Path()
        path.move(to: from)
        path.addCurve(to: to, control1: control(Self.controls.first), control2: control(Self.controls.second))
        return path
    }

    private func control(_ fraction: (along: Double, across: Double)) -> CGPoint {
        let chord = CGPoint(x: to.x - from.x, y: to.y - from.y)
        let length = max(hypot(chord.x, chord.y), 1)
        let along = CGPoint(x: chord.x / length, y: chord.y / length)
        let across = CGPoint(x: -along.y, y: along.x)
        return CGPoint(
            x: from.x + (along.x * fraction.along + across.x * fraction.across) * length,
            y: from.y + (along.y * fraction.along + across.y * fraction.across) * length
        )
    }

    /// The point `parameter` (0...1) of the way along the curve's own parameter (not its length); the glints sit at fixed parameters.
    func point(at parameter: Double) -> CGPoint {
        let c1 = control(Self.controls.first), c2 = control(Self.controls.second)
        let u = min(1, max(0, parameter)), v = 1 - u
        return CGPoint(
            x: v * v * v * from.x + 3 * v * v * u * c1.x + 3 * v * u * u * c2.x + u * u * u * to.x,
            y: v * v * v * from.y + 3 * v * v * u * c1.y + 3 * v * u * u * c2.y + u * u * u * to.y
        )
    }

    /// The point `fraction` (0...1) of the way along the curve's length (what the board's `offset-distance` is).
    func point(atLength fraction: Double) -> CGPoint {
        path.trimmedPath(from: 0, to: min(max(fraction, 0.0001), 1)).currentPoint ?? from
    }
}
