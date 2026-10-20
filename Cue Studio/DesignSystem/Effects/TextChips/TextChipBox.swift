//
//  TextChipBox.swift
//  Cue Studio
//

import UIKit

/// A `TextChip` as an `NSAttributedString` attribute value (`TextChipAttribute.nsKey`), with what `TextChipFragment` needs to draw it:
/// the metrics of the text around it and its colours, resolved on the main actor by whoever styles the text. A class, compared by
/// identity, so two chips side by side never become one run.
nonisolated final class TextChipBox: NSObject, Sendable {
    let chip: TextChip
    let metrics: TextChipMetrics
    let fill: UIColor
    let rim: UIColor
    let ink: UIColor

    init(chip: TextChip, metrics: TextChipMetrics, fill: UIColor, rim: UIColor, ink: UIColor) {
        self.chip = chip
        self.metrics = metrics
        self.fill = fill
        self.rim = rim
        self.ink = ink
    }
}
