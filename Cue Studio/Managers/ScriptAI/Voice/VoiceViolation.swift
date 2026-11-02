//
//  VoiceViolation.swift
//  Cue Studio
//

import Foundation

/// One way a written script breaks what the creator asked for. Sent to the bounded correction and
/// counted without its text. Voice preferences do not block delivery; missing explicit verbatim wording does.
nonisolated struct VoiceViolation: Hashable, Sendable {
    enum Kind: String, CaseIterable, Hashable, Sendable {
        /// A word or phrase of something the creator asked never to write.
        case avoided
        /// Wording explicitly requested verbatim is absent or changed.
        case requiredPhrase
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
        /// A word about the creator in the gender they didn't choose ("cansado" for Feminine, `GenderAgreementChecker`; the owner's B8).
        case agreement
        /// A result of the creator's that nobody gave ("Eu perdi 2 quilos em 7 dias", `AttributedResultDetector`; the owner's B12).
        case inventedResult

        /// How much breaking it costs the creator when two drafts are compared (`RevisionChoice`): words they asked never to say are the worst, a
        /// wrong "I" or "we", an emoji they refused or a style's name read out loud are plainly wrong, a catchphrase too early is a slip. What is only
        /// counted (the habits measured from their writing) weighs nothing, and the length is judged apart (`DraftAssessment.spokenWords`).
        var severity: Int {
            switch self {
            case .avoided, .requiredPhrase, .inventedResult: 3
            case .pronoun, .emoji, .styleName, .agreement: 2
            case .catchphraseFirst: 1
            case .tooShort, .sentenceLength, .exclamation: 0
            }
        }
    }

    let kind: Kind

    /// A rule that is counted and told to a second attempt that is happening anyway, but never makes one: the habits measured from a creator's
    /// writing are a tendency, not something they asked for, and a script that is too short is lengthened block by block (`ScriptExpansion`), which the
    /// model does and a second whole attempt does not (measured on an iPhone 15 Pro: it wrote 54 words for 150, then 64 to 86).
    var isSoft: Bool { countedOnly || kind == .sentenceLength || kind == .exclamation || kind == .tooShort }
    /// What the model is told, in English: the sentence of the correction.
    let detail: String
    /// This one is counted and told to a second attempt that happens anyway, never the reason for one (a short greeting said first:
    /// `VoiceConstraintChecker.opening`).
    var countedOnly = false
}
