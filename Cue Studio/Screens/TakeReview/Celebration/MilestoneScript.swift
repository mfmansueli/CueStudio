//
//  MilestoneScript.swift
//  Cue Studio
//

import SwiftUI

/// The milestone story (8.3) as a function of time, with the board's keyframes (4.5 s): six specks of light fall in on the point (0–1.35 s,
/// `(0.5, 0, 0.2, 1)`), the icon pops (scale 0.6 → 1.06 → 1, from 1.17 s, `(0.3, 0, 0.2, 1)`, `.success` as it lands) and a gold ring goes out of it
/// (1.35–2.79 s, ×0.7 → ×1.9, ease-out). The rays behind turn once in 40 s. The board loops; the app plays once and holds on the icon.
nonisolated enum MilestoneScript {
    static let duration = 4.5
    /// When the icon has landed (the haptic).
    static let landing = 1.62

    struct Speck {
        let dx: Double
        let dy: Double
        let size: Double
        /// 0 white, 1 lilac, 2 yellow
        let tone: Int
    }

    static let specks = [
        Speck(dx: -150, dy: -110, size: 6, tone: 0), Speck(dx: 160, dy: -80, size: 5, tone: 1), Speck(dx: -170, dy: 60, size: 5, tone: 2),
        Speck(dx: 140, dy: 120, size: 6, tone: 0), Speck(dx: 20, dy: -180, size: 5, tone: 2), Speck(dx: -40, dy: 170, size: 4, tone: 1),
    ]

    private static let fall = UnitCurve.css(0.5, 0, 0.2, 1)
    private static let popCurve = UnitCurve.css(0.3, 0, 0.2, 1)

    /// A speck: how far it still is from the point (1 → 0), its scale and its opacity.
    static func speck(at time: Double) -> (distance: Double, scale: Double, opacity: Double) {
        let local = min(1, max(0, time / 1.35))
        let progress = fall.value(at: local)
        let fadeIn = min(1, time / 0.36)
        let fadeOut = time <= 1.35 ? 1 : max(0, 1 - (time - 1.35) / 0.18)
        return (1 - progress, 1 - 0.6 * progress, max(0, fadeIn * fadeOut))
    }

    /// The icon's pose: nothing until 1.17 s, then it pops past full size and settles by 1.98 s.
    static func icon(at time: Double) -> (scale: Double, opacity: Double) {
        if time <= 1.17 { return (0.6, 0) }
        if time <= 1.62 {
            let p = popCurve.value(at: (time - 1.17) / 0.45)
            return (0.6 + 0.46 * p, p)
        }
        if time <= 1.98 { return (1.06 - 0.06 * popCurve.value(at: (time - 1.62) / 0.36), 1) }
        return (1, 1)
    }

    /// The ring: its scale and opacity, nil outside 1.35–2.79 s.
    static func ring(at time: Double) -> (scale: Double, opacity: Double)? {
        guard time >= 1.35, time <= 2.79 else { return nil }
        let grow = 1 - pow(1 - (time - 1.35) / 1.44, 2)
        let opacity = time < 1.53 ? 0.9 * (time - 1.35) / 0.18 : 0.9 * (1 - (time - 1.53) / 1.26)
        return (0.7 + 1.2 * grow, max(0, opacity))
    }

    private static let flare = UnitCurve.css(0.2, 0.8, 0.3, 1)
    private static let ringCurve = UnitCurve.css(0.1, 0.6, 0.3, 1)

    /// The cross of light that opens over the icon as it lands (1.73 s) and closes by 2.45 s: its scale (0 → 1 → 0) and opacity.
    static func cross(at time: Double) -> (scale: Double, opacity: Double) {
        let scale = Keyframes([(0, 0), (34.444, 0), (38.444, 1), (54.444, 0), (100, 0)], curve: flare, duration: duration)
        let opacity = Keyframes([(0, 0), (34.444, 0), (38.444, 1), (54.444, 0.9), (100, 0.9)], curve: flare, duration: duration)
        return (scale.value(at: time), opacity.value(at: time))
    }

    /// The thin pale ring after the gold one (1.5–2.5 s): ×0.4 → ×2 of 150 pt.
    static func echo(at time: Double) -> (scale: Double, opacity: Double) {
        let scale = Keyframes([(0, 0.3), (33.333, 0.3), (34.444, 0.4), (55.556, 2), (100, 2)], curve: ringCurve, duration: duration)
        let opacity = Keyframes([(0, 0), (33.333, 0), (34.444, 0.95), (55.556, 0), (100, 0)], curve: ringCurve, duration: duration)
        return (scale.value(at: time), opacity.value(at: time))
    }

    /// The rays turn once in 40 s.
    static func raysAngle(at time: Double) -> Double { time * 360 / 40 }
}
