//
//  ReadingLinePercent.swift
//  Cue Studio
//

import Foundation

/// The reading line as a percentage of the screen's height (the v29 slider: 10% is by the camera, 50% is the
/// middle), converted to and from what is stored: points below the front camera (`ReadingLinePlacement`).
/// The screen is measured where the slider is, never assumed, so the line lands in the same relative place
/// on any iPhone.
nonisolated struct ReadingLinePercent: Equatable, Sendable {
    /// The screen's height in points.
    var screenHeight: Double
    /// Where the lens is, from the top of the screen (`SelfieScreenMetrics.lensY`: half the top safe area).
    var lensY: Double

    /// A typical iPhone, for the moment before the view has measured the screen.
    static let standard = ReadingLinePercent(screenHeight: 874, lensY: 31)

    /// Where a placement sits, as a percent of the screen, held to the slider's range.
    func percent(for placement: ReadingLinePlacement) -> Double {
        guard screenHeight > 0 else { return CueSliderSpec.readingLine.defaultValue }
        let offset = placement.offset ?? Double(ReadingLayout.recommendedFrontOffset)
        let percent = ((lensY + offset) / screenHeight * 100).rounded()
        return min(CueSliderSpec.readingLine.range.upperBound, max(CueSliderSpec.readingLine.range.lowerBound, percent))
    }

    /// The placement a percent of the screen means.
    func placement(forPercent percent: Double) -> ReadingLinePlacement {
        let range = CueSliderSpec.readingLine.range
        let clamped = min(range.upperBound, max(range.lowerBound, percent))
        return .offset((clamped / 100 * screenHeight - lensY).rounded())
    }
}
