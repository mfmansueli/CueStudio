//
//  EyeContactAnalyzing.swift
//  Cue Studio
//

import Foundation

/// Finds the main person's eyes in every frame of a recording for Eye Contact (`EyeContactAnalysis`).
nonisolated protocol EyeContactAnalyzing: Sendable {
    /// Analyzes the video at `url` from what `analysis` already has (from nothing without one, or with one of another version or
    /// file): first the stretch from just before `focus` (seconds of the recording; what the preview shows), then the rest in order.
    /// Hands what's done to `checkpoint` every few seconds of video, and returns early, with what's done, as soon as `shouldStop`
    /// says so. Throws when the video can't be read. Runs off the caller's actor.
    @concurrent
    func analyze(
        videoAt url: URL, continuing analysis: EyeContactAnalysis?, focus: TimeInterval?, shouldStop: @escaping @Sendable () -> Bool,
        checkpoint: @escaping @Sendable (EyeContactAnalysis) -> Void
    ) async throws -> EyeContactAnalysis
}
