//
//  SpeedCurvePreset.swift
//  Cue Studio
//

import Foundation

/// The ready-made speed curves: the moves short videos use most (a slow-motion beat in the middle, a ramp into or out of a
/// moment, a flash at a cut).
nonisolated enum SpeedCurvePreset: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Fast, slow on the moment in the middle, fast again.
    case hero
    /// As filmed, a deep slow motion in the middle, as filmed.
    case bullet
    /// Slow to fast.
    case rampUp
    /// Fast to slow.
    case rampDown
    /// Fast, slow, fast, slow: a montage's pulse.
    case montage
    /// Rushes in, then plays as filmed.
    case flashIn
    /// Plays as filmed, then rushes out.
    case flashOut

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hero: String(localized: "Hero")
        case .bullet: String(localized: "Bullet")
        case .rampUp: String(localized: "Ramp up")
        case .rampDown: String(localized: "Ramp down")
        case .montage: String(localized: "Montage")
        case .flashIn: String(localized: "Flash in")
        case .flashOut: String(localized: "Flash out")
        }
    }

    var curve: SpeedCurve {
        typealias Point = SpeedCurve.Point
        let points: [Point] = switch self {
        case .hero: [Point(position: 0, speed: 2), Point(position: 0.38, speed: 0.4), Point(position: 0.62, speed: 0.4), Point(position: 1, speed: 2)]
        case .bullet:
            [
                Point(position: 0, speed: 1), Point(position: 0.3, speed: 1), Point(position: 0.5, speed: 0.25), Point(position: 0.7, speed: 1),
                Point(position: 1, speed: 1),
            ]
        case .rampUp: [Point(position: 0, speed: 0.5), Point(position: 1, speed: 2.5)]
        case .rampDown: [Point(position: 0, speed: 2.5), Point(position: 1, speed: 0.5)]
        case .montage:
            [Point(position: 0, speed: 2.5), Point(position: 0.3, speed: 0.6), Point(position: 0.6, speed: 2.5), Point(position: 1, speed: 0.7)]
        case .flashIn: [Point(position: 0, speed: 4), Point(position: 0.3, speed: 1), Point(position: 1, speed: 1)]
        case .flashOut: [Point(position: 0, speed: 1), Point(position: 0.7, speed: 1), Point(position: 1, speed: 4)]
        }
        return SpeedCurve(points: points, preset: self)
    }
}
