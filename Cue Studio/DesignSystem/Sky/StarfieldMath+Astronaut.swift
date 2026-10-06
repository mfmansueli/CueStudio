//
//  StarfieldMath+Astronaut.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The numbers of the astronaut that floats in the Adrift sky, apart from the drawing so they can be tested: a small astronaut lost in space,
/// drifting slowly across the screen in zero gravity and bouncing softly off its edges. Like the rest of the sky, everything is a function of
/// time and a seed (the app's clock, the same on every screen), so he carries on from where he was when the creator changes tab and never jumps.
nonisolated extension StarfieldMath {
    struct Astronaut: Equatable, Sendable {
        /// The centre of the body, in the sky's coordinates.
        let position: CGPoint
        /// How far he is turned, in radians (0 is upright).
        let angle: Double
        /// Head to boots, in points.
        let size: CGFloat
        /// 0...1: he eases in over the first seconds of a session instead of appearing.
        let opacity: Double
    }

    /// Small (30 pt at first, 25% bigger at the owner's request on 6/10/2026, to see him better), and slow: a drift of 7 to 10 pt a second
    /// (a screen's width in about 40 s) and a turn of a lap every 70 to 125 s.
    static let astronautSize: CGFloat = 37.5
    static let astronautSpeed = 7.0...10.0
    static let astronautSpin = 0.05...0.09
    static let astronautFadeIn = 4.0

    /// The astronaut at `time` seconds after launch, in a screen of `screen`. He bounces off the edges of the screen like a ball in zero
    /// gravity (no loss of speed), floats a little off a straight line, rocks gently and, at every bounce, gets a soft nudge of spin that settles.
    static func astronaut(at time: TimeInterval, size screen: CGSize, seed: UInt64) -> Astronaut {
        var random = SeededRandom(seed: seed &+ 49_979_687)
        let startX = random.next(in: 0.2...0.8) * screen.width
        let startY = random.next(in: 0.2...0.8) * screen.height
        // Never near-vertical or near-horizontal, so he crosses the screen and does not slide along an edge.
        let quadrant = Double(Int(random.next() * 4)) * .pi / 2
        let heading = random.next(in: 0.44...1.13) + quadrant
        let speed = random.next(in: astronautSpeed)
        let spin = random.next(in: astronautSpin) * (random.next() < 0.5 ? -1 : 1)
        let phases = (random.next(in: 0...(2 * .pi)), random.next(in: 0...(2 * .pi)), random.next(in: 0...(2 * .pi)))
        let tilt = random.next(in: -0.6...0.6)

        let t = max(0, time)
        let velocity = (x: cos(heading) * speed, y: sin(heading) * speed)
        // He floats a little off the straight line: 4 pt, slowly, and at different rhythms across and down.
        let driftX = 4 * sin(2 * .pi * t / 9 + phases.0)
        let driftY = 4 * sin(2 * .pi * t / 13 + phases.1)

        let half = Double(astronautSize) / 2 + 1
        let across = bounce(startX + velocity.x * t + driftX, in: half...max(half + 1, screen.width - half), speed: abs(velocity.x))
        let down = bounce(startY + velocity.y * t + driftY, in: half...max(half + 1, screen.height - half), speed: abs(velocity.y))

        // A slow tumble, a gentle rock, and a nudge after each bounce (it starts and ends at nothing, so there is no jump).
        let nudge = { (hit: Bounce) -> Double in
            let sign = hit.count % 2 == 0 ? 1.0 : -1.0
            let progress = min(1, hit.secondsSince / 1.5)
            return sign * 0.25 * pow(sin(.pi * progress), 2)
        }
        let angle = tilt + spin * t + 0.18 * sin(2 * .pi * t / 11 + phases.2) + nudge(across) + nudge(down)

        return Astronaut(
            position: CGPoint(x: across.value, y: down.value), angle: angle, size: astronautSize, opacity: min(1, t / astronautFadeIn)
        )
    }

    /// One axis of the bouncing: where he is, how many walls he has hit on it and how long ago the last hit was.
    struct Bounce: Equatable, Sendable {
        let value: Double
        let count: Int
        let secondsSince: Double
    }

    /// Folds a position that has run on in a straight line back into `range`, like a ball bouncing between two walls, keeping its speed.
    static func bounce(_ raw: Double, in range: ClosedRange<Double>, speed: Double) -> Bounce {
        let length = range.upperBound - range.lowerBound
        let legs = (raw - range.lowerBound) / length
        let whole = legs.rounded(.down)
        let along = legs - whole
        let count = Int(whole)
        let isEven = ((count % 2) + 2) % 2 == 0
        let value = range.lowerBound + length * (isEven ? along : 1 - along)
        return Bounce(value: value, count: count, secondsSince: speed > 0 ? along * length / speed : .infinity)
    }
}
