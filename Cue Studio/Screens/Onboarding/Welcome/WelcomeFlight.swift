//
//  WelcomeFlight.swift
//  Cue Studio
//

import CoreGraphics

/// The star's flight in 1.1 as one smooth curve: it passes through each waypoint at its second and never stops or turns a corner on
/// the way. Between two waypoints it is a cubic Hermite curve whose velocity at each waypoint is the time-weighted mean of the legs on
/// either side (a Catmull-Rom spline with the seconds as knots), so both where it is and how fast it goes change smoothly. It fades in
/// while it comes in and is gone just after it lands for the last time.
nonisolated struct WelcomeFlight: Sendable {
    struct Waypoint: Sendable {
        let time: Double
        let point: CGPoint
    }

    let waypoints: [Waypoint]
    /// It is fully lit from `litAt`, after coming in from nothing at the first waypoint.
    let litAt: Double
    /// It goes out from `fadeFrom` to `goneAt`.
    let fadeFrom: Double
    let goneAt: Double

    /// Where the star is at `time` (`x`, `y`) and how visible (`opacity`).
    func pose(at time: Double) -> Pose {
        let point = point(at: time)
        return Pose(opacity: opacity(at: time), x: point.x, y: point.y)
    }

    func point(at time: Double) -> CGPoint {
        guard let first = waypoints.first, let last = waypoints.last else { return .zero }
        if time <= first.time { return first.point }
        if time >= last.time { return last.point }
        let index = (waypoints.lastIndex { $0.time <= time } ?? 0)
        let from = waypoints[index]
        let to = waypoints[index + 1]
        let span = to.time - from.time
        guard span > 0 else { return to.point }
        let u = (time - from.time) / span
        let u2 = u * u
        let u3 = u2 * u
        let start = velocity(at: index)
        let end = velocity(at: index + 1)
        let h00 = 2 * u3 - 3 * u2 + 1
        let h10 = u3 - 2 * u2 + u
        let h01 = -2 * u3 + 3 * u2
        let h11 = u3 - u2
        return CGPoint(
            x: h00 * from.point.x + h10 * span * start.dx + h01 * to.point.x + h11 * span * end.dx,
            y: h00 * from.point.y + h10 * span * start.dy + h01 * to.point.y + h11 * span * end.dy
        )
    }

    private func opacity(at time: Double) -> Double {
        guard let first = waypoints.first else { return 0 }
        if time <= first.time || time >= goneAt { return 0 }
        if time < litAt { return smooth((time - first.time) / (litAt - first.time)) }
        if time > fadeFrom { return 1 - smooth((time - fadeFrom) / (goneAt - fadeFrom)) }
        return 1
    }

    private func smooth(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }

    /// Points per second at waypoint `index`: the legs on either side, each weighted by the other's length in time; the ends take their
    /// only leg.
    private func velocity(at index: Int) -> CGVector {
        func leg(_ from: Int, _ to: Int) -> CGVector {
            let span = max(waypoints[to].time - waypoints[from].time, 0.0001)
            return CGVector(
                dx: (waypoints[to].point.x - waypoints[from].point.x) / span, dy: (waypoints[to].point.y - waypoints[from].point.y) / span
            )
        }
        guard waypoints.count > 1 else { return .zero }
        if index == 0 { return leg(0, 1) }
        if index == waypoints.count - 1 { return leg(index - 1, index) }
        let before = leg(index - 1, index)
        let after = leg(index, index + 1)
        let inSpan = waypoints[index].time - waypoints[index - 1].time
        let outSpan = waypoints[index + 1].time - waypoints[index].time
        let total = max(inSpan + outSpan, 0.0001)
        return CGVector(dx: (before.dx * outSpan + after.dx * inSpan) / total, dy: (before.dy * outSpan + after.dy * inSpan) / total)
    }
}
