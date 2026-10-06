//
//  SendOffScript.swift
//  Cue Studio
//

import Foundation
import SwiftUI

/// The send-off (8.2) as a function of time, with the numbers of `ANIMACOES` §2 (the board's own script, played with the Web Animations API):
/// the card becomes a star (0.65 s); network `i`'s star leaves at 0.52 s + `i` · 0.35 s and arcs to its planet in 1.05 s, with nine dots of trail
/// 38 ms apart behind it; on arrival the planet pulses (0.6 s), a ring goes out of it (0.8 s), "+1" comes up (1.4 s, 0.5 s for the networks after the
/// first) and the number grows by one; 0.3 s after the first pulse a new small star lights beside YOU (0.7 s). Every curve is the board's.
nonisolated enum SendOffScript {
    static let foldDuration = 0.65
    static let firstLaunch = 0.52
    static let stagger = 0.35
    static let flight = 1.05
    static let trailDots = 9
    static let trailStep = 0.038
    static let pulseDuration = 0.6
    static let ringDuration = 0.8
    static let newStarDelay = 0.3
    static let newStarDuration = 0.7

    private static let foldCurve = UnitCurve.css(0.5, 0, 0.4, 1)
    private static let arcCurve = UnitCurve.css(0.45, 0.05, 0.35, 1)
    private static let pulseCurve = UnitCurve.css(0.3, 1.4, 0.5, 1)
    private static let ringCurve = UnitCurve.css(0.2, 0.8, 0.2, 1)
    private static let settleCurve = UnitCurve.css(0.2, 0.9, 0.25, 1)

    /// When network `index`'s star leaves and arrives.
    static func launch(_ index: Int) -> Double { firstLaunch + stagger * Double(index) }

    static func arrival(_ index: Int) -> Double { launch(index) + flight }

    /// When everything has landed and settled.
    static func end(networks: Int) -> Double {
        let last = arrival(max(0, networks - 1))
        return max(last + ringDuration, last + plusDuration(index: max(0, networks - 1)), newStarStart + newStarDuration)
    }

    // MARK: - The card

    /// The card in the first 0.65 s: up 16 pt while it stays whole, then up to 30 pt as it shrinks to 12% and goes out (`(0.5, 0, 0.4, 1)`).
    struct Fold: Equatable {
        let y: Double
        let scale: Double
        let opacity: Double
    }

    static func card(at time: Double) -> Fold {
        let local = clamp(time / foldDuration)
        if local < 0.5 {
            return Fold(y: -16 * foldCurve.value(at: local / 0.5), scale: 1, opacity: 1)
        }
        let eased = foldCurve.value(at: (local - 0.5) / 0.5)
        return Fold(y: -16 - 14 * eased, scale: 1 - 0.88 * eased, opacity: 1 - eased)
    }

    // MARK: - The stars

    /// A star of network `index`, or one of its trail (`dot` 0 is the star itself; 1…9 the dots behind it, 38 ms apart): how far along its arc it
    /// is (eased), its scale (1 → 0.65) and its opacity (in over the first 6% of the flight, out at the end), or nil when it is not in the air.
    struct Flight: Equatable {
        let progress: Double
        let scale: Double
        let opacity: Double
    }

    static func star(_ index: Int, dot: Int = 0, at time: Double) -> Flight? {
        let raw = (time - launch(index) - Double(dot) * trailStep) / flight
        guard raw > 0, raw < 1 else { return nil }
        let eased = arcCurve.value(at: raw)
        let peak = dot == 0 ? 1 : max(0, 0.55 - 0.06 * Double(dot))
        let opacity = peak * clamp(raw / 0.06) * (1 - clamp((raw - 0.96) / 0.04))
        return Flight(progress: eased, scale: 1 - 0.35 * eased, opacity: opacity)
    }

    // MARK: - The arrival

    /// The planet's scale in its pulse: 1 → 1.35 over the first 35% of 0.6 s → 1.12 (`(0.3, 1.4, 0.5, 1)` on each stretch).
    static func planetScale(_ index: Int, at time: Double) -> Double {
        let local = (time - arrival(index)) / pulseDuration
        if local <= 0 { return 1 }
        if local >= 1 { return 1.12 }
        if local < 0.35 { return 1 + 0.35 * pulseCurve.value(at: local / 0.35) }
        return 1.35 - 0.23 * pulseCurve.value(at: (local - 0.35) / 0.65)
    }

    /// The ring that goes out of the planet: ×1 → ×5 and .9 → 0 over 0.8 s (`(0.2, 0.8, 0.2, 1)`), or nil outside it.
    static func ring(_ index: Int, at time: Double) -> (scale: Double, opacity: Double)? {
        let local = (time - arrival(index)) / ringDuration
        guard local >= 0, local < 1 else { return nil }
        let eased = ringCurve.value(at: local)
        return (1 + 4 * eased, 0.9 * (1 - eased))
    }

    /// How long "+1" takes to come up: 1.4 s over the first network, 0.5 s over the ones after it.
    static func plusDuration(index: Int) -> Double { index == 0 ? 1.4 : 0.5 }

    /// "+1": opacity 0 → 1 over its first 30%, and up from 8 pt below (`(0.2, 0.9, 0.25, 1)`).
    static func plus(_ index: Int, at time: Double) -> (opacity: Double, lift: Double) {
        let local = clamp((time - arrival(index)) / plusDuration(index: index))
        guard local > 0 else { return (0, 8) }
        return (settleCurve.value(at: clamp(local / 0.3)), 8 * (1 - settleCurve.value(at: local)))
    }

    /// The number on a planet's label: the count before the share until the star arrives, then one more.
    static func count(final: Int, index: Int, at time: Double) -> Int {
        time >= arrival(index) ? final : max(0, final - 1)
    }

    /// 0 → 1 as the planet lights up (it was dimmed to 38% and desaturated) in the 0.4 s after its star lands.
    static func lit(_ index: Int, at time: Double) -> Double { clamp((time - arrival(index)) / 0.4) }

    // MARK: - The new star

    static var newStarStart: Double { arrival(0) + newStarDelay }

    /// The small star beside YOU: scale 0 → 1.8 (at 40%) → 1 and opacity 0 → 1 over 0.7 s (`(0.2, 0.9, 0.25, 1)`).
    static func newStar(at time: Double) -> (scale: Double, opacity: Double) {
        let local = clamp((time - newStarStart) / newStarDuration)
        guard local > 0 else { return (0, 0) }
        if local < 0.4 {
            let eased = settleCurve.value(at: local / 0.4)
            return (1.8 * eased, eased)
        }
        return (1.8 - 0.8 * settleCurve.value(at: (local - 0.4) / 0.6), 1)
    }

    /// How many arrivals sound a haptic: each one, but when three or more land within 0.7 s only the first.
    static func hapticArrivals(networks: Int) -> [Double] {
        let all = (0..<networks).map(arrival)
        guard networks >= 3, let first = all.first, (all.last ?? first) - first <= 0.7 else { return all }
        return [first]
    }

    private static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
}
