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

    // MARK: - Curves

    /// Light arriving: fast, then a long settle (`cubic-bezier(.16,1,.3,1)`).
    static func light(duration: Double) -> Animation {
        .timingCurve(0.16, 1, 0.3, 1, duration: duration)
    }

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
