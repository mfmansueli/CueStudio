//
//  CueSliderSpec.swift
//  Cue Studio
//

import Foundation

/// The range, step and default of each slider in the app (v29, `02-Tokens.md` §6): minimums and
/// maximums that make sense for what is being changed. One place, so a screen never invents its own
/// and a test can hold the table to the design. Values are in the units the slider shows (wpm, %, pt);
/// stepped controls (S/M/L/XL, Off/Light/Strong) count steps from 0.
nonisolated struct CueSliderSpec: Equatable, Sendable {
    let range: ClosedRange<Double>
    /// Nil for a smooth control.
    let step: Double?
    let defaultValue: Double

    init(_ range: ClosedRange<Double>, step: Double? = nil, default defaultValue: Double) {
        self.range = range
        self.step = step
        self.defaultValue = defaultValue
    }

    /// The stepped control with `count` positions (0 ... count − 1), one step apart.
    static func steps(_ count: Int, default defaultValue: Int) -> CueSliderSpec {
        CueSliderSpec(0...Double(count - 1), step: 1, default: Double(defaultValue))
    }

    // MARK: - Settings › Prompter and the recorder (Steady only)

    /// Words a minute: 80–220, in 5s, 150 is the natural pace.
    static let speed = CueSliderSpec(80...220, step: 5, default: 150)
    /// Small · Medium · Large · Extra large: 24 / 30 / 36 / 44 pt, Large by default.
    static let textSize = steps(4, default: 2)
    /// Percent of the screen's height, from the camera (10%) to the middle (50%).
    static let readingLine = CueSliderSpec(10...50, step: 1, default: 22)
    /// Points on each side of the text.
    static let margins = CueSliderSpec(8...40, step: 2, default: 20)
    /// Off · 3 s · 5 s · 10 s.
    static let countdown = steps(4, default: 1)
    /// Off · Soft · Full.
    static let starrySky = steps(3, default: 2)

    // MARK: - Editor

    /// Text size on the video, in points.
    static let textPoints = CueSliderSpec(24...120, step: 2, default: 64)
    /// Glow of a text, in percent.
    static let textGlow = CueSliderSpec(0...100, step: 5, default: 35)
    /// S · M · L · XL, Large by default.
    static let captionSize = steps(4, default: 2)
    /// Your voice, in percent: 100% is as recorded.
    static let voice = CueSliderSpec(0...200, step: 5, default: 100)
    /// Music, in percent: it ducks under your voice.
    static let music = CueSliderSpec(0...100, step: 5, default: 20)
    /// Off · Light · Strong, Light by default.
    static let cleanUpVoice = steps(3, default: 1)
    /// How fast a clip plays.
    static let clipSpeed = CueSliderSpec(0.5...3, step: 0.1, default: 1)
    /// How much of a filter shows, in percent.
    static let filterIntensity = CueSliderSpec(0...100, step: 1, default: 70)
}
