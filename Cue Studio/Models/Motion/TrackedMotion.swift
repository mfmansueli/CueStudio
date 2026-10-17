//
//  TrackedMotion.swift
//  Cue Studio
//

import Foundation

/// Track's result as keyframes the creator can edit: the followed points (the item's center at each frame, in its own time)
/// thinned to the fewest keyframes that keep the path within a hair of it (Ramer–Douglas–Peucker over time), at an even pace
/// between them, with the size and opacity the item had there. Pure.
nonisolated enum TrackedMotion {
    /// How far (a share of the frame) the thinned path may stray from the followed one.
    static let tolerance = 0.004
    /// Closest two keyframes can be.
    static let shortestGap: TimeInterval = 1.0 / 15

    struct Point: Hashable, Sendable {
        /// Seconds into the item.
        var time: TimeInterval
        var center: OverlayPoint
    }

    /// The keyframes for `points` (in time order). `state` gives the size and opacity the item has at a moment.
    static func keyframes(for points: [Point], state: (TimeInterval) -> (scale: Double, opacity: Double)) -> [OverlayKeyframe] {
        let kept = thinned(points)
        return kept.map { point in
            let held = state(point.time)
            return OverlayKeyframe(time: point.time, center: point.center.clamped, scale: held.scale, opacity: held.opacity, easing: .linear)
        }
    }

    /// The fewest points that keep the path within `tolerance`, the first and last always.
    static func thinned(_ points: [Point]) -> [Point] {
        var spaced: [Point] = []
        for point in points where spaced.last.map({ point.time - $0.time >= shortestGap - 0.000_1 }) ?? true {
            spaced.append(point)
        }
        if let last = points.last, spaced.last != last { spaced.append(last) }
        guard spaced.count > 2 else { return spaced }
        var keep = Array(repeating: false, count: spaced.count)
        keep[0] = true
        keep[spaced.count - 1] = true
        var stack = [(0, spaced.count - 1)]
        while let (from, to) = stack.popLast() {
            guard to - from > 1 else { continue }
            let start = spaced[from], end = spaced[to]
            var worst = 0.0, worstIndex = from
            for index in (from + 1)..<to {
                let point = spaced[index]
                let part = (point.time - start.time) / max(0.000_1, end.time - start.time)
                let x = start.center.x + (end.center.x - start.center.x) * part
                let y = start.center.y + (end.center.y - start.center.y) * part
                let distance = hypot(point.center.x - x, point.center.y - y)
                if distance > worst {
                    worst = distance
                    worstIndex = index
                }
            }
            if worst > tolerance {
                keep[worstIndex] = true
                stack.append((from, worstIndex))
                stack.append((worstIndex, to))
            }
        }
        return spaced.indices.filter { keep[$0] }.map { spaced[$0] }
    }
}
