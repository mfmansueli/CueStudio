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
/// check the timing and nothing claims a measurement it doesn't have. A word heard as starting in the silence before the voice
/// starts where the voice does.
///
/// The spoken stretch is read against the take's own room: people's recordings (FLEURS, measured on an iPhone) open with one to
/// three seconds of hiss at −38 to −44 dBFS, which a fixed level took for speech, so measured times were spread over the hiss and
/// lost, and estimated ones started two seconds before anyone spoke.
nonisolated enum TranscriptTimingCheck {
    /// Share of the spoken stretch the words must cover, at least, for their times to be taken as measured.
    static let minimumCoverage = 0.7
    /// Fewest words, and shortest speech, before the check says anything.
    static let minimumWords = 6
    static let minimumSpeech: TimeInterval = 3
    /// Level above which a take in a quiet room is speaking, in dBFS.
    static let speechLevel: Float = -45
    /// How far above the room's own noise (its quietest tenth) speech is, in dB, in a louder room.
    static let aboveNoise: Float = 12
    /// Speech is never asked to be louder than this far under the loudest reading, in dB: a take that is nearly all speech has
    /// a quietest tenth made of speech.
    static let underLoudest: Float = 10
    /// Seconds of readings a start or an end is checked over, half of which have to be speech: a click isn't.
    static let sustain: TimeInterval = 0.2
    /// How far before the voice a word may start before it is moved to it: smaller differences are the recognizer's to keep.
    static let leadTolerance: TimeInterval = 0.3

    /// The stretch of the take that is speaking, from the level of each `interval`: from the first reading above `level(for:)`
    /// that half of the next `sustain` are too, to the last such reading. Nil when nothing is.
    static func spokenSpan(levels: [Float], interval: TimeInterval) -> TimeSpan? {
        guard !levels.isEmpty else { return nil }
        let threshold = level(for: levels)
        let run = max(1, Int((sustain / interval).rounded()))
        let needed = max(1, run / 2)
        let sustained = { (range: Range<Int>) in levels[range].count { $0 > threshold } >= needed }
        guard let first = levels.indices.first(where: { levels[$0] > threshold && sustained($0..<min(levels.count, $0 + run)) }),
              let last = levels.indices.last(where: { levels[$0] > threshold && sustained(max(0, $0 - run + 1)..<($0 + 1)) })
        else { return nil }
        return TimeSpan(start: Double(first) * interval, end: Double(last + 1) * interval)
    }

    /// The level speech is told from the room by: `speechLevel` in a quiet room, `aboveNoise` over the room's noise in a louder
    /// one, never more than `underLoudest` under the loudest reading.
    static func level(for levels: [Float]) -> Float {
        let sorted = levels.sorted()
        guard let loudest = sorted.last else { return speechLevel }
        let noise = sorted[sorted.count / 10]
        return min(max(speechLevel, noise + aboveNoise), max(speechLevel, loudest - underLoudest))
    }

    /// `words`, a word that starts more than `leadTolerance` before the voice and goes on into it starting where the voice
    /// does. Korean's transcriber stretched the first word back to the start of the recording (up to 2.4 s before anyone spoke,
    /// people's voices on an iPhone): its caption showed, and its word lit, in the silence.
    static func startingWithTheVoice(_ words: [TimedWord], spoken: TimeSpan?) -> [TimedWord] {
        guard let spoken else { return words }
        return words.map { word in
            guard word.start < spoken.start - leadTolerance, word.end > spoken.start + 0.05 else { return word }
            var moved = word
            moved.start = spoken.start
            return moved
        }
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
