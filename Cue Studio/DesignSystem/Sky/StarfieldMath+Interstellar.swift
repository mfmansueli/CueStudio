//
//  StarfieldMath+Interstellar.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The colour of a nebula. Serene and Adrift only have violet ones.
nonisolated enum NebulaHue: Sendable { case violet, blue, magenta, teal }

/// The numbers of the Interstellar sky (Starry sky › Interstellar), apart from the drawing so they can be tested: three coloured nebulae, the Milky
/// Way band with its dust, and the spaceship that crosses where Adrift has the comet. Like the rest of the sky, everything is a function of
/// time and a seed, so a screen's sky is the same every time and never jumps.
nonisolated extension StarfieldMath {
    // MARK: - Nebulae

    /// How strong a Interstellar nebula is at its heart. Kept low on purpose: with the wash under it and the band over it, the brightest
    /// point of the night still has to read `inkHint` text (`PaletteContrastTests`).
    static let interstellarNebulaOpacity = 0.06...0.10

    /// Three nebulae, one in each colour, in three different parts of the sky: bigger and slower than the violet ones.
    static func interstellarNebulae(seed: UInt64) -> [Nebula] {
        var random = SeededRandom(seed: seed &+ 15_485_863)
        return [
            Nebula(
                x: random.next(in: 0.15...0.4), y: random.next(in: 0.05...0.22), diameter: random.next(in: 320...400),
                opacity: random.next(in: interstellarNebulaOpacity), period: random.next(in: 30...40), hue: .blue
            ),
            Nebula(
                x: random.next(in: 0.65...0.92), y: random.next(in: 0.38...0.6), diameter: random.next(in: 280...360),
                opacity: random.next(in: interstellarNebulaOpacity), period: random.next(in: 30...40), hue: .magenta
            ),
            Nebula(
                x: random.next(in: 0.1...0.4), y: random.next(in: 0.68...0.9), diameter: random.next(in: 300...380),
                opacity: random.next(in: interstellarNebulaOpacity), period: random.next(in: 30...40), hue: .teal
            ),
        ]
    }

    // MARK: - The Milky Way band

    /// The band crosses the screen from the lower left to the upper right, tilted 24°.
    static let bandAngle = -24.0 * .pi / 180
    /// Its width, in points, and how strong its glow is at the middle.
    static let bandWidth = 150.0
    static let bandPeakOpacity = 0.05
    /// Seconds for the band to drift across and back (±18 pt), so it is never quite still.
    static let bandPeriod = 90.0
    static let bandDrift = 18.0
    static let bandStarCount = 70

    /// A grain of dust in the band: tiny, many, most near its middle.
    struct BandStar: Equatable, Sendable {
        /// Along the band, -0.5...0.5 of the screen's diagonal.
        let along: Double
        /// Across the band, -1...1 of half its width (bell-shaped: most are near 0).
        let across: Double
        let size: Double
        let opacity: Double
    }

    static func bandStars(seed: UInt64) -> [BandStar] {
        var random = SeededRandom(seed: seed &+ 32_452_843)
        return (0..<bandStarCount).map { _ in
            let bell = (random.next() + random.next() + random.next()) / 3 * 2 - 1
            return BandStar(
                along: random.next(in: -0.5...0.5), across: bell,
                size: random.next(in: 0.5...1.2), opacity: random.next(in: 0.25...0.7)
            )
        }
    }

    /// How far across (perpendicular to itself) the band has drifted `time` seconds in: ±`bandDrift`, slowly, back and forth.
    static func bandOffset(at time: TimeInterval) -> Double {
        sin(time * 2 * .pi / bandPeriod) * bandDrift
    }

    // MARK: - The spaceship

    /// The spaceship: small (16 to 22 pt), slow (it crosses the whole screen in 16 to 22 s along a gentle arch) and rare: the first one 90 s into the
    /// session and then one every 4 to 7 minutes. The sky is behind a screen full of information (Scripts), so the ship is something to find, never
    /// something that calls: the owner's call, 6/10/2026.
    struct Spaceship: Equatable, Sendable {
        /// 0...1 of the crossing.
        let time: Double
        /// Seconds the whole crossing takes.
        let duration: Double
        /// A quadratic curve from `start` (off one edge) through the pull of `control` to `end` (off the other).
        let start: CGPoint
        let control: CGPoint
        let end: CGPoint
        /// The hull's length, in points.
        let length: CGFloat

        var position: CGPoint { position(atTime: time) }

        /// Where the ship was (or will be) at `t`, 0...1 of the crossing: the trail it leaves is drawn along this curve.
        func position(atTime t: Double) -> CGPoint {
            Self.point(at: t, start: start, control: control, end: end)
        }

        /// Which way the nose points, in radians (0 is to the right), from the curve's tangent.
        var heading: Double {
            let u = 1 - time
            let dx = 2 * u * (control.x - start.x) + 2 * time * (end.x - control.x)
            let dy = 2 * u * (control.y - start.y) + 2 * time * (end.y - control.y)
            return atan2(dy, dx)
        }

        /// It is there the whole crossing, and only the last few frames before an edge fade it, so it never pops.
        var opacity: Double { min(1, time / 0.04, (1 - time) / 0.04) }

        static func point(at t: Double, start: CGPoint, control: CGPoint, end: CGPoint) -> CGPoint {
            let u = 1 - t
            return CGPoint(
                x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
                y: u * u * start.y + 2 * u * t * control.y + t * t * end.y
            )
        }
    }

    static let firstSpaceshipDelay = 90.0
    static let spaceshipInterval = 240.0...420.0
    static let spaceshipDuration = 16.0...22.0
    static let spaceshipLength = 16.0...22.0
    /// Seconds of flight the trail reaches back (about 125 pt at the ship's speed): it follows the path the ship really flew, curve included.
    static let spaceshipTrailSeconds = 4.5

    /// The spaceship crossing `size` at `time` seconds after launch, if there is one. Like the comet's, the schedule is a function of time and
    /// the seed, the same on every screen.
    static func spaceship(at time: TimeInterval, size: CGSize, seed: UInt64) -> Spaceship? {
        var begins = firstSpaceshipDelay
        var index: UInt64 = 0
        while begins <= time {
            var random = SeededRandom(seed: seed &+ index &* 7_333)
            let duration = random.next(in: spaceshipDuration)
            if time <= begins + duration {
                let leftToRight = random.next() < 0.5
                let height = size.height
                let startY = CGFloat(random.next(in: 0.10...0.50)) * height
                let endY = startY + CGFloat(random.next(in: -0.10...0.12)) * height
                // It flies over the sky: the pull of the curve is above both ends.
                let lift = CGFloat(random.next(in: 0.04...0.12)) * height
                let margin: CGFloat = 60
                let startX = leftToRight ? -margin : size.width + margin
                let endX = leftToRight ? size.width + margin : -margin
                return Spaceship(
                    time: (time - begins) / duration,
                    duration: duration,
                    start: CGPoint(x: startX, y: startY),
                    control: CGPoint(x: size.width / 2, y: min(startY, endY) - lift),
                    end: CGPoint(x: endX, y: endY),
                    length: CGFloat(random.next(in: spaceshipLength))
                )
            }
            begins += random.next(in: spaceshipInterval)
            index += 1
        }
        return nil
    }

    /// The second the `index`th spaceship (0 is the first) leaves, after launch: for the catalogue, which sends one on demand.
    static func spaceshipBegin(index: Int, seed: UInt64) -> TimeInterval {
        var begins = firstSpaceshipDelay
        for step in 0..<max(0, index) {
            var random = SeededRandom(seed: seed &+ UInt64(step) &* 7_333)
            _ = random.next(in: spaceshipDuration)
            begins += random.next(in: spaceshipInterval)
        }
        return begins
    }
}
