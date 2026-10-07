//
//  VoiceViolation.swift
//  Cue Studio
//

import Foundation

/// One way a written script breaks what the creator asked for (`VoiceConstraintChecker`). Never shown to the creator and never blocks them: it
/// is what the one new attempt is told, and what is counted (the kind, never the text).
nonisolated struct VoiceViolation: Hashable, Sendable {
    enum Kind: String, CaseIterable, Hashable, Sendable {
        /// A word or phrase of something the creator asked never to write.
        case avoided
        /// "I" in a script of "we", or "we" in a script of "I".
        case pronoun
        /// The creator's catchphrase opens a script whose opening they chose another way.
        case catchphraseFirst
        /// The name of an opening style ("Question.") written as the first words.
        case styleName
        /// An emoji, when the creator asked for none.
        case emoji
        /// Far fewer words than were asked for.
        case tooShort
        /// Sentences much longer or shorter than the creator's own (measured from what they imported). Only counted, never a reason to write again.
        case sentenceLength
        /// Exclamation marks in the script of a creator who almost never uses them. Only counted.
        case exclamation
    }

    let kind: Kind

    /// A rule that is counted and told to a second attempt that is happening anyway, but never makes one: the habits measured from a creator's
    /// writing are a tendency, not something they asked for, and a script that is too short is lengthened block by block (`ScriptExpansion`), which the
    /// model does and a second whole attempt does not (measured on an iPhone 15 Pro: it wrote 54 words for 150, then 64 to 86).
    var isSoft: Bool { kind == .sentenceLength || kind == .exclamation || kind == .tooShort }
    /// What the model is told, in English: the sentence of the correction.
    let detail: String
}
