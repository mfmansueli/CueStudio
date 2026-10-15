//
//  UniverseOpening.swift
//  Cue Studio
//

import SwiftUI

/// How Your universe (9.2) builds itself as it opens, under 3 s (the owner's pass, the Pro planet's language): YOU is born white-hot in a
/// bloom and cools to its colour, the two orbits draw round it, each video's dot flies out of the core to its place, one after the other, and
/// lands with a small ring; then a light runs out along each route and its platform's planet is born where it arrives, white-hot, with
/// sparks; last, the newest video's star ignites. A function of the seconds since the map appeared; with Reduce Motion, a sealed year or a
/// picture of the map there is none, everything is in place.
nonisolated enum UniverseOpening {
    /// Everything is in place.
    static let duration = 2.9

    // MARK: - YOU

    static let core = PoseTrack(curve: .css(0.2, 0.9, 0.25, 1), [
        .init(0, opacity: 0, scale: 0.3), .init(0.08, opacity: 1, scale: 0.45), .init(0.55, opacity: 1, scale: 1.1), .init(0.85, opacity: 1, scale: 1),
    ])
    /// How white YOU still is (born white-hot, cooling to its colour).
    static let coreWhite = PoseTrack(curve: .css(0.3, 0, 0.4, 1), [.init(0.04, opacity: 0), .init(0.1, opacity: 1), .init(0.9, opacity: 0)])
    /// The bloom of light as YOU is born (× 90 pt).
    static let bloom = PoseTrack(curve: .cssEaseOut, [
        .init(0.04, opacity: 0, scale: 0.4), .init(0.12, opacity: 0.85, scale: 0.7), .init(0.95, opacity: 0, scale: 1.3),
    ])

    // MARK: - The orbits

    /// How much of the inner and the outer orbit is drawn (0 → 1).
    static let innerOrbit = PoseTrack(curve: .css(0.3, 0, 0.2, 1), [.init(0.25, scale: 0), .init(0.95, scale: 1)])
    static let outerOrbit = PoseTrack(curve: .css(0.3, 0, 0.2, 1), [.init(0.4, scale: 0), .init(1.2, scale: 1)])

    // MARK: - The videos

    /// A video's dot flies out of the core to its place: how far it has come (0 at the core, 1 there), the `index`th of `count`, all of them
    /// leaving between 0.45 and 1.45 s and taking 0.5 s each.
    static func dotFlight(index: Int, count: Int, at time: Double) -> Double {
        let start = 0.45 + 1.0 * Double(index) / Double(max(count, 1))
        let raw = min(1, max(0, (time - start) / 0.5))
        return UnitCurve.css(0.2, 0.8, 0.3, 1).value(at: raw)
    }

    /// The small ring a dot lands with (0 → 1 as it opens and fades), nil when it is not there.
    static func dotLanding(index: Int, count: Int, at time: Double) -> Double? {
        let landed = 0.45 + 1.0 * Double(index) / Double(max(count, 1)) + 0.5
        let age = time - landed
        guard age >= 0, age < 0.4 else { return nil }
        return age / 0.4
    }

    // MARK: - The planets

    /// The light along the route to the `index`th planet: how far it has gone (0 → 1), 0.55 s from 1 s, the next 0.14 s later.
    static func routeLight(index: Int, at time: Double) -> Double {
        let raw = min(1, max(0, (time - routeStart(index)) / 0.55))
        return UnitCurve.css(0.45, 0, 0.2, 1).value(at: raw)
    }

    static func routeStart(_ index: Int) -> Double { 1.0 + 0.14 * Double(index) }

    /// When the light reaches the `index`th planet, and it is born.
    static func planetBirth(_ index: Int) -> Double { routeStart(index) + 0.55 }

    /// The `index`th planet: its size (× its own) springing past 1 and settling, and how white it still is.
    static func planet(index: Int, at time: Double) -> (scale: Double, white: Double) {
        let born = planetBirth(index)
        let scale = PoseTrack(curve: .css(0.2, 0.9, 0.25, 1), [
            .init(born - 0.01, scale: 0), .init(born, scale: 0.3), .init(born + 0.3, scale: 1.12), .init(born + 0.55, scale: 1),
        ]).pose(at: time).scale
        let white = PoseTrack(curve: .css(0.3, 0, 0.4, 1), [.init(born - 0.01, opacity: 0), .init(born, opacity: 1), .init(born + 0.6, opacity: 0)])
            .pose(at: time).opacity
        return (scale, white)
    }

    /// The sparks of a planet's birth: how far they have gone (0 → 1) and how bright.
    static func planetSparks(index: Int, at time: Double) -> (reach: Double, opacity: Double) {
        let born = planetBirth(index)
        let pose = PoseTrack(curve: .css(0.1, 0.7, 0.3, 1), [
            .init(born - 0.01, opacity: 0, scale: 0), .init(born, opacity: 1, scale: 0), .init(born + 0.6, opacity: 0, scale: 1),
        ]).pose(at: time)
        return (pose.scale, pose.opacity)
    }

    // MARK: - The newest

    /// The newest video's star ignites last: its size and the flare of its cross.
    static let newest = PoseTrack(curve: .css(0.3, 1.3, 0.5, 1), [
        .init(2.3, opacity: 0, scale: 0.2), .init(2.5, opacity: 1, scale: 1.6), .init(2.8, scale: 1),
    ])

    // MARK: - Haptics

    /// What the hand feels: a soft tap as YOU is born, a light one as each planet is.
    static func beats(planets: Int) -> [(second: Double, isPlanet: Bool)] {
        [(0.08, false)] + (0..<planets).map { (planetBirth($0), true) }
    }
}
