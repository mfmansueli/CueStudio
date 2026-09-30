//
//  MusicEnvelope.swift
//  Cue Studio
//

import Foundation

/// How loud a music clip is over time: its volume, its fade in and out, and, when it ducks, lower
/// while someone speaks. Going down starts a moment before the voice (the edit is known ahead) and
/// coming back waits a moment after it, so nothing is cut off; stretches of speech close together
/// stay down in between rather than pumping. Pure, so it is tested with made-up spans.
nonisolated enum MusicEnvelope {
    /// How long the music stays down after the voice stops before coming back.
    static let hold: TimeInterval = 0.2
    /// Gaps shorter than this between two stretches of speech stay down.
    static let gap: TimeInterval = 0.3

    struct Point: Hashable, Sendable {
        var time: TimeInterval
        var volume: Double
    }

    /// The volume at each moment it changes, from where the music starts (`span`, the same
    /// seconds as `speech`) to where it ends; straight lines in between.
    static func points(
        span: TimeSpan, volume: Double, fadeIn: TimeInterval, fadeOut: TimeInterval, speech: [TimeSpan]?
    ) -> [Point] {
        guard span.duration > 0 else { return [] }
        let ducks = duckSpans(speech ?? [])
        let fades = fadeLengths(span: span, fadeIn: fadeIn, fadeOut: fadeOut)
        var times: Set<TimeInterval> = [span.start, span.end, span.start + fades.in, span.end - fades.out]
        for duck in ducks {
            times.formUnion([duck.start - MusicClip.duckRamp, duck.start, duck.end + hold, duck.end + hold + MusicClip.duckRamp])
        }
        return times
            .filter { $0 >= span.start && $0 <= span.end }
            .sorted()
            .map { time in
                Point(time: time, volume: volume * fade(at: time, span: span, fades: fades) * duck(at: time, spans: ducks))
            }
    }

    /// The stretches the music is fully down for: speech joined across short gaps.
    static func duckSpans(_ speech: [TimeSpan]) -> [TimeSpan] {
        var result: [TimeSpan] = []
        for span in TimeSpan.merged(speech) {
            if let last = result.last, span.start - MusicClip.duckRamp < last.end + hold + MusicClip.duckRamp + gap {
                result[result.count - 1].end = max(last.end, span.end)
            } else {
                result.append(span)
            }
        }
        return result
    }

    /// How far down the music is at `time`: 1 in the clear, `MusicClip.duckedLevel` under speech.
    static func duck(at time: TimeInterval, spans: [TimeSpan]) -> Double {
        let low = MusicClip.duckedLevel, ramp = MusicClip.duckRamp
        var level = 1.0
        for span in spans {
            let here: Double
            if time <= span.start - ramp || time >= span.end + hold + ramp {
                here = 1
            } else if time < span.start {
                here = 1 - (1 - low) * (time - (span.start - ramp)) / ramp
            } else if time <= span.end + hold {
                here = low
            } else {
                here = low + (1 - low) * (time - span.end - hold) / ramp
            }
            level = min(level, here)
        }
        return level
    }

    // MARK: - Fades

    /// Fades that fit the clip: when both are longer than it, each gets its share.
    private static func fadeLengths(span: TimeSpan, fadeIn: TimeInterval, fadeOut: TimeInterval) -> (in: TimeInterval, out: TimeInterval) {
        let fadeIn = max(0, fadeIn), fadeOut = max(0, fadeOut)
        let total = fadeIn + fadeOut
        guard total > span.duration, total > 0 else { return (fadeIn, fadeOut) }
        let share = span.duration / total
        return (fadeIn * share, fadeOut * share)
    }

    private static func fade(at time: TimeInterval, span: TimeSpan, fades: (in: TimeInterval, out: TimeInterval)) -> Double {
        var level = 1.0
        if fades.in > 0, time < span.start + fades.in { level = min(level, max(0, time - span.start) / fades.in) }
        if fades.out > 0, time > span.end - fades.out { level = min(level, max(0, span.end - time) / fades.out) }
        return level
    }
}
