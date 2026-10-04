//
//  StarfieldMath.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The numbers behind the sky, apart from the drawing so they can be tested: the three star layers,
/// the twinkle keyframes, and when a shooting star crosses. Everything is a function of time, with
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
        /// 1.8 to 3 pt.
        let size: Double
        /// 2.6 to 4.1 s for one cycle.
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
                size: random.next(in: 1.8...3.0), cycle: random.next(in: 2.6...4.1),
                phase: random.next(),
                hasGlint: index % 2 == 0,
                tint: [TwinkleTint.white, .warm, .lilac][Int(random.next(in: 0...2.999))]
            )
        }
    }

    /// The irregular keyframes of a twinkle: opacity 0.2 → 1 → 0.45 → 0.95 → 0.25 → 1 → 0.5, with the
    /// scale between 0.7 and 1.3. `phase` is 0...1 through the cycle.
    static func twinkleLevel(at phase: Double) -> (opacity: Double, scale: Double) {
        let opacities = [0.2, 1, 0.45, 0.95, 0.25, 1, 0.5, 0.2]
        let scales = [0.7, 1.3, 0.9, 1.2, 0.75, 1.3, 0.95, 0.7]
        let wrapped = phase - phase.rounded(.down)
        let position = wrapped * Double(opacities.count - 1)
        let index = min(opacities.count - 2, Int(position))
        let t = position - Double(index)
        // Smooth between keyframes.
        let eased = t * t * (3 - 2 * t)
        return (
            opacities[index] + (opacities[index + 1] - opacities[index]) * eased,
            scales[index] + (scales[index + 1] - scales[index]) * eased
        )
    }

    // MARK: - Shooting stars

    struct ShootingStar: Equatable, Sendable {
        /// 0...1 along its way.
        let progress: Double
        /// Where it started and the unit direction (160°: left and a little down).
        let start: CGPoint
        let direction: CGVector
        static let length: CGFloat = 130
        static let thickness: CGFloat = 1.5
        static let travel: CGFloat = 380
        /// A fade in the first and last fifth of the way.
        var opacity: Double { min(1, min(progress, 1 - progress) * 5) }
    }

    /// Seconds a shooting star takes to cross.
    static let shootingStarDuration = 0.7

    /// The shooting star of `slot` at `time`, if one is crossing. Each slot fires every 11 to 14 s, and
    /// the slots are staggered so two are never at the same point of their way.
    static func shootingStar(slot: Int, at time: TimeInterval, size: CGSize, seed: UInt64) -> ShootingStar? {
        // The same period for every slot, offset by half of it: two are never crossing together.
        let period = 11.0 + Double(seed % 4)
        let offset = period * (Double(slot) / 2 + 0.35)
        let shifted = time - offset
        guard shifted >= 0 else { return nil }
        let cycle = Int(shifted / period)
        let inCycle = shifted - Double(cycle) * period
        guard inCycle < shootingStarDuration else { return nil }
        var random = SeededRandom(seed: seed &+ UInt64(slot) &* 977 &+ UInt64(cycle) &* 131)
        let angle = 160.0 * .pi / 180
        return ShootingStar(
            progress: inCycle / shootingStarDuration,
            start: CGPoint(x: size.width * random.next(in: 0.45...1.0), y: size.height * random.next(in: 0.04...0.35)),
            direction: CGVector(dx: cos(angle), dy: sin(angle))
        )
    }

    // MARK: - Nebulae

    /// A soft violet blob: 240 to 320 pt, drifting ±20 pt and growing 1 → 1.16 over 26 to 34 s, then back.
    struct Nebula: Equatable, Sendable {
        let x: Double
        let y: Double
        let diameter: Double
        let opacity: Double
        let period: Double
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
