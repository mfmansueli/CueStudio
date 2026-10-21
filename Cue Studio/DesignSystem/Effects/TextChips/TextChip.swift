//
//  TextChip.swift
//  Cue Studio
//

import SwiftUI

/// A run of text drawn as a small rounded chip, with an SF Symbol in its leading inset when it has one (a stage cue on the script page).
/// The text stays text: whoever styles it makes room for the insets (its first and last characters carry the kern) and the chip is
/// drawn behind it, by `TextChipFragment` in a text view and by the renderer of `ArrivingText`.
///
/// `id` tells two chips side by side apart (the offset where each starts), so their runs never merge into one long chip.
nonisolated struct TextChip: Hashable, Sendable, TextAttribute {
    var id: Int
    var symbol: String?
}
