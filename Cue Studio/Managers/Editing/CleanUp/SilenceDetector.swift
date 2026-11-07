//
//  SilenceDetector.swift
//  Cue Studio
//

import Foundation

/// Finds the pauses Clean Up suggests, from the loudness of the take over time. It finds them from
/// 0.3 s up; Clean Up's "Ignore pauses under" decides which ones the creator sees. Pure, so it is
/// tested with made-up levels.
///
/// In a quiet room a pause is what stays under a fixed silence level (`silences`). `pauses` first measures the recording
/// (`BackgroundLevel`): when a fan, traffic or music keeps it above that level, or the voice itself is so soft that the level would
/// take quiet words for pauses, the level follows the background instead (D16). What a moved level finds is less certain, so it is
/// listed for a listen but never marked to go, its edges keep more breath, and a stretch where even the voice nearby stays close
/// to the background is let pass. When the voice doesn't stand clear of the background at all, the moved level isn't used:
/// `PauseHearing.tooMuchBackgroundSound`. Measured on a corpus of FLEURS readings mixed with made fan, traffic and music noise
/// (`NoisyRoomPauseTests`).
nonisolated enum SilenceDetector {
    /// Quieter than this (dBFS) counts as silence.
    static let threshold: Float = -42
    /// Pauses shorter than this are part of speaking and are never suggested.
    static let minimumSilence: TimeInterval = 0.3
    /// Kept on each side of a cut so words never lose their first or last sound.
    static let padding: TimeInterval = 0.12

    // MARK: - A moved level (D16)

    /// The voice (`BackgroundLevel.speech`) at least this far above the fixed level: the fixed level is clear of it, pauses as always.
    static let clearHeadroom: Float = 18
    /// A moved level sits this far above the background: its own wobble (`spread`) and 1.5 dB, from 2.5 to 6 dB.
    static let marginRange: ClosedRange<Float> = 2.5...6
    /// Under this much between voice and background (less twice its wobble), the voice doesn't stand clear of it.
    static let minimumSeparation: Float = 12
    /// A moved level at least this far under the voice, overall and in the 2.5 s around each pause (a quieter stretch of a take can
    /// sit at the background's level).
    static let minimumHeadroom: Float = 8
    static let localReach: TimeInterval = 2.5
    /// A pause found by a moved level starts and ends where the sound has settled this close to the background (at most the
    /// level), not where it crossed the level: the end of a word fades into the background, and a soft stretch of speech can sit
    /// just under the level, next to a pause.
    static let settledMargin: Float = 1
    /// And is at least this long, keeping this much on each side of its cut (a weak consonant can hide under a background).
    static let uncertainMinimum: TimeInterval = 0.5
    static let uncertainPadding: TimeInterval = 0.25

    /// `levels` are dBFS readings, one every `interval` seconds from the start of the recording.
    static func silences(levels: [Float], interval: TimeInterval) -> [TimeSpan] {
        silences(levels: levels, interval: interval, under: threshold)
    }

    /// The pauses of a recording and how sure they are, the silence level following the background when it has to.
    static func pauses(levels: [Float], interval: TimeInterval) -> PauseDetection {
        let fixed = silences(levels: levels, interval: interval)
        guard interval > 0, let level = BackgroundLevel.measure(levels) else { return clear(fixed) }
        // The voice well above the fixed level: what falls under it is a pause, as always.
        let voiceIsClear = level.speech - threshold >= clearHeadroom
        let underFixed = fixed.map { PauseDetection.Pause(cut: $0, silence: padded($0), isClear: voiceIsClear) }
        let margin = min(marginRange.upperBound, max(marginRange.lowerBound, level.spread + 1.5))
        if level.lowest > threshold {
            // A background louder than the fixed level: the level rises with it.
            let gate = level.floor + margin
            guard level.speech - level.floor - 2 * level.spread >= minimumSeparation, level.speech - gate >= minimumHeadroom else {
                return PauseDetection(hearing: .tooMuchBackgroundSound, pauses: underFixed)
            }
            let heard = uncertainPauses(levels: levels, interval: interval, under: gate, background: level)
                .filter { pause in !underFixed.contains { $0.silence.overlaps(pause.silence) } }
            // Nothing at all under a background: the take may flow, or the background may hide its pauses. Clean Up can't tell.
            guard !heard.isEmpty || !underFixed.isEmpty else { return PauseDetection(hearing: .tooMuchBackgroundSound, pauses: []) }
            return PauseDetection(hearing: .overBackgroundSound, pauses: (underFixed + heard).sorted { $0.cut.start < $1.cut.start })
        }
        guard !voiceIsClear else { return clear(fixed) }
        // A quiet room but a soft voice: the fixed level would take its quiet words for pauses, so the level goes under the voice.
        let gate = min(threshold, max(level.floor + margin, level.speech - clearHeadroom))
        guard level.speech - level.floor >= minimumSeparation, level.speech - gate >= minimumHeadroom else {
            return PauseDetection(hearing: .tooMuchBackgroundSound, pauses: [])
        }
        return PauseDetection(hearing: .softVoice, pauses: uncertainPauses(levels: levels, interval: interval, under: gate, background: level))
    }

    /// How long the silence around a cut really was: the cut keeps `padding` on each side.
    static func silenceLength(ofCut span: TimeSpan) -> TimeInterval {
        span.duration + 2 * padding
    }

    /// How long a pause's silence was: the one it was heard as, or its cut and the breath on each side.
    static func silenceLength(of suggestion: CleanUpSuggestion) -> TimeInterval {
        suggestion.silence?.duration ?? silenceLength(ofCut: suggestion.span)
    }

    // MARK: - Private

    private static func clear(_ fixed: [TimeSpan]) -> PauseDetection {
        PauseDetection(hearing: .clear, pauses: fixed.map { PauseDetection.Pause(cut: $0, silence: padded($0), isClear: true) })
    }

    private static func padded(_ cut: TimeSpan) -> TimeSpan {
        TimeSpan(start: cut.start - padding, end: cut.end + padding)
    }

    /// Runs under `gate`, each kept with `padding` on both sides when it lasts `minimumSilence`.
    private static func silences(levels: [Float], interval: TimeInterval, under gate: Float) -> [TimeSpan] {
        guard interval > 0 else { return [] }
        var result: [TimeSpan] = []
        var runStart: Int?
        for (index, level) in levels.enumerated() + [(levels.count, Float.greatestFiniteMagnitude)] {
            if level < gate {
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

    /// The runs under a moved `gate`, as unsure pauses: their edges where the sound settles near the background, long enough,
    /// with the voice around them clear of the gate, and a wider breath on each side.
    private static func uncertainPauses(
        levels: [Float], interval: TimeInterval, under gate: Float, background: BackgroundLevel
    ) -> [PauseDetection.Pause] {
        let settled = min(gate, background.floor + max(settledMargin, background.spread + 1))
        let reach = Int(localReach / interval)
        var result: [PauseDetection.Pause] = []
        var runStart: Int?
        for (index, level) in levels.enumerated() + [(levels.count, Float.greatestFiniteMagnitude)] {
            if level < gate {
                if runStart == nil { runStart = index }
                continue
            }
            guard var start = runStart else { continue }
            runStart = nil
            var end = index
            while start < end, levels[start] > settled { start += 1 }
            while end > start, levels[end - 1] > settled { end -= 1 }
            guard Double(end - start) * interval >= uncertainMinimum else { continue }
            let around = (levels[max(0, start - reach)..<start] + levels[end..<min(levels.count, end + reach)]).sorted()
            if let voice = around.isEmpty ? nil : around[around.count * 9 / 10], voice - gate < minimumHeadroom { continue }
            let silence = TimeSpan(start: Double(start) * interval, end: Double(end) * interval)
            let cut = TimeSpan(start: silence.start + uncertainPadding, end: silence.end - uncertainPadding)
            if cut.duration > 0 { result.append(PauseDetection.Pause(cut: cut, silence: silence, isClear: false)) }
        }
        return result
    }
}
