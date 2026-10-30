//
//  ProOpeningScript.swift
//  Cue Studio
//

import SwiftUI

/// The moment Cue Pro opens with (09, "11.4 · Pro paywall — opening moment", with the owner's galaxy, 30/10/2026): 42 star streaks rush in from
/// the edges to a point at 44% of the height (0–1.1 s), a golden star ignites there (0.7–1.4 s) with a ring of gold crossing the screen and a
/// warm flash; then the star flies up to the galaxy's place with the first flight's trail (1.5–2.1 s) and becomes the golden planet at its
/// core, white-hot and cooling to gold; the arms unfurl face on, turning (1.98–2.83 s), the galaxy lies back to its slant on a spring
/// (2.25–3.05 s) and the year's ring wipes in round it, its nodes popping one after the other (2.4–3.4 s) (`ProGalaxyArt`). The content rises
/// from 2.32 s. Tappable from 1.4 s. The calm Pro has none of it.
enum ProOpeningScript {
    /// The light over the screen is over (the streaks, star, rings, sparks and flashes).
    static let duration = 3.0
    /// Everything is in place: the ring's last node has lit, the last block of content has risen and the badge has popped.
    static let settled = 3.5
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

    // MARK: - The star, the wave and the galaxy

    /// The golden star: it ignites (20% → 100% → 160% between 0.7 and 1.4 s, `cubic-bezier(.2, .9, .25, 1)`), waits, then flies up to the galaxy's
    /// place (1.5–2.1 s), a little smaller on the way, and goes out into the core it becomes. `y` is how far it has gone (0 at the focus, 1 there).
    static let core = PoseTrack(curve: .css(0.2, 0.9, 0.25, 1), [
        .init(0.7, opacity: 0, scale: 0.2), .init(1.12, opacity: 0.97, scale: 1), .init(1.4, opacity: 1, scale: 1.6),
        .init(1.5, opacity: 1, scale: 1.6, curve: .css(0.45, 0, 0.2, 1)),
        .init(2.1, opacity: 1, scale: 0.9, y: 1),
        .init(2.18, opacity: 0, scale: 0.9, y: 1),
    ])

    /// Where the star is on its way up: from the focus to the galaxy, bowing out to the right (the words come in on the left).
    static func flight(from focus: CGPoint, to core: CGPoint, progress: Double) -> CGPoint {
        CGPoint(
            x: focus.x + (core.x - focus.x) * progress + 70 * sin(.pi * progress),
            y: focus.y + (core.y - focus.y) * progress
        )
    }

    /// A soft bloom where the star arrives and becomes the core (× 70 pt).
    static let arrival = PoseTrack(curve: .cssEaseOut, [
        .init(2.04, opacity: 0, scale: 0.4), .init(2.1, opacity: 0.75, scale: 0.7), .init(2.7, opacity: 0, scale: 1.3),
    ])
    /// The core: from a point it springs past its size and settles (0 → 1.5 → 1, 1.98–2.68 s), white-hot cooling to gold
    /// (`whiteHot`, 1.1 s from 2 s); its glow comes up from a third of its size (`coreGlow`, 2–2.8 s) and then breathes.
    static let coreBirth = PoseTrack(curve: .cssEaseOut, [.init(1.98, scale: 0), .init(2.295, scale: 1.5), .init(2.68, scale: 1)])
    static let whiteHot = PoseTrack(curve: .cssEaseOut, [.init(2.0, opacity: 1), .init(3.1, opacity: 0)])
    static let coreGlow = PoseTrack(curve: .cssEaseOut, [.init(2.0, opacity: 0, scale: 0.3), .init(2.8, opacity: 0.85)])
    static let glowBreathes = 2.8
    /// The arms unfurl from the core, face on: a tenth of their size turned back 220° to all of it (1.98–2.83 s, `cubic-bezier(.2, .9, .25, 1)`),
    /// showing over the first 30%.
    static let unfurl = PoseTrack(curve: .css(0.2, 0.9, 0.25, 1), [.init(1.98, scale: 0.1, rotation: -220), .init(2.83)])
    static let unfurlFade = PoseTrack([.init(1.98, opacity: 0), .init(2.235, opacity: 1)])
    /// The galaxy lies back to its slant (`scale` 0 → 1, past it and back: 2.25–3.05 s, `cubic-bezier(.34, 1.3, .5, 1)`).
    static let tilt = PoseTrack(curve: .css(0.34, 1.3, 0.5, 1), [.init(2.25, scale: 0), .init(3.05, scale: 1)])
    /// The year's ring wipes in from the left (`scale` 0 → 1, 2.4–3.1 s).
    static let ringWipe = PoseTrack(curve: .cssEaseOut, [.init(2.4, scale: 0), .init(3.1, scale: 1)])

