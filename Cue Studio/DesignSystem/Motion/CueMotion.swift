//
//  CueMotion.swift
//  Cue Studio
//

import SwiftUI

/// The motion language of v27: short interactions (120–400 ms) with springs for physical things (the slider's
/// thumb, the tab capsule, cards) and decelerating curves for light, and longer durations only for the story moments
/// (onboarding, send-off, milestones). Every value here is from `DESIGN-SPEC.md` §7.
///
/// With Reduce Motion on, the sky, the orbits, the comets and the glows stop and state changes become
/// fades: read `@Environment(\.accessibilityReduceMotion)` and use `CueMotion.animation(_:reduced:)`.
nonisolated enum CueMotion {
    // MARK: - Durations (seconds)

    enum Duration {
        static let tap = 0.12
        static let standard = 0.35
        static let chapterOut = 0.35
        static let chapterIn = 0.45
        /// One line of the prompter gliding up to the horizon.
        static let voiceGlide = 0.45
        /// A word lighting as it is spoken.
        static let wordLight = 0.12
        /// A word of the AI's script arriving.
        static let wordFromLight = 0.3
        /// The pause between those words.
        static let wordStagger = 0.16
        static let ignite = 0.65
        static let igniteWaves = 1.0
        static let arrival = 1.0
        static let foldIntoLight = 0.55
        static let cometMin = 1.25
        static let cometMax = 2.0
        /// The ring of 12 stars: three seconds, one count each.
        static let countdownStep = 1.0
        /// The AI aura turning once.
        static let auraTurn = 2.8
        /// The reading line breathing.
        static let horizonBreath = 2.4
        static let shineSweep = 0.8
    }

    // MARK: - Springs

    /// A slider's thumb snapping to a step.
    static let sliderSnap = Animation.spring(response: 0.28, dampingFraction: 0.72)
    /// Cards, sheets and rows.
    static let card = Animation.smooth(duration: 0.3)
    /// Find inspiration's card turning to the next idea: a soft spring, so the new card arrives and settles instead of stopping.
    static let inspirationTurn = Animation.spring(response: 0.46, dampingFraction: 0.84)
    /// A line of the new idea rising into place (each a beat after the one above, `inspirationLineStagger`).
    static let inspirationLine = light(duration: 0.5)
    static let inspirationLineStagger = 0.06
    /// The light crossing the new idea's card once.
    static let inspirationSweep = Animation.timingCurve(0.45, 0, 0.25, 1, duration: 0.8)

    // MARK: - Curves

    /// Light arriving: fast, then a long settle (`cubic-bezier(.16,1,.3,1)`).
    static func light(duration: Double) -> Animation {
        .timingCurve(0.16, 1, 0.3, 1, duration: duration)
    }

    /// The Scripts dock's first row folding away and coming back (09 §6: 0.28 s, `cubic-bezier(.2,.8,.2,1)`).
    static let dockFold = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.28)
    /// The My Cue Voice tip coming in (09 §3: 0.40 s, `cubic-bezier(.2,.9,.25,1)`).
    static let tipEnter = Animation.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.4)
    /// The list dimming while the dock's field has the keyboard (09 §6: 0.25 s, ease-out).
    static let dockDim = Animation.easeOut(duration: 0.25)

    /// A finger landing on a button: it sinks at once, with no bounce (the answer has to be there before the finger settles).
    static let pressIn = Animation.spring(response: 0.16, dampingFraction: 0.9)
    /// The finger lifting: the button comes back a little slower and settles past its place, so the release reads as a release.
    static let pressRelease = Animation.spring(response: 0.34, dampingFraction: 0.62)

    /// A chapter of the first flight leaving: short and accelerating, so it is out of the way before the next one arrives.
    static let chapterExit = Animation.easeIn(duration: 0.22)
    /// The next chapter arriving, a beat after the last one starts to leave (one thing moves at a time): light's curve, fast then a long settle.
    static let chapterEnter = light(duration: 0.55).delay(0.1)
    /// The night's haze moving to the next chapter's: slower than the chapter, as a far thing is (the background lags the foreground).
    static let hazeShift = Animation.easeInOut(duration: 0.8)
    /// An SF Symbol swapping for another (`symbolSwap`): quick, no bounce.
    static let symbolSwap = Animation.snappy(duration: 0.22)
    /// A full-screen story coming over the screen (`StoryCover`): light's curve, and going, quicker.
    static let storyIn = light(duration: 0.35)
    static let storyOut = Animation.easeIn(duration: 0.25)
    /// A story skipped with a tap: everything eases to its final place instead of jumping there.
    static let skipSettle = Animation.easeOut(duration: 0.3)
    /// The sky drifting up a little with each chapter: slower still, the farthest layer of the three.
    static let skyShift = Animation.timingCurve(0.45, 0, 0.25, 1, duration: 0.95)

    /// The prompter's glide to the next line (`cubic-bezier(.45,0,.25,1)`).
    static let glide = Animation.timingCurve(0.45, 0, 0.25, 1, duration: Duration.voiceGlide)

    /// A comet or the fold into light: slow start, fast middle, soft landing.
    static func travel(duration: Double) -> Animation {
        .timingCurve(0.5, 0, 0.3, 1, duration: duration)
    }

    /// Something igniting: overshoot, then rest (`cubic-bezier(.3,1.3,.5,1)`).
    static func overshoot(duration: Double) -> Animation {
        .timingCurve(0.3, 1.3, 0.5, 1, duration: duration)
    }

    /// The countdown's numbers (`cubic-bezier(.2,.9,.25,1)`).
    static func number(duration: Double) -> Animation {
        .timingCurve(0.2, 0.9, 0.25, 1, duration: duration)
    }

    /// Reduce Motion: a plain fade.
    static let fade = Animation.easeInOut(duration: 0.2)

    /// `animation` normally, a fade when Reduce Motion is on.
    static func animation(_ animation: Animation, reduced: Bool) -> Animation {
        reduced ? fade : animation
    }
}
