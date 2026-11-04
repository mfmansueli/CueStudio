//
//  UniverseParallax.swift
//  Cue Studio
//

import CoreGraphics

/// How Your universe answers the iPhone's tilt (the owner, 04/11/2026: a solar system you look into): each layer of the map slides by its own
/// depth, so the far haze barely moves, the disc of videos a little, YOU more and the planets most, and the disc opens toward the viewer as the
/// top of the iPhone tips back (it is seen more from above). `tilt` is −1…1 on each axis (`UniverseTilt`); zero is the map as drawn. Pure, in
/// board points.
nonisolated struct UniverseParallax: Equatable {
    enum Depth {
        case haze, disc, core, planet

        /// How far the layer slides at a full tilt, in board points.
        var reach: CGFloat {
            switch self {
            case .haze: 2
            case .disc: 5
            case .core: 8
            case .planet: 13
            }
        }
    }

    var tilt: CGVector = .zero

    static let still = UniverseParallax()

    /// How much the disc's height is opened (above 1) or closed (below) by the tilt: up to 18% either way.
    var flatten: CGFloat { 1 + 0.18 * tilt.dy }

    func shift(_ depth: Depth) -> CGVector {
        CGVector(dx: tilt.dx * depth.reach, dy: tilt.dy * depth.reach * 0.6)
    }

    func moved(_ point: CGPoint, _ depth: Depth) -> CGPoint {
        let by = shift(depth)
        return CGPoint(x: point.x + by.dx, y: point.y + by.dy)
    }
}
