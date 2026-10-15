//
//  ProOpeningScript.swift
//  Cue Studio
//

import SwiftUI

/// The moment Cue Pro opens with (09, "11.4 · Pro paywall — opening moment", and the owner's finish on top): 42 star streaks rush in from the
/// edges to a point at 44% of the height (0–1.1 s), a golden star ignites there (0.7–1.4 s) with a ring of gold crossing the screen and a warm
/// flash; then the star flies up to the planet's place with the first flight's trail (1.5–2.1 s), a ring of light gathers into that point and
/// the planet that is you is born there: white-hot, springing to its size and cooling to gold, sparks flying out, its orbits drawing round it
/// and its small planets coming in (2.1–3.1 s). The content fades up and un-blurs meanwhile. Tappable from 1.4 s. The calm Pro (from exports)
/// has none of it.
enum ProOpeningScript {
    /// The light over the screen is over (the streaks, star, rings, sparks and flashes).
    static let duration = 3.0
    /// Everything is in place: the planet's small planets have come in, and the last block of content.
    static let settled = 3.1
    /// A tap from here on skips to the end.
    static let tappableFrom = 1.4
    static let streakCount = 42

    // MARK: - Streaks

    /// A streak: the angle it comes in from, how long it is (60–200 pt), and how late it starts (0–0.24 s).
    struct Streak: Sendable {
        let angle: Double
        let length: CGFloat
        let delay: Double
    }

    /// The streaks, spread round the screen and the same on every launch.
    static let streaks: [Streak] = (0..<streakCount).map { index in
        let fraction = Double(index) / Double(streakCount)
        // A golden-angle walk round the circle spreads them evenly without a visible pattern.
        let angle = (Double(index) * 137.508).truncatingRemainder(dividingBy: 360)
        return Streak(angle: angle, length: 60 + CGFloat((index * 53) % 141), delay: fraction * 0.24)
    }

    /// How far a streak has come (0 at the edge, 1 at the centre) `time` seconds in: 0.9 s, `cubic-bezier(.5, 0, .8, .4)`.
    static func progress(of streak: Streak, at time: Double) -> Double {
        let raw = min(1, max(0, (time - streak.delay) / 0.9))
        return UnitCurve.css(0.5, 0, 0.8, 0.4).value(at: raw)
    }

    // MARK: - The core, the wave and the planet

    /// The golden star: it ignites (20% → 100% → 160% between 0.7 and 1.4 s, `cubic-bezier(.2, .9, .25, 1)`), waits, then flies up to the planet's
    /// place (1.5–2.1 s), a little smaller on the way, and goes out into the planet it becomes. `y` is how far it has gone (0 at the focus, 1 there).
    static let core = PoseTrack(curve: .css(0.2, 0.9, 0.25, 1), [
        .init(0.7, opacity: 0, scale: 0.2), .init(1.12, opacity: 0.97, scale: 1), .init(1.4, opacity: 1, scale: 1.6),
        .init(1.5, opacity: 1, scale: 1.6, curve: .css(0.45, 0, 0.2, 1)),
        .init(2.1, opacity: 1, scale: 0.9, y: 1),
        .init(2.18, opacity: 0, scale: 0.9, y: 1),
    ])

    /// Where the star is on its way up: from the focus to the planet, bowing out to the right (the words come in on the left).
    static func flight(from focus: CGPoint, to planet: CGPoint, progress: Double) -> CGPoint {
        CGPoint(
            x: focus.x + (planet.x - focus.x) * progress + 70 * sin(.pi * progress),
            y: focus.y + (planet.y - focus.y) * progress
        )
    }

    /// The ring of light that gathers into the planet's place as the star arrives (× the planet's radius, closing in).
    static let gather = PoseTrack(curve: .css(0.5, 0, 0.7, 0.4), [
        .init(1.9, opacity: 0, scale: 3.2), .init(1.97, opacity: 0.85, scale: 2.9), .init(2.14, opacity: 0.95, scale: 1), .init(2.2, opacity: 0, scale: 0.9),
    ])

    /// The light where the planet is born: a wide soft bloom (× 120 pt) and the planet white-hot, cooling to its gold (`opacity` is how white).
    static let birthBloom = PoseTrack(curve: .cssEaseOut, [
        .init(2.12, opacity: 0, scale: 0.4), .init(2.17, opacity: 0.9, scale: 0.7), .init(2.9, opacity: 0, scale: 1.25),
    ])
    static let whiteHot = PoseTrack(curve: .css(0.3, 0, 0.4, 1), [.init(2.12, opacity: 0), .init(2.16, opacity: 1), .init(2.95, opacity: 0)])

    /// The sparks the planet's birth throws out: how far they have gone (0 → 1 of their reach) and how bright.
    static let birthSparks = PoseTrack(curve: .css(0.1, 0.7, 0.3, 1), [
        .init(2.14, opacity: 0, scale: 0), .init(2.15, opacity: 1, scale: 0), .init(2.85, opacity: 0, scale: 1),
    ])
    static let sparkCount = 14

    /// The planet's orbits draw round it (0 → 1), and its small planets come in.
    static let orbitsDraw = PoseTrack(curve: .css(0.3, 0, 0.2, 1), [.init(2.3, scale: 0), .init(3.0, scale: 1)])
    static let travellers = PoseTrack(curve: .cssEaseOut, [.init(2.6, opacity: 0), .init(3.1, opacity: 1)])

    /// The thin gold ring: ×0.4 → ×14 and fading, 1.25–2.35 s (`cubic-bezier(.2, .8, .2, 1)`).
    static let shockwave = PoseTrack(curve: .css(0.2, 0.8, 0.2, 1), [
        .init(1.25, opacity: 0.9, scale: 0.4), .init(2.35, opacity: 0, scale: 14),
    ])

    /// The warm flash behind it, 0.9 s from 1.25 s (its peak at 30%).
    static let flash = PoseTrack(curve: .cssEaseOut, [.init(1.25, opacity: 0), .init(1.52, opacity: 0.35), .init(2.15, opacity: 0)])

    /// The planet that is you is born as the star reaches it: from a point it springs past its size and settles (0.3 → 1.08 → 1, 2.12–2.85 s).
    static let planet = PoseTrack(curve: .css(0.2, 0.9, 0.25, 1), [
        .init(2.12, opacity: 0, scale: 0.3), .init(2.18, opacity: 1, scale: 0.45), .init(2.55, opacity: 1, scale: 1.08), .init(2.85, opacity: 1, scale: 1),
    ])

    // MARK: - The content

    /// Each block of content fades up 18 pt and un-blurs over 0.7 s, 70 ms after the one above it, from 1.35 s (`cubic-bezier(.2, .9, .25, 1)`).
    static func reveal(_ index: Int) -> PoseTrack {
        let start = 1.35 + Double(index) * 0.07
        return PoseTrack(curve: .css(0.2, 0.9, 0.25, 1), [.init(start, opacity: 0, y: 18, blur: 8), .init(min(settled, start + 0.7))])
    }

    /// The second the planet is born: where the success haptic goes.
    static let landing = 2.16

    /// The soft haptic of the ignition.
    static let ignitionBeat = 1.25
}