    /// Node `index` of the ring pops in, past its size and back (0.35 s), one after the other from 2.5 s: 45 ms apart, 18 ms on the thirty.
    static func nodePop(_ index: Int, of count: Int) -> PoseTrack {
        let start = ringBeat + Double(index) * nodeGap(count)
        return PoseTrack(curve: .cssEaseOut, [
            .init(start, opacity: 0, scale: 0), .init(start + 0.21, opacity: 1, scale: 1.9), .init(start + 0.35, opacity: 1, scale: 1),
        ])
    }

    static func nodeGap(_ count: Int) -> Double { count > 12 ? 0.018 : 0.045 }

    /// The thin gold ring: ×0.4 → ×14 and fading, 1.25–2.35 s (`cubic-bezier(.2, .8, .2, 1)`).
    static let shockwave = PoseTrack(curve: .css(0.2, 0.8, 0.2, 1), [
        .init(1.25, opacity: 0.9, scale: 0.4), .init(2.35, opacity: 0, scale: 14),
    ])

    /// The warm flash behind it, 0.9 s from 1.25 s (its peak at 30%).
    static let flash = PoseTrack(curve: .cssEaseOut, [.init(1.25, opacity: 0), .init(1.52, opacity: 0.35), .init(2.15, opacity: 0)])

    // MARK: - The content

    /// When each block of content rises, from the title as the galaxy unfurls to Restore · Terms · Privacy.
    enum Block: Double {
        case title = 2.32
        case subtitle = 2.4
        case exports = 2.52
        case ultra = 2.58
        case list = 2.64
        case plans = 2.72
        case button = 2.8
        case finePrint = 2.86
        case links = 2.9
    }

    /// A block of content rises 18 pt and un-blurs over 0.55 s at its turn (`cubic-bezier(.2, .8, .2, 1)`); a line of the list 60 ms after the
    /// one above it.
    static func reveal(_ block: Block, line: Int = 0) -> PoseTrack {
        let start = block.rawValue + Double(line) * 0.06
        return PoseTrack(curve: .css(0.2, 0.8, 0.2, 1), [.init(start, opacity: 0, y: 18, blur: 6), .init(start + 0.55)])
    }

    /// "SAVE 58%" pops onto Yearly as the content settles (0.5 s from 3 s, past its size and back), and the Ultra AI card's ✦ turns half round
    /// (0.6 s from 2.8 s).
    static let badge = PoseTrack(curve: .css(0.3, 1.6, 0.5, 1), [.init(3.0, scale: 0), .init(3.5, scale: 1)])
    static let ultraGlyph = PoseTrack(curve: .css(0.3, 1.5, 0.5, 1), [
        .init(2.8, opacity: 0, scale: 0.4, rotation: 0), .init(3.16, opacity: 1, scale: 1.5, rotation: 150), .init(3.4, scale: 1, rotation: 180),
    ])

    // MARK: - Haptics

    /// The soft tap of the ignition.
    static let ignitionBeat = 1.25
    /// The hum that swells as the arms unfurl, from the star's arrival to the firm tap of the galaxy settling at its slant.
    static let unfurlBeat = 1.98
    static let settleBeat = 2.85
    /// The ring's nodes lighting: a light tick each.
    static let ringBeat = 2.5
}
