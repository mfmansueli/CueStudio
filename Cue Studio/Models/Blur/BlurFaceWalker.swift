//
//  BlurFaceWalker.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// One way through a recording's face samples (`BlurFollowing.followFace`), keeping hold of one face: each next face must be
/// near where this one was going and about its size; when two could be it the moment is ambiguous, and when none can it's lost
/// until one comes back near where it was lost.
nonisolated struct BlurFaceWalker {
    enum Step {
        case found(NormalizedBox, ambiguous: Bool, reacquired: (lost: TimeSpan, heldFace: NormalizedBox)?)
        case lost
    }

    var face: NormalizedBox
    var time: TimeInterval
    let forward: Bool
    var velocity = CGVector(dx: 0, dy: 0)
    /// When it was last seen, while it's lost.
    var lostAt: TimeInterval?

    init(face: NormalizedBox, time: TimeInterval, forward: Bool) {
        self.face = face
        self.time = time
        self.forward = forward
    }

    /// A stretch with no samples at all before `next` (the analysis skipped it), which nothing confirms.
    func gap(before next: TimeInterval) -> TimeSpan? {
        guard abs(next - time) > BlurFollowing.longestStep, lostAt == nil else { return nil }
        return TimeSpan(start: min(time, next), end: max(time, next))
    }

    mutating func step(to sample: SubjectSample) -> Step {
        let elapsed = sample.time - time
        let away = lostAt.map { abs(sample.time - $0) } ?? 0
        let size = max(face.width, face.height)
        // Where it was going, carried on a few frames at most: a face lost for a while is looked for near where it was lost.
        let carried = min(max(elapsed, -0.3), 0.3)
        let predicted = CGPoint(x: face.midX + velocity.dx * carried, y: face.midY + velocity.dy * carried)
        // Further the longer it's been lost, never across the whole frame; once lost, only a face of about its size.
        let gate = size * (0.9 + 2 * min(away, 1)) + 0.02
        let sizes: ClosedRange<Double> = lostAt == nil ? 0.55...1.8 : 0.7...1.45
        let scored = sample.faces.compactMap { candidate -> (box: NormalizedBox, score: Double)? in
            let distance = hypot(candidate.midX - predicted.x, candidate.midY - predicted.y)
            let ratio = max(candidate.width, candidate.height) / max(0.000_1, size)
            guard distance <= gate, sizes.contains(ratio) else { return nil }
            return (candidate, distance / max(0.000_1, size) + abs(log(ratio)) * 0.6)
        }.sorted { $0.score < $1.score }
        guard let best = scored.first else {
            if lostAt == nil { lostAt = time }
            return .lost
        }
        // Another face that could be it: nearly as likely, or over this one (faces crossing, which Vision may swap).
        let ambiguous = scored.count > 1 && (
            scored[1].score < best.score * 1.35 + 0.1
                || best.box.sharedArea(with: scored[1].box) > 0.3 * min(best.box.area, scored[1].box.area)
        )
        var reacquired: (lost: TimeSpan, heldFace: NormalizedBox)?
        if let lostAt {
            reacquired = (TimeSpan(start: min(lostAt, sample.time), end: max(lostAt, sample.time)), face)
            velocity = CGVector(dx: 0, dy: 0)
        } else if abs(elapsed) > 0.000_1 {
            let measured = CGVector(dx: (best.box.midX - face.midX) / elapsed, dy: (best.box.midY - face.midY) / elapsed)
            velocity = CGVector(dx: velocity.dx * 0.5 + measured.dx * 0.5, dy: velocity.dy * 0.5 + measured.dy * 0.5)
        }
        lostAt = nil
        face = best.box
        time = sample.time
        return .found(best.box, ambiguous: ambiguous, reacquired: reacquired)
    }

    /// From where it was lost to the end of the way, when it never came back.
    func lostStretch(to end: TimeInterval) -> TimeSpan? {
        guard let lostAt else { return nil }
        return TimeSpan(start: min(lostAt, end), end: max(lostAt, end))
    }
}
