//
//  FaceFollowPath.swift
//  Cue Studio
//

import Foundation

/// Where Follow face puts the crop's center over a recording, worked out once from its analysis the way a camera operator
/// would: it locks on one face (the nearest to where it was; the largest at first or when it's lost), lets it move inside a
/// calm zone without following, goes after it when it leaves the zone, never faster than the pace allows, and starts and stops
/// softly (the whole path smoothed both ways, so it never lags). The eyes sit a little above the middle of the frame. The crop
/// never leaves the recording. Pure: the preview and the export read the same path.
nonisolated struct FaceFollowPath: Hashable, Sendable {
    /// Seconds of the recording of the first center.
    let start: TimeInterval
    /// Seconds between two centers.
    let interval: TimeInterval
    /// The crop's center at each moment, as fractions of the upright frame from the top left.
    let xs: [Double]
    let ys: [Double]

    /// The crop's center at `time` (seconds of the recording), between the two moments around it.
    func center(at time: TimeInterval) -> (x: Double, y: Double) {
        guard let lastX = xs.last, let lastY = ys.last else { return (0.5, 0.5) }
        let position = (time - start) / interval
        guard position > 0 else { return (xs[0], ys[0]) }
        let index = Int(position)
        guard index < xs.count - 1 else { return (lastX, lastY) }
        let part = position - Double(index)
        return (xs[index] + (xs[index + 1] - xs[index]) * part, ys[index] + (ys[index + 1] - ys[index]) * part)
    }

    /// Share of the frame's height the crop's center sits below the eyes' line: the face a little above the middle.
    static let headroom = 0.1
    /// How far (as a share of the frame) the face can jump between two moments and still be the same face.
    static let sameFaceReach = 0.3

    /// The path for a crop `cropWidth` × `cropHeight` (fractions of the upright frame) over the analyzed recording; nil when
    /// the crop has no room to move or no face (or person) was found in it.
    static func make(_ analysis: MotionAnalysis, cropWidth: Double, cropHeight: Double, pace: FollowPace) -> FaceFollowPath? {
        let roomX = 1 - cropWidth, roomY = 1 - cropHeight
        guard roomX > 0.005 || roomY > 0.005, !analysis.subjects.isEmpty else { return nil }
        let interval = MotionAnalysis.subjectInterval
        let start = analysis.subjects[0].time
        let count = Int(((analysis.subjects.last?.time ?? start) - start) / interval) + 1
        // The face followed at each moment, on an even grid (a moment without a sample holds the last).
        var targets: [(x: Double, y: Double)?] = Array(repeating: nil, count: count)
        var followed: (x: Double, y: Double)?
        for sample in analysis.subjects {
            let index = min(count - 1, max(0, Int(((sample.time - start) / interval).rounded())))
            guard let face = pick(in: sample, near: followed) else { continue }
            followed = face
            targets[index] = (face.x, face.y + headroom * cropHeight)
        }
        guard let first = targets.first(where: { $0 != nil }) ?? nil else { return nil }
        // The operator: still while the face is in the calm zone, after it when it leaves, never faster than the pace.
        let zoneX = pace.deadZone * cropWidth, zoneY = pace.deadZone * cropHeight
        let stepX = pace.topSpeed * cropWidth * interval, stepY = pace.topSpeed * cropHeight * interval
        var position = clamp(first, cropWidth: cropWidth, cropHeight: cropHeight)
        var xs: [Double] = [], ys: [Double] = []
        xs.reserveCapacity(count)
        ys.reserveCapacity(count)
        for target in targets {
            if let target {
                let goal = clamp(target, cropWidth: cropWidth, cropHeight: cropHeight)
                position.x += step(toward: goal.x - position.x, zone: zoneX, limit: stepX)
                position.y += step(toward: goal.y - position.y, zone: zoneY, limit: stepY)
            }
            xs.append(position.x)
            ys.append(position.y)
        }
        let radius = pace.smoothing / interval
        let smoothX = GaussianSmoothing.smoothed(xs, sigma: radius), smoothY = GaussianSmoothing.smoothed(ys, sigma: radius)
        let clamped = zip(smoothX, smoothY).map { clamp(($0, $1), cropWidth: cropWidth, cropHeight: cropHeight) }
        return FaceFollowPath(start: start, interval: interval, xs: clamped.map(\.x), ys: clamped.map(\.y))
    }

    /// The face to follow in a sample: the nearest to the one followed, else the largest; a person's head when no face shows.
    private static func pick(in sample: SubjectSample, near followed: (x: Double, y: Double)?) -> (x: Double, y: Double)? {
        var candidates = sample.faces.map { (x: $0.midX, y: $0.midY) }
        // A body without a face (turned away, too small): its head is near the top of its box.
        if candidates.isEmpty { candidates = sample.bodies.map { (x: $0.midX, y: $0.y + $0.height * 0.12) } }
        guard let largest = candidates.first else { return nil }
        guard let followed else { return largest }
        let nearest = candidates.min { hypot($0.x - followed.x, $0.y - followed.y) < hypot($1.x - followed.x, $1.y - followed.y) }
        guard let nearest, hypot(nearest.x - followed.x, nearest.y - followed.y) <= sameFaceReach else { return largest }
        return nearest
    }

    /// How far to move toward a target `distance` away: nothing inside the zone, else up to its edge, at most `limit`.
    private static func step(toward distance: Double, zone: Double, limit: Double) -> Double {
        guard abs(distance) > zone else { return 0 }
        let wanted = distance - (distance > 0 ? zone : -zone)
        return min(max(wanted, -limit), limit)
    }

    private static func clamp(_ point: (x: Double, y: Double), cropWidth: Double, cropHeight: Double) -> (x: Double, y: Double) {
        let halfW = min(0.5, cropWidth / 2), halfH = min(0.5, cropHeight / 2)
        return (min(max(point.x, halfW), 1 - halfW), min(max(point.y, halfH), 1 - halfH))
    }
}
