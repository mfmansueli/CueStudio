//
//  TextChipAttribute.swift
//  Cue Studio
//

import UIKit

/// Marks a run of an `AttributedString` as a `TextChip`. `Text` ignores it; `ArrivingText` reads it to draw the chip behind the run.
/// In a text view (an `NSAttributedString`) the same mark is `nsKey`, holding a `TextChipBox`.
nonisolated enum TextChipAttribute: AttributedStringKey {
    typealias Value = TextChip
    static let name = "studio.cue.textChip"

    static let nsKey = NSAttributedString.Key(name)
}
