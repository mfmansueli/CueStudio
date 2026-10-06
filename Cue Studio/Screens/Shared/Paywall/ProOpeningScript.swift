//
//  ProOpeningScript.swift
//  Cue Studio
//

import SwiftUI

/// The moment Cue Pro opens with (09, "11.4 · Pro paywall — opening moment"): 42 star streaks rush in from the edges to a point at 44% of the
/// height (0–1.1 s), a golden core ignites there (0.7–1.4 s) and rises into the planet that is you, a ring of gold crosses the screen (1.25–2.35 s)
/// with a warm flash, and the content fades up and un-blurs. 2.4 s in all; tappable from 1.4 s. The calm Pro (from exports) has none of it.
enum ProOpeningScript {
    /// The light is over (the streaks, core, ring and flash).
    static let duration = 2.4
    /// Everything is in place: the planet's last 0.35 s (it ignites at 2.05 s for 0.7 s, `ANIMACOES` §2) and the last block of content.
    static let settled = 2.75
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

    /// The golden core: it ignites (20% → 100% → 160% between 0.7 and 1.4 s, `cubic-bezier(.2, .9, .25, 1)`), waits, then rises into the planet that
    /// is you (1.5–2.26 s, `cubic-bezier(.5, 0, .3, 1)`; 85% of the way it has arrived and keeps growing, ×2.6 → ×4.2, as it goes out). `y` is how far it
    /// has gone toward the planet's centre (0 at the focus, 1 there).
    static let core = PoseTrack(curve: .css(0.2, 0.9, 0.25, 1), [
        .init(0.7, opacity: 0, scale: 0.2), .init(1.12, opacity: 0.97, scale: 1), .init(1.4, opacity: 1, scale: 1.6),
        .init(1.5, opacity: 1, scale: 1.6, curve: .css(0.5, 0, 0.3, 1)),
        .init(2.146, opacity: 1, scale: 2.6, y: 1, curve: .css(0.5, 0, 0.3, 1)),
        .init(2.26, opacity: 0, scale: 4.2, y: 1),
    ])

    /// The thin gold ring: ×0.4 → ×14 and fading, 1.25–2.35 s (`cubic-bezier(.2, .8, .2, 1)`).
    static let shockwave = PoseTrack(curve: .css(0.2, 0.8, 0.2, 1), [
        .init(1.25, opacity: 0.9, scale: 0.4), .init(2.35, opacity: 0, scale: 14),
    ])

    /// The warm flash behind it, 0.9 s from 1.25 s (its peak at 30%).
    static let flash = PoseTrack(curve: .cssEaseOut, [.init(1.25, opacity: 0), .init(1.52, opacity: 0.35), .init(2.15, opacity: 0)])

    /// The planet that is you ignites as the core reaches it: 0.6 → 1.04 → 1, 2.05–2.75 s (`cubic-bezier(.2, .9, .25, 1)`).
    static let planet = PoseTrack(curve: .css(0.2, 0.9, 0.25, 1), [
        .init(2.05, opacity: 0, scale: 0.6), .init(2.54, opacity: 1, scale: 1.04), .init(2.75, opacity: 1, scale: 1),
    ])

    // MARK: - The content

    /// Each block of content fades up 18 pt and un-blurs over 0.7 s, 70 ms after the one above it, from 1.35 s (`cubic-bezier(.2, .9, .25, 1)`).
    static func reveal(_ index: Int) -> PoseTrack {
        let start = 1.35 + Double(index) * 0.07
        return PoseTrack(curve: .css(0.2, 0.9, 0.25, 1), [.init(start, opacity: 0, y: 18, blur: 8), .init(min(settled, start + 0.7))])
    }

    /// The second the button lands: where the success haptic goes (the last block finishes here).
    static let landing = 2.3

    /// The soft haptic of the ignition.
    static let ignitionBeat = 1.25
}
