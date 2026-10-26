//
//  FakeObjectTracker.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Follows whatever a test says: each call gets the samples `path` gives for the stretch asked (forwards or backwards), lost
/// where `lostAfter` says, stopping early when told (and then only after `stopAfter` samples, to test Cancel keeping what was
/// followed).
nonisolated final class FakeObjectTracker: ObjectTracking, @unchecked Sendable {
    /// The object's box at a second of the recording.
    let path: @Sendable (TimeInterval) -> NormalizedBox
    /// Seconds of the recording past which (forwards) the object is lost; nil: never.
    var lostAfter: TimeInterval?
    /// Waits this long per sample, so a test can cancel meanwhile.
    var delay: Duration = .zero
    private(set) var calls: [(at: TimeInterval, until: TimeInterval)] = []

    init(path: @escaping @Sendable (TimeInterval) -> NormalizedBox) {
        self.path = path
    }

    @concurrent
    func track(
        videoAt url: URL, box: NormalizedBox, at time: TimeInterval, until: TimeInterval, shouldStop: @escaping @Sendable () -> Bool,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [TrackSample] {
        calls.append((time, until))
        let step = 1.0 / 30 * (until >= time ? 1 : -1)
        var samples = [TrackSample(time: time, box: box, confidence: 1)]
        var moment = time + step
        while until >= time ? moment <= until + 0.000_1 : moment >= until - 0.000_1 {
            try Task.checkCancellation()
            if shouldStop() { break }
            if let lostAfter, until >= time, moment > lostAfter { break }
            if delay > .zero { try await Task.sleep(for: delay) }
            samples.append(TrackSample(time: moment, box: path(moment), confidence: 0.9))
            progress(min(1, abs(moment - time) / max(0.001, abs(until - time))))
            moment += step
        }
        return samples.sorted { $0.time < $1.time }
    }
}
