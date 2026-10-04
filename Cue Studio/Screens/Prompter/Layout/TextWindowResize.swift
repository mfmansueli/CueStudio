//
//  TextWindowResize.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// What dragging the corner of the Selfie text window does: the window stays centered, so the
/// width follows the finger twice over; the height follows it too, scaled for the reading line
/// (the window's top moves with its height, see `ReadingLayout.leadFraction`). Both settle on
/// the usual widths and on whole lines of text, so a quick drag lands on tidy sizes.
nonisolated struct TextWindowResize: Equatable, Sendable {
    /// Widths the drag settles on when it comes close (fractions of the screen).
    static let widthSnaps: [Double] = [0.6, 0.75, PrompterSettings.defaultReadingWidth]
    static let widthSnapReach = 0.025
    /// How close, in points, the height has to be to a whole number of lines to settle on it.
    static let heightSnapReach: CGFloat = 8
    /// The window can't be shorter than this many lines.
    static let minimumLines = 3

    let width: Double
    let height: Double
    /// The height in lines of text, for the label and VoiceOver.
    let lines: Int

    /// The window after dragging by `translation` from where it was when the drag started.
    init(
        startWidth: Double,
        startHeight: Double,
        translation: CGSize,
        screenWidth: CGFloat,
        lineHeight: CGFloat
    ) {
        let widthRange = PrompterSettings.readingWidthRange
        var fraction = startWidth + Double(2 * translation.width / max(1, screenWidth))
        fraction = min(widthRange.upperBound, max(widthRange.lowerBound, fraction))
        if let snap = Self.widthSnaps.first(where: { abs($0 - fraction) < Self.widthSnapReach }) {
            fraction = snap
        }
        width = fraction

        let heightRange = PrompterSettings.textWindowHeightRange
        let line = max(1, lineHeight)
        let minimum = max(heightRange.lowerBound, Double(line) * Double(Self.minimumLines))
        var points = startHeight + Double(translation.height / (1 - ReadingLayout.leadFraction))
        points = min(heightRange.upperBound, max(minimum, points))
        let wholeLines = (points / Double(line)).rounded()
        if abs(points - wholeLines * Double(line)) < Double(Self.heightSnapReach) {
            points = min(heightRange.upperBound, max(minimum, wholeLines * Double(line)))
        }
        height = points
        lines = max(1, Int((points / Double(line)).rounded()))
    }

    /// The label while dragging: "WIDTH 93% · 6 LINES".
    var label: String {
        String(localized: "WIDTH \(Int((width * 100).rounded()))% · \(lines) LINES")
    }
}
