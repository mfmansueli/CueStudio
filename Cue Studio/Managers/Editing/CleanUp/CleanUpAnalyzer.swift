//
//  CleanUpAnalyzer.swift
//  Cue Studio
//

import Foundation

/// Everything Clean Up suggests for a take, from its pauses and, when it could be heard, its
/// transcript: filler words, possible retakes, and the tries at a script line said more than once
/// (`ScriptRetakeDetector`). Suggestions only, each with how sure it is; the ones below
/// `CleanUpSuggestion.sureConfidence` wait for the creator to listen. Pure, so it is tested with
/// made-up pauses and words.
nonisolated enum CleanUpAnalyzer {
    /// A silence at least this long is a long pause, sure enough for "Remove all". Shorter ones
    /// may be for emphasis.
    static let longPause = CleanUpSuggestion.longPauseLength
    static let longPauseConfidence = 0.95
    static let shortPauseConfidence = 0.6

    /// A pause heard only by a silence level that followed the background or a soft voice (`PauseHearing`): never sure, so never
    /// in "Remove all", and not marked to go (`CleanUpSuggestion.isMarkedByDefault`).
    static let heardLongPauseConfidence = 0.5
    static let heardShortPauseConfidence = 0.4

    /// The suggestions for silences heard clearly (a quiet room, the fixed level), as before the levels followed the background.
    /// `script`: the take's script ("" for a freestyle take), for the lines said more than once (`ScriptRetakeDetector`).
    static func suggestions(silences: [TimeSpan], transcript: TakeTranscript?, script: String = "") -> [CleanUpSuggestion] {
        let pauses = silences.map { cut in
            PauseDetection.Pause(
                cut: cut, silence: TimeSpan(start: cut.start - SilenceDetector.padding, end: cut.end + SilenceDetector.padding), isClear: true
            )
        }
        return findings(pauses: PauseDetection(hearing: .clear, pauses: pauses), transcript: transcript, script: script).suggestions
    }

    /// Everything Clean Up suggests from the pauses `SilenceDetector.pauses` heard and, when it could be heard, the transcript.
    static func findings(pauses detection: PauseDetection, transcript: TakeTranscript?, script: String = "") -> CleanUpFindings {
        var found = detection.pauses.map { pause in
            if pause.isClear {
                return CleanUpSuggestion(
                    kind: .pause, span: pause.cut,
                    confidence: SilenceDetector.silenceLength(ofCut: pause.cut) >= longPause ? longPauseConfidence : shortPauseConfidence
                )
            }
            return CleanUpSuggestion(
                kind: .pause, span: pause.cut,
                confidence: pause.silence.duration >= longPause ? heardLongPauseConfidence : heardShortPauseConfidence,
                hearing: detection.hearing == .softVoice ? .softVoice : .overBackgroundSound, silence: pause.silence
            )
        }
        if let transcript {
            // The shared recognizer can time a whole phrase, not its individual words. Such a
            // phrase must never become a high-confidence word-sized removal of the whole audio.
            // Keep pauses available, and only match within uninterrupted measured-word runs.
            let measured = transcript.words.split(whereSeparator: \.isEstimated).map(Array.init)
            let tries = measured.flatMap { ScriptRetakeDetector.suggestions(in: $0, script: script) }
            // A false start the script's tries already hold is one of those tries.
            let retakes = measured.flatMap { RetakeDetector.suggestions(in: $0, languageCode: transcript.languageCode) }
                .filter { retake in !tries.contains { $0.span.overlaps(retake.span) } }
            let fillers = measured.flatMap { FillerWordDetector.suggestions(in: $0, languageCode: transcript.languageCode) }
            // Removing a retake takes the pauses and fillers inside it too. A try at a script line may be the one kept, so what
            // is inside it stays listed on its own.
            found = (found + fillers).filter { suggestion in
                !retakes.contains { $0.span.start <= suggestion.span.start && suggestion.span.end <= $0.span.end }
            } + retakes + tries
        }
        return CleanUpFindings(
            suggestions: found.sorted { $0.span.start < $1.span.start }, pauseHearing: detection.hearing,
            hearing: CleanUpHearing(wordsLanguage: transcript?.languageCode)
        )
    }

    /// A new analysis joined with what the creator already decided: kept and removed suggestions
    /// stay as they are; undecided ones are replaced by the new findings, except where a decided
    /// one already sits.
    static func merged(_ found: [CleanUpSuggestion], into existing: [CleanUpSuggestion]) -> [CleanUpSuggestion] {
        let decided = existing.filter { $0.status != .pending }
        // Only decisions about the same recording count: the same second of another one is another moment.
        let fresh = found.filter { new in !decided.contains { $0.sourceID == new.sourceID && $0.span.overlaps(new.span) } }
        return (decided + fresh).sorted { $0.span.start < $1.span.start }
    }
}
