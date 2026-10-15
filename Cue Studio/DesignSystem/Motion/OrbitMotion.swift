//
//  OrbitMotion.swift
//  Cue Studio
//

import Foundation

/// How a body goes round a flattened orbit so it reads as a circle seen at a slant, not a dot sliding on an ellipse: a little faster in front
/// (the lower half of the ellipse, nearer the eye) and slower behind, a little bigger and brighter in front and smaller and dimmer behind. The
/// lap time is the same; only the pace within the lap changes, and the angle never jumps (it is a smooth function of the plain one).
nonisolated enum OrbitMotion {
    /// How much the pace swings: ±12% of the plain angular speed.
    static let swing = 0.12
    /// How much bigger in front and smaller behind (× its size).
    static let depth = 0.1

    /// The angle a body is at when a plain, even lap would have it at `mean` (radians; 0 is the right end, π/2 the front).
    static func angle(mean: Double) -> Double {
        mean - swing * cos(mean)
    }

    /// Its size at `angle` (× its size): 1 + `depth` in front, 1 − `depth` behind.
    static func scale(at angle: Double) -> Double {
        1 + depth * sin(angle)
    }

    /// How lit it is at `angle` (× its opacity): full in front, 80% behind.
    static func light(at angle: Double) -> Double {
        0.9 + 0.1 * sin(angle)
    }
}
