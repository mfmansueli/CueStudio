//
//  MusicEnvelope.swift
//  Cue Studio
//

import Foundation

/// How loud a music clip is over time: its volume, its fade in and out, and, when it ducks, lower
/// while someone speaks. Going down starts a moment before the voice (the edit is known ahead) and
/// coming back waits a moment after it, so nothing is cut off; stretches of speech close together
/// stay down in between rather than pumping. Pure, so it is tested with made-up spans.
///
/// A clip with `MusicClip.duck` goes down by its depth and moves along an S-curve in decibels, the way loudness is heard, with
/// no corner where a ramp starts or ends; how long a pause has to be before it comes back is its `MusicDuckPauses`. A clip saved
/// before has none and keeps the first way (`Timing.legacy`): a quarter of its volume, straight ramps of a quarter second.
nonisolated enum MusicEnvelope {
    /// How long the music stays down after the voice stops before coming back (the first way).
    static let hold: TimeInterval = 0.2
    /// Gaps shorter than this between two stretches of speech stay down (the first way).
    static let gap: TimeInterval = 0.3
    /// Points a smooth ramp is drawn with: the sound's volume moves in straight lines between points, so enough of them follow
    /// the curve without a step being heard.
    static let smoothSteps = 8

    struct Point: Hashable, Sendable {
        var time: TimeInterval
        var volume: Double
    }

    /// When the music goes down and comes back around speech.
    struct Timing: Hashable, Sendable {
        /// Seconds before the voice it starts going down, so it's down when the first word starts.
        var lead: TimeInterval
        /// Seconds it stays down after the voice stops.
        var hold: TimeInterval
        /// Seconds it takes to come back.
        var release: TimeInterval
        /// Quiet shorter than this, on top of what going down and coming back take, stays down.
        var bridge: TimeInterval
        /// Moves along an S-curve in decibels, not a straight line of volume.
        var isSmooth: Bool

        /// Clips saved before `MusicClip.duck`: as they always sounded.
        static let legacy = Timing(lead: MusicClip.duckRamp, hold: MusicEnvelope.hold, release: MusicClip.duckRamp, bridge: MusicEnvelope.gap, isSmooth: false)
        /// Stays low in pauses: any quiet up to about 3.3 s (a breath, a thought, a beat between sentences) keeps it down; it
        /// comes back over a second, unhurried.
        static let staysLow = Timing(lead: 0.4, hold: 0.4, release: 1.0, bridge: 1.5, isSmooth: true)
        /// Comes back up in pauses longer than about 1.15 s, quickly enough to be heard before the next sentence.
        static let comesBack = Timing(lead: 0.25, hold: 0.1, release: 0.4, bridge: 0.4, isSmooth: true)

        static func of(_ duck: MusicDuck?) -> Timing {
            switch duck?.pauses {
            case nil: .legacy
            case .staysLow?: .staysLow
            case .comesBack?: .comesBack
            }
        }

        /// The quiet between two stretches of speech that the music stays down through.
        var bridgedQuiet: TimeInterval { hold + release + lead + bridge }
    }

    /// The volume at each moment it changes, from where the music starts (`span`, the same
    /// seconds as `speech`) to where it ends; straight lines in between. `duck` nil goes down the first way.
    static func points(
        span: TimeSpan, volume: Double, fadeIn: TimeInterval, fadeOut: TimeInterval, speech: [TimeSpan]?, duck: MusicDuck? = nil
    ) -> [Point] {
        guard span.duration > 0 else { return [] }
        let timing = Timing.of(duck)
        let low = duck?.level ?? MusicClip.duckedLevel
        let ducks = duckSpans(speech ?? [], timing: timing)
        let fades = fadeLengths(span: span, fadeIn: fadeIn, fadeOut: fadeOut)
        var times: Set<TimeInterval> = [span.start, span.end, span.start + fades.in, span.end - fades.out]
        for duck in ducks {
            let down = TimeSpan(start: duck.start - timing.lead, end: duck.start)
            let back = TimeSpan(start: duck.end + timing.hold, end: duck.end + timing.hold + timing.release)
            for ramp in [down, back] {
                times.formUnion([ramp.start, ramp.end])
                guard timing.isSmooth else { continue }
                for step in 1..<smoothSteps { times.insert(ramp.start + ramp.duration * Double(step) / Double(smoothSteps)) }
            }
        }
        return times
            .filter { $0 >= span.start && $0 <= span.end }
            .sorted()
            .map { time in
                Point(time: time, volume: volume * fade(at: time, span: span, fades: fades) * self.duck(at: time, spans: ducks, low: low, timing: timing))
            }
    }

    /// The stretches the music is fully down for: speech joined where the quiet between is shorter than `timing` bridges.
    static func duckSpans(_ speech: [TimeSpan], timing: Timing) -> [TimeSpan] {
        var result: [TimeSpan] = []
        for span in TimeSpan.merged(speech) {
            if let last = result.last, span.start - last.end < timing.bridgedQuiet {
                result[result.count - 1].end = max(last.end, span.end)
            } else {
                result.append(span)
            }
        }
        return result
    }

    /// How far down the music is at `time`: 1 in the clear, `low` under speech, and on the way between.
    static func duck(at time: TimeInterval, spans: [TimeSpan], low: Double, timing: Timing) -> Double {
        var level = 1.0
        for span in spans {
            let here: Double
            if time <= span.start - timing.lead || time >= span.end + timing.hold + timing.release {
                here = 1
            } else if time < span.start {
                here = ramp(from: 1, to: low, progress: (time - (span.start - timing.lead)) / timing.lead, smooth: timing.isSmooth)
            } else if time <= span.end + timing.hold {
                here = low
            } else {
                here = ramp(from: low, to: 1, progress: (time - span.end - timing.hold) / timing.release, smooth: timing.isSmooth)
            }
            level = min(level, here)
        }
        return level
    }

    /// From one level to another: a straight line of volume, or (`smooth`) a straight line in decibels eased at both ends, so
    /// the change is even to the ear and starts and stops without a corner.
    static func ramp(from: Double, to: Double, progress: Double, smooth: Bool) -> Double {
        let share = min(max(progress, 0), 1)
        guard smooth, from > 0, to > 0 else { return from + (to - from) * share }
        let eased = share * share * (3 - 2 * share)
        return from * pow(to / from, eased)
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
