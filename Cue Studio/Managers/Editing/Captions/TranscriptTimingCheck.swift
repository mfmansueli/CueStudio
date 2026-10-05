//
//  TranscriptTimingCheck.swift
//  Cue Studio
//

import Foundation

/// Whether the times a recognizer gave for a take's words fit the take. A word's time is only as good as
/// the recognizer's: on an iPhone, the dictation model's Hindi finished ten seconds of speech in the first
/// five (words timed at about half their real moment), while its other languages and `SpeechTranscriber`
/// fit the recording. Captions built on such times would come and go in the first half of the video and
/// pass for measured. When the words cover far less of the spoken stretch than they should, they are
/// spread over it instead and marked as estimated (`TimedWord.isEstimated`), so the creator is told to
/// check the timing and nothing claims a measurement it doesn't have.
nonisolated enum TranscriptTimingCheck {
    /// Share of the spoken stretch the words must cover, at least, for their times to be taken as measured.
    static let minimumCoverage = 0.7
    /// Fewest words, and shortest speech, before the check says anything.
    static let minimumWords = 6
    static let minimumSpeech: TimeInterval = 3
    /// Level above which the take is speaking, in dBFS.
    static let speechLevel: Float = -45

    /// The stretch of the take that is speaking, from the level of each `interval`: first to last reading
    /// above `speechLevel`. Nil when nothing is.
    static func spokenSpan(levels: [Float], interval: TimeInterval) -> TimeSpan? {
        guard let first = levels.firstIndex(where: { $0 > speechLevel }), let last = levels.lastIndex(where: { $0 > speechLevel }) else { return nil }
        return TimeSpan(start: Double(first) * interval, end: Double(last + 1) * interval)
    }

    /// `words`, with times that don't fit `spoken` spread across it and marked as estimated.
    static func reconciled(_ words: [TimedWord], spoken: TimeSpan?) -> [TimedWord] {
        guard let spoken, spoken.duration >= minimumSpeech, words.count >= minimumWords,
              let first = words.map(\.start).min(), let last = words.map(\.end).max(), last > first else { return words }
        let coverage = (last - first) / spoken.duration
        guard coverage < minimumCoverage else { return words }
        let scale = spoken.duration / (last - first)
        return words.map { word in
            var spread = word
            spread.start = spoken.start + (word.start - first) * scale
            spread.end = spoken.start + (word.end - first) * scale
            spread.isEstimated = true
            return spread
        }
    }
}
