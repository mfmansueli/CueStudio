//
//  MotionAnalyzing.swift
//  Cue Studio
//

import Foundation

/// Analyzes a recording's motion (`MotionAnalysis`): faces and bodies over time, and how the picture moves from frame to frame.
nonisolated protocol MotionAnalyzing: Sendable {
    /// Analyzes the video at `url` from where `analysis` stopped (from the start without one, or with one of another version).
    /// Hands what's done to `checkpoint` every few seconds of video, and returns early, with what's done, as soon as
    /// `shouldStop` says so. Throws when the video can't be read.
    func analyze(
        videoAt url: URL, continuing analysis: MotionAnalysis?, shouldStop: @escaping @Sendable () -> Bool,
        checkpoint: @escaping @Sendable (MotionAnalysis) -> Void
    ) async throws -> MotionAnalysis
}
