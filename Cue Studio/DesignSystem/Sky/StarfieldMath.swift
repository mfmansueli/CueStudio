//
//  StarfieldMath.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The numbers behind the sky, apart from the drawing so they can be tested: the three star layers,
/// the twinkle keyframes, and when the comet crosses. Everything is a function of time, with
/// stars laid out by a seeded generator, so a screen's sky is the same every time and never jumps.
nonisolated enum StarfieldMath {
    // MARK: - Layers

    struct Layer: Equatable, Sendable {
        let starsPerTile: Int
        let size: ClosedRange<Double>
        let opacity: ClosedRange<Double>
        let tile: CGSize
        /// Seconds for the pattern to drift one tile, downward.
        let drift: Double
    }

    static let far = Layer(starsPerTile: 16, size: 0.6...1.0, opacity: 0.30...0.65, tile: CGSize(width: 180, height: 170), drift: 260)
    static let mid = Layer(starsPerTile: 12, size: 1.0...1.5, opacity: 0.45...0.80, tile: CGSize(width: 390, height: 310), drift: 160)
    static let near = Layer(starsPerTile: 7, size: 1.6...2.4, opacity: 0.60...0.95, tile: CGSize(width: 390, height: 600), drift: 85)
    static let layers = [far, mid, near]

    /// How strongly the stars are drawn: the drifting stars' and the twinkles' opacity are multiplied by `opacity`, and the drifting stars' size by
    /// `size` (the twinkles' own size is `twinkleSize`). The app's sky is the delicate one (the owner's call, 6/10/2026: "a bit more delicate"); the
    /// first flight keeps the strength its boards were drawn with.
    struct StarLook: Equatable, Sendable {
        let opacity: Double
        let size: Double
    }

    static let delicateLook = StarLook(opacity: 0.65, size: 0.88)
    static let boardLook = StarLook(opacity: 1, size: 1)

    struct Star: Equatable, Sendable {
        /// Position inside the tile, 0...1.
        let x: Double
        let y: Double
        let size: Double
        let opacity: Double
    }

    /// The stars of one tile of `layer`: always the same for a seed.
    static func stars(in layer: Layer, seed: UInt64) -> [Star] {
        var random = SeededRandom(seed: seed)
        return (0..<layer.starsPerTile).map { _ in
            Star(
                x: random.next(), y: random.next(),
                size: random.next(in: layer.size), opacity: random.next(in: layer.opacity)
            )
        }
    }

    /// How far down, in points, a layer's pattern has drifted `time` seconds in (wrapping at one tile).
    static func drift(of layer: Layer, at time: TimeInterval) -> CGFloat {
        guard layer.drift > 0 else { return 0 }
        let progress = (time / layer.drift).truncatingRemainder(dividingBy: 1)
        return CGFloat(progress) * layer.tile.height
    }

    // MARK: - Twinkles

    struct Twinkle: Equatable, Sendable {
        /// Position on the screen, 0...1.
        let x: Double
        let y: Double
        /// `twinkleSize`.
        let size: Double
        /// 7 s for one cycle (`motion/README.md`).
        let cycle: Double
        let phase: Double
        /// Half of them have the phone-camera cross glint.
        let hasGlint: Bool
        /// Some are tinted warm or lilac.
        let tint: TwinkleTint
    }

    static func twinkles(count: Int, seed: UInt64) -> [Twinkle] {
        var random = SeededRandom(seed: seed &+ 7919)
        return (0..<count).map { index in
            Twinkle(
                x: random.next(in: 0.06...0.94), y: random.next(in: 0.05...0.9),
                size: random.next(in: twinkleSize), cycle: twinkleCycle,
                // Each star starts 0 to 5.2 s into its cycle.
                phase: random.next(in: 0...5.2) / twinkleCycle,
                hasGlint: index % 2 == 0,
                tint: [TwinkleTint.white, .warm, .lilac][Int(random.next(in: 0...2.999))]
            )
        }
    }

    /// Seconds for one twinkle.
    static let twinkleCycle = 7.0

    /// A twinkling star's size at its fullest, in points: small, close to the near layer's stars (1.6 to 2.4 pt), so it is the light
    /// coming and going that gives it away (the design's 1.8 to 3 pt, made smaller on 6/10/2026 at the owner's request).
    static let twinkleSize = 1.2...2.0

    /// Half the length of the cross glint of a twinkle at its fullest, in points (it was 8).
    static let glintHalfLength = 5.5

    /// The keyframes of a twinkle (`motion/README.md`): opacity 0.16 → 0.75 at 45% → 0.58 at 60% → 0.16, with the scale between 0.75 and 1.
    /// `phase` is 0...1 through the cycle (it wraps).
    static func twinkleLevel(at phase: Double) -> (opacity: Double, scale: Double) {
        let wrapped = phase - phase.rounded(.down)
        let keyframes: [(at: Double, opacity: Double, scale: Double)] = [
            (0, 0.16, 0.75), (0.45, 0.75, 1), (0.60, 0.58, 0.9), (1, 0.16, 0.75),
        ]
        let index = keyframes.lastIndex { $0.at <= wrapped } ?? 0
        let from = keyframes[min(index, keyframes.count - 2)]
        let to = keyframes[min(index, keyframes.count - 2) + 1]
        let t = (wrapped - from.at) / (to.at - from.at)
        let eased = t * t * (3 - 2 * t)
        return (from.opacity + (to.opacity - from.opacity) * eased, from.scale + (to.scale - from.scale) * eased)
    }

    // MARK: - The comet

    /// The comet (`motion/README.md`): one crosses every 105 to 135 s, the first 25 s after launch, in any direction, 520 to 680 pt in 1.7 to
    /// 2.4 s (`cubic-bezier(.3,.1,.45,1)`), with a tail of 140 to 210 pt; it fades in to 1 at 12% of its way, is at 0.9 at 72% and gone at the end.
    struct Comet: Equatable, Sendable {
        /// 0...1 of the time it takes.
        let time: Double
        let start: CGPoint
        /// A unit vector.
        let direction: CGVector
        let distance: CGFloat
        let tail: CGFloat

        /// How far along its way it is, eased.
        var progress: Double { cubicBezier(0.3, 0.1, 0.45, 1, at: time) }

        var opacity: Double {
            if time < 0.12 { return time / 0.12 }
            if time < 0.72 { return 1 - 0.1 * (time - 0.12) / 0.6 }
            return max(0, 0.9 * (1 - (time - 0.72) / 0.28))
        }
    }

    static let firstCometDelay = 25.0
    static let cometInterval = 105.0...135.0

    /// The comet crossing `size` at `time` seconds after launch, if there is one. The schedule is a function of time and the seed (the same on
    /// every screen, so it carries on across tabs).
    static func comet(at time: TimeInterval, size: CGSize, seed: UInt64) -> Comet? {
        var begins = firstCometDelay
        var index: UInt64 = 0
        while begins <= time {
            var random = SeededRandom(seed: seed &+ index &* 6_151)
            let duration = random.next(in: 1.7...2.4)
            if time <= begins + duration {
                let distance = CGFloat(random.next(in: 520...680))
                let angle = random.next(in: 0...(2 * .pi))
                let direction = CGVector(dx: cos(angle), dy: sin(angle))
                // It passes through a point of the screen a third of the way in.
                let through = CGPoint(x: size.width * random.next(in: 0.15...0.85), y: size.height * random.next(in: 0.05...0.8))
                let start = CGPoint(x: through.x - direction.dx * distance / 3, y: through.y - direction.dy * distance / 3)
                return Comet(
                    time: (time - begins) / duration, start: start, direction: direction, distance: distance,
                    tail: CGFloat(random.next(in: 140...210))
                )
            }
            begins += random.next(in: cometInterval)
            index += 1
        }
        return nil
    }

    /// A CSS-style cubic Bézier easing: where the curve is at `t` of the time (solved for x by Newton, with bisection as the fallback).
    static func cubicBezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, at t: Double) -> Double {
        func coordinate(_ a: Double, _ b: Double, _ s: Double) -> Double {
            let u = 1 - s
            return 3 * u * u * s * a + 3 * u * s * s * b + s * s * s
        }
        var low = 0.0
        var high = 1.0
        var s = t
        for _ in 0..<24 {
            let x = coordinate(x1, x2, s)
            if abs(x - t) < 1e-6 { break }
            if x < t { low = s } else { high = s }
            s = (low + high) / 2
        }
        return coordinate(y1, y2, s)
    }

    // MARK: - Nebulae

    /// A soft violet blob: 240 to 320 pt, drifting ±20 pt and growing 1 → 1.16 over 26 to 34 s, then back.
    struct Nebula: Equatable, Sendable {
        let x: Double
        let y: Double
        let diameter: Double
        let opacity: Double
        let period: Double
        /// Violet in Calm and Lively; Galactic has blue, magenta and teal ones (`galacticNebulae`).
        var hue: NebulaHue = .violet
    }

    static func nebulae(seed: UInt64) -> [Nebula] {
        var random = SeededRandom(seed: seed &+ 104_729)
        return (0..<2).map { index in
            Nebula(
                x: index == 0 ? random.next(in: 0.2...0.45) : random.next(in: 0.6...0.9),
                y: index == 0 ? random.next(in: 0.05...0.25) : random.next(in: 0.55...0.85),
                diameter: random.next(in: 240...320), opacity: random.next(in: 0.10...0.22), period: random.next(in: 26...34)
            )
        }
    }

    /// 0...1...0 across `period` (a triangle, eased): the nebula's drift and growth.
    static func nebulaPhase(at time: TimeInterval, period: Double) -> Double {
        let t = (time / period).truncatingRemainder(dividingBy: 2)
        let triangle = t <= 1 ? t : 2 - t
        return triangle * triangle * (3 - 2 * triangle)
    }
}

/// The tint of a twinkling star.
nonisolated enum TwinkleTint: Sendable { case white, warm, lilac }

/// A small deterministic generator (SplitMix64), so a sky is the same every time.
nonisolated struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func nextBits() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0...1.
    mutating func next() -> Double {
        Double(nextBits() >> 11) / Double(1 << 53)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * next()
    }
}
