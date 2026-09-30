//
//  CleanUpAnalyzer.swift
//  Cue Studio
//

import Foundation

/// Everything Clean Up suggests for a take, from its pauses and, when it could be heard, its
/// transcript: filler words and possible retakes. Suggestions only, each with how sure it is; the
/// ones below `CleanUpSuggestion.sureConfidence` wait for the creator to listen. Pure, so it is
/// tested with made-up pauses and words.
nonisolated enum CleanUpAnalyzer {
    /// A silence at least this long is a long pause, sure enough for "Remove all". Shorter ones
    /// may be for emphasis.
    static let longPause: TimeInterval = 0.8
    static let longPauseConfidence = 0.95
    static let shortPauseConfidence = 0.6

    static func suggestions(silences: [TimeSpan], transcript: TakeTranscript?) -> [CleanUpSuggestion] {
        var found = silences.map { span in
            CleanUpSuggestion(
                kind: .pause, span: span,
                confidence: SilenceDetector.silenceLength(ofCut: span) >= longPause ? longPauseConfidence : shortPauseConfidence
            )
        }
        if let transcript {
            // The shared recognizer can time a whole phrase, not its individual words. Such a
            // phrase must never become a high-confidence word-sized removal of the whole audio.
            // Keep pauses available, and only match within uninterrupted measured-word runs.
            let measured = transcript.words.split(whereSeparator: \.isEstimated).map(Array.init)
            let retakes = measured.flatMap { RetakeDetector.suggestions(in: $0, languageCode: transcript.languageCode) }
            let fillers = measured.flatMap { FillerWordDetector.suggestions(in: $0, languageCode: transcript.languageCode) }
            // Removing a retake takes the pauses and fillers inside it too.
            found = (found + fillers).filter { suggestion in
                !retakes.contains { $0.span.start <= suggestion.span.start && suggestion.span.end <= $0.span.end }
            } + retakes
        }
        return found.sorted { $0.span.start < $1.span.start }
    }

    /// A new analysis joined with what the creator already decided: kept and removed suggestions
    /// stay as they are; undecided ones are replaced by the new findings, except where a decided
    /// one already sits.
    static func merged(_ found: [CleanUpSuggestion], into existing: [CleanUpSuggestion]) -> [CleanUpSuggestion] {
        let decided = existing.filter { $0.status != .pending }
        let fresh = found.filter { new in !decided.contains { $0.span.overlaps(new.span) } }
        return (decided + fresh).sorted { $0.span.start < $1.span.start }
    }
}
