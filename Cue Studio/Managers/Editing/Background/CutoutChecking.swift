//
//  CutoutChecking.swift
//  Cue Studio
//

import Foundation

/// Looks for the moments of a recording where the automatic cutout fails: Vision loses the creator for longer than the last good
/// outline is held (`PersonMaskTrack`), so the cutout turns back into the frame as recorded or loses part of the creator there.
/// Behind a protocol so the editor's tests check the panel's flow without Vision (which finds no one in the Simulator).
nonisolated protocol CutoutChecking: Sendable {
    /// The failures in `span` (seconds of the recording at `url`), with `progress` (0 to 1) as it reads; stops when its task is
    /// cancelled. Throws when the video can't be read.
    @concurrent
    func check(videoAt url: URL, over span: TimeSpan, progress: @escaping @Sendable (Double) -> Void) async throws -> CutoutCheckResult
}
