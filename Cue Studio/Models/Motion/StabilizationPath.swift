//
//  StabilizationPath.swift
//  Cue Studio
//

import Foundation

/// How Stabilize holds a recording steady, worked out once from its analysis: the picture's path (its frame-to-frame slides
/// and turns added up) is smoothed both ways, so slow, meant movement stays and the shake goes; each frame is moved and turned
/// by what separates it from the smooth path, and the whole recording is zoomed in just enough to hide the edges that moving
/// shows (never past the level's limit: a bigger correction is cut short instead, so an edge never shows). Pure: the preview
/// and the export read the same path.
nonisolated struct StabilizationPath: Hashable, Sendable {
    /// Seconds of the recording of each frame measured.
    let times: [TimeInterval]
    /// How far to move each frame, as fractions of the upright frame's width and height (right and down positive).
    let dx: [Double]
    let dy: [Double]
    /// How far to turn each frame, in radians (clockwise positive).
    let angles: [Double]
    /// How much the frame is zoomed in, 1 or more.
    let zoom: Double
    /// The recording's frames per second: a frame the edit holds (slow motion, a slower recording) keeps its own correction.
    var frameRate: Double = 30

    /// The correction at `time` (seconds of the recording), between the two frames around it; none before the first or after
    /// the last measured.
    func correction(at moment: TimeInterval) -> (dx: Double, dy: Double, angle: Double) {
        // The frame showing at `moment`: the last one that started by then.
        let time = frameRate > 0 ? (moment * frameRate + 0.001).rounded(.down) / frameRate : moment
        guard let first = times.first, let last = times.last, time >= first, time <= last else {
            if let first = times.first, time < first { return (dx[0], dy[0], angles[0]) }
            if !times.isEmpty { return (dx[dx.count - 1], dy[dy.count - 1], angles[angles.count - 1]) }
            return (0, 0, 0)
        }
        // The first frame at or after `time`.
        var low = 0, high = times.count - 1
        while low < high {
            let middle = (low + high) / 2
            if times[middle] < time { low = middle + 1 } else { high = middle }
        }
        guard low > 0, times[low] > time else { return (dx[low], dy[low], angles[low]) }
        let before = low - 1
        let part = (time - times[before]) / max(0.000_1, times[low] - times[before])
        return (
            dx[before] + (dx[low] - dx[before]) * part,
            dy[before] + (dy[low] - dy[before]) * part,
            angles[before] + (angles[low] - angles[before]) * part
        )
    }

    /// The path for the analyzed recording at `level`; nil when nothing was measured.
    static func make(_ analysis: MotionAnalysis, level: StabilizationLevel) -> StabilizationPath? {
        let shifts = analysis.shifts
        guard shifts.count > 2 else { return nil }
        // The picture's path: where it has drifted by each frame.
        var x = 0.0, y = 0.0, turn = 0.0
        var pathX: [Double] = [], pathY: [Double] = [], pathA: [Double] = []
        for shift in shifts {
            x += shift.dx
            y += shift.dy
            turn += shift.angle
            pathX.append(x)
            pathY.append(y)
            pathA.append(turn)
        }
        let span = (shifts.last?.time ?? 0) - (shifts.first?.time ?? 0)
        let rate = span > 0 ? Double(shifts.count - 1) / span : MotionAnalysis.shiftRate
        let sigma = level.smoothing * rate
        let smoothX = GaussianSmoothing.smoothed(pathX, sigma: sigma)
        let smoothY = GaussianSmoothing.smoothed(pathY, sigma: sigma)
        let smoothA = GaussianSmoothing.smoothed(pathA, sigma: sigma)
        let aspect = analysis.aspect > 0 ? analysis.aspect : 1
        // The least zoom that hides the edges for most frames (nine in ten), within the level's limit: "minimal crop". Where
        // the camera moves more than that (a pan, a turn), the path bends along the corridor below instead of zooming in more.
        let needed = pathX.indices.map {
            zoomNeeded(dx: smoothX[$0] - pathX[$0], dy: smoothY[$0] - pathY[$0], angle: smoothA[$0] - pathA[$0], aspect: aspect)
        }.sorted()
        let typical = needed[min(needed.count - 1, Int(Double(needed.count) * 0.9))]
        let zoom = min(level.maximumZoom, max(1, typical))
        // What the zoom hides: the turn within part of it (no more than the turns need), the slide in what's left.
        let turns = pathA.indices.map { abs(smoothA[$0] - pathA[$0]) }.sorted()
        let turnLimit = max(0, min(turnAllowed(zoom: zoom, aspect: aspect), turns[min(turns.count - 1, Int(Double(turns.count) * 0.98))]))
        let slideLimit = max(0, (zoom - zoomNeeded(dx: 0, dy: 0, angle: turnLimit, aspect: aspect)) / 2)
        // A bigger jolt than the zoom hides isn't cut short at once (that would jerk): the smooth path is kept inside the
        // corridor the zoom allows around the real one and smoothed again, a few times, so it bends softly around the jolt.
        let cx = corridor(pathX, smooth: smoothX, limit: slideLimit, sigma: sigma)
        let cy = corridor(pathY, smooth: smoothY, limit: slideLimit, sigma: sigma)
        let ca = corridor(pathA, smooth: smoothA, limit: turnLimit, sigma: sigma)
        return StabilizationPath(times: shifts.map(\.time), dx: cx, dy: cy, angles: ca, zoom: zoom, frameRate: analysis.frameRate ?? 30)
    }

    /// The corrections (smooth path minus real path) kept within `limit`: the smooth path is pulled into the corridor around
    /// the real one and smoothed again (half as much), three times, then cut to the corridor for good.
    private static func corridor(_ path: [Double], smooth: [Double], limit: Double, sigma: Double) -> [Double] {
        var current = smooth
        for _ in 0..<3 {
            let inside = zip(current, path).map { $1 + min(max($0 - $1, -limit), limit) }
            current = GaussianSmoothing.smoothed(inside, sigma: sigma / 2)
        }
        return zip(current, path).map { min(max($0 - $1, -limit), limit) }
    }

    /// The zoom that keeps a frame of `aspect` (width over height) covered when it's moved by `dx`, `dy` (fractions) and
    /// turned by `angle`.
    static func zoomNeeded(dx: Double, dy: Double, angle: Double, aspect: Double) -> Double {
        let turn = abs(cos(angle)) + abs(sin(angle)) * max(aspect, 1 / aspect)
        return turn + 2 * max(abs(dx), abs(dy))
    }

    /// The biggest turn allowed with `zoom`: what 40% of the zoom's room hides (the rest is for the slides).
    private static func turnAllowed(zoom: Double, aspect: Double) -> Double {
        let ratio = max(aspect, 1 / aspect)
        // cos a + ratio · sin a ≤ 1 + 0.4 (zoom − 1); for small angles ≈ 1 + ratio · a.
        return (zoom - 1) * 0.4 / ratio
    }
}
