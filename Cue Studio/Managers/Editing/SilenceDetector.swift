//
//  SilenceDetector.swift
//  Cue Studio
//

import Foundation

/// Finds the pauses "Remove silences" cuts, from the loudness of the take over time. Pure, so it is
/// tested with made-up levels.
nonisolated enum SilenceDetector {
    /// Quieter than this (dBFS) counts as silence.
    static let threshold: Float = -42
    /// Pauses shorter than this are part of speaking and stay.
    static let minimumSilence: TimeInterval = 0.7
    /// Kept on each side of a cut so words never lose their first or last sound.
    static let padding: TimeInterval = 0.15

    /// `levels` are dBFS readings, one every `interval` seconds from the start of the recording.
    static func silences(levels: [Float], interval: TimeInterval) -> [TimeSpan] {
        guard interval > 0 else { return [] }
        var result: [TimeSpan] = []
        var runStart: Int?
        for (index, level) in levels.enumerated() + [(levels.count, Float.greatestFiniteMagnitude)] {
            if level < threshold {
                if runStart == nil { runStart = index }
            } else if let start = runStart {
                runStart = nil
                let span = TimeSpan(start: Double(start) * interval + padding, end: Double(index) * interval - padding)
                if Double(index - start) * interval >= minimumSilence, span.duration > 0 {
                    result.append(span)
                }
            }
        }
        return result
    }

    /// Total time the silences would cut.
    static func totalDuration(of silences: [TimeSpan]) -> TimeInterval {
        silences.reduce(0) { $0 + $1.duration }
    }
}
