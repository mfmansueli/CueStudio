//
//  CaptionMarkup.swift
//  Cue Studio
//

import Foundation

/// What one drawing of a caption line shows besides its words (`CaptionCollectionRenderer.image`): the words the creator
/// marked for emphasis, and, while the line plays with motion (`CaptionMotion`), the word being said and how it stands out,
/// the words not said yet, a popped word's size and the sliding box on its way. Words are counted as the line's words
/// (`CaptionText.words(in:)`). Every state of a line lays out the same: only ink, a box or a drawn-over pop changes.
nonisolated struct CaptionMarkup: Hashable, Sendable {
    /// Marked for emphasis (`CaptionCue.emphasis`): bigger and in the emphasis color, in every state.
    var emphasized: Set<Int> = []
    /// The first word being said, and how many from it are (the whole line, for a line lit whole).
    var lit: Int?
    var litCount = 1
    var spoken: CaptionSpokenHighlight = .none
    /// Words after this one aren't drawn yet (Reveal › Word by word).
    var revealedThrough: Int?
    /// How big the popped word is drawn in this state (1: its size).
    var popScale = 1.0
    /// The sliding box coming from this word to `lit`, `glideProgress` of the way.
    var glideFrom: Int?
    var glideProgress = 1.0

    /// Draws something over the words besides the marks.
    var playsWords: Bool { lit != nil || revealedThrough != nil }
}
