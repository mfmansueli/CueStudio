//
//  VoiceShipFlight.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Where My Cue Voice's spaceship is, and how it is seen, at each moment after the tank is full (`VoiceFuelTank`; the owner, 03/11/2026: an
/// award-level flight, not a zoom). Three acts, as an animator stages a takeoff:
/// 1. **Anticipation** (0.28 s): the ship backs off a few points and crouches (shorter, a little wider) while its engines charge.
/// 2. **Launch** (0.45 s): it leaves along an arc that turns up and back toward the middle, steering a little ahead of its path as a pilot
///    does, banking as much as it is turning (the wings narrow and the inner one darkens), stretched by its speed and leaving its ion trail; it
///    reaches the turn still moving, so the flight never stalls.
/// 3. **Toward the viewer** (0.70 s): it pitches its nose at the screen (its top view foreshortens to a sliver, then its front view opens),
///    boosts with a shock wave, and comes closer with true perspective, its size `1 / z` as the distance `z` falls, so it grows slowly and then
///    fast, carrying on a little in the direction it came from, along a gentle curve, coming out of the turn rolled and levelling, then rolling
///    slightly the other way as it rushes past. Rings of force push out behind it, its light warms the page and it passes the glass off the top
///    right with a flash.
///
/// Pure geometry in the tank's coordinates (`origin` is where the ship sits at the end of the run, `anchor` where it turns to the viewer, `width`
/// the tank's), so a moment always gives the same pose and the tests can check every frame.
nonisolated enum VoiceShipFlight {
    static let anticipation: TimeInterval = 0.28
    static let launch: TimeInterval = 0.45
    static let approach: TimeInterval = 0.70
    /// From the end of the run until the ship has passed the glass.
    static let duration: TimeInterval = anticipation + launch + approach
    /// How close the ship comes before it passes the glass: its last size is `1 / nearest` times its first.
    static let nearest: Double = 0.12
    /// Where it passes the glass, in points of the screen per unit of `1 / z`: up and to the right, so it leaves by the top right corner.
    static let passing = CGVector(dx: 30, dy: -27)
    /// The part of the launch, at its end, where the nose pitches toward the viewer (the top view foreshortens to nothing).
    static let pitchShare = 0.30

    enum View: Equatable { case top, front }

    struct Pose: Equatable {
        var position: CGPoint
        var view: View
        /// Top view: the nose's direction (radians, 0 is +x).
        var heading: Double = 0
        /// Top view: the length's scale (speed stretches it, the crouch and the pitch shorten it) and the span's (the bank narrows it).
        var along: Double = 1
        var across: Double = 1
        /// Top view: the bank, −1…1 (which wing is lower, and how much it darkens).
        var bank: Double = 0
        /// Front view: its size as seen (`1 / z`, 1 when it turns), how open it is (0 a sliver, 1 fully turned) and its roll (radians).
        var scale: Double = 1
        var opening: Double = 1
        var roll: Double = 0
        /// The engines: 1 at cruise, more as they charge and burn.
        var thrust: Double = 1
        var opacity: Double = 1
        /// 0…1: how strongly its light falls on the page, and the flash as it passes the glass.
        var glow: Double = 0
        var flash: Double = 0
    }

    /// The pose at `time` seconds after the run ended; nil once it has passed the glass.
    static func pose(at time: TimeInterval, origin: CGPoint, anchor: CGPoint) -> Pose? {
        guard time >= 0, time < duration else { return nil }
        if time < anticipation { return crouch(at: time / anticipation, origin: origin) }
        let launched = time - anticipation
        if launched < launch { return arc(at: launched / launch, origin: origin, anchor: anchor) }
        return closer(at: (launched - launch) / approach, origin: origin, anchor: anchor)
    }

    // MARK: - The acts

    private static func crouch(at progress: Double, origin: CGPoint) -> Pose {
        let eased = easeInOut(progress)
        return Pose(
            position: CGPoint(x: origin.x - 5 * eased, y: origin.y), view: .top,
            along: 1 - 0.12 * eased, across: 1 + 0.06 * eased, thrust: 1 + 1.4 * eased
        )
    }

    private static func arc(at progress: Double, origin: CGPoint, anchor: CGPoint) -> Pose {
        let path = launchPath(origin: origin, anchor: anchor)
        let along = launchTiming(progress)
        // Steering a little ahead of where it is, and banking as much as the path turns there.
        let heading = path.heading(at: min(1, along + 0.04))
        let turn = angle(path.heading(at: min(1, along + 0.07)), minus: path.heading(at: max(0, along - 0.07)))
        let pitchStart = 1 - pitchShare
        let pitch = progress > pitchStart ? easeIn((progress - pitchStart) / pitchShare) : 0
        let bank = max(-1, min(1, -turn * 1.5)) * (1 - pitch)
        let speed = launchSpeed(progress)
        return Pose(
            position: path.point(at: along), view: .top, heading: heading,
            along: (1 + 0.18 * speed) * (1 - 0.95 * pitch), across: cos(bank * .pi / 3), bank: bank, thrust: 2.4 - 0.5 * progress
        )
    }

    private static func closer(at progress: Double, origin: CGPoint, anchor: CGPoint) -> Pose {
        // Constant speed toward the screen, a touch faster at the end: the size grows as `1 / z` does, slowly and then all at once.
        let distance = 1 - (1 - nearest) * pow(progress, 1.15)
        let scale = 1 / distance
        let reach = scale - 1
        // It carries on a little the way it was flying as it turned, along a gentle curve across its way out.
        let came = launchPath(origin: origin, anchor: anchor).tangent(at: 1)
        let cameLength = max(1, hypot(came.dx, came.dy))
        let carry = 16 * (1 - exp(-6 * progress))
        let across = CGVector(dx: -passing.dy, dy: passing.dx)
        let acrossLength = hypot(across.dx, across.dy)
        let curve = 10 * sin(.pi * progress)
        let near = max(0, (progress - 0.82) / 0.18)
        return Pose(
            position: CGPoint(
                x: anchor.x + passing.dx * reach + came.dx / cameLength * carry + across.dx / acrossLength * curve,
                y: anchor.y + passing.dy * reach + came.dy / cameLength * carry + across.dy / acrossLength * curve
            ),
            view: .front, scale: scale, opening: easeOut(min(1, progress / 0.12)),
            roll: 0.28 * (1 - easeOut(min(1, progress * 3))) - 0.16 * sin(.pi * progress),
            thrust: 1.8 + 0.6 * progress, opacity: 1 - pow(near, 2),
            glow: min(1, reach / 6), flash: near > 0 ? sin(.pi * near) : 0
        )
    }

    /// The launch's progress along its path: from rest out of the crouch, fastest a little past the middle, and still moving (60% of its mean
    /// speed) as it turns to the viewer (a cubic with those two speeds at its ends).
    static func launchTiming(_ progress: Double) -> Double {
        -1.4 * pow(progress, 3) + 2.4 * pow(progress, 2)
    }

    /// Its speed, 0…1 of the fastest.
    private static func launchSpeed(_ progress: Double) -> Double {
        (-4.2 * progress * progress + 4.8 * progress) / 1.372
    }

    /// The difference of two headings, wrapped to −π…π.
    private static func angle(_ first: Double, minus second: Double) -> Double {
        let difference = first - second
        return atan2(sin(difference), cos(difference))
    }

    // MARK: - The launch arc

    /// A cubic curve out of the tank: forward along the tank, then up and around toward `anchor`, arriving climbing and a little to the left,
    /// so the nose is already rising as it pitches to the viewer.
    static func launchPath(origin: CGPoint, anchor: CGPoint) -> Bezier {
        let start = CGPoint(x: origin.x - 5, y: origin.y)
        // `anchor` is the tank's middle, so the tank ends near `2 × anchor.x`: with a full tank the swing out is shorter, staying on screen.
        let rightmost = 2 * anchor.x
        return Bezier(
            start: start,
            control1: CGPoint(x: start.x + min(85, max(36, (rightmost - 20 - start.x) / 0.45)), y: start.y - 4),
            // Always above the tank, so the climb never dips back into it when the tank is fuller than half.
            control2: CGPoint(x: max(anchor.x + 34, min(start.x + 30, rightmost - 30)), y: anchor.y + 40),
            end: anchor
        )
    }

    struct Bezier: Equatable {
        var start, control1, control2, end: CGPoint

        func point(at t: Double) -> CGPoint {
            let u = 1 - t
            let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
            return CGPoint(
                x: a * start.x + b * control1.x + c * control2.x + d * end.x,
                y: a * start.y + b * control1.y + c * control2.y + d * end.y
            )
        }

        func heading(at t: Double) -> Double {
            let direction = tangent(at: t)
            return atan2(direction.dy, direction.dx)
        }

        func tangent(at t: Double) -> CGVector {
            let u = 1 - t
            let a = 3 * u * u, b = 6 * u * t, c = 3 * t * t
            return CGVector(
                dx: a * (control1.x - start.x) + b * (control2.x - control1.x) + c * (end.x - control2.x),
                dy: a * (control1.y - start.y) + b * (control2.y - control1.y) + c * (end.y - control2.y)
            )
        }
    }

    // MARK: - Easing

    static func easeInOut(_ value: Double) -> Double {
        value < 0.5 ? 4 * value * value * value : 1 - pow(-2 * value + 2, 3) / 2
    }

    static func easeIn(_ value: Double) -> Double { value * value }

    static func easeOut(_ value: Double) -> Double { 1 - pow(1 - value, 3) }
}
