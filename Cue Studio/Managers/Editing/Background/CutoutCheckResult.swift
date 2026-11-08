//
//  CutoutCheckResult.swift
//  Cue Studio
//

import Foundation

/// What Check the cutout found in a stretch of a recording: where the cutout fails (seconds of the recording, joined when close),
/// how many frames it read and how many a held outline covered (a failure the creator doesn't see).
nonisolated struct CutoutCheckResult: Equatable, Sendable {
    /// Two failures closer than this are one moment.
    static let joinGap: TimeInterval = 0.3

    var failures: [TimeSpan] = []
    var frames = 0
    var heldFrames = 0

    /// Joins the failing frames read at `times` (in order) into moments, each lasting until a frame after its last one (`interval`).
    static func moments(of times: [TimeInterval], interval: TimeInterval) -> [TimeSpan] {
        var moments: [TimeSpan] = []
        for time in times {
            if let last = moments.last, time - last.end <= joinGap {
                moments[moments.count - 1].end = time + interval
            } else {
                moments.append(TimeSpan(start: time, end: time + interval))
            }
        }
        return moments
    }
}
