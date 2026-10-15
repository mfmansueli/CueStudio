//
//  RevisionChoice.swift
//  Cue Studio
//

import Foundation

/// Which of two drafts of one script the creator gets when the first broke what they asked and was written again (`VoiceCheckedWriting`). The
/// second must be better where it was asked to be (what it breaks is less serious, `VoiceViolation.Kind.severity`, not merely fewer or as many),
/// and must not have lost on the way what made the first one worth having: the opening line the creator picked, the angle, the content, its ending,
/// and its freedom from repetition. Pure, so every case is tested without the model.
nonisolated enum RevisionChoice {
    enum Verdict: String, Hashable, Sendable {
        /// The second draft is the one shown.
        case revision
        /// What it breaks is no less serious.
        case notBetter
        /// It no longer opens with the line the creator picked.
        case lostOpening
        /// It covers much less of the angle (or the idea).
        case lostAngle
        /// It says much less.
        case lostContent
        /// It stops mid-sentence where the first did not.
        case cutShort
        /// It repeats itself more.
        case moreRepetitive

        var takesRevision: Bool { self == .revision }
    }

    /// The share of the angle's words a revision may lose.
    static let coverageLoss = 0.2
    /// The share of the spoken words a revision must keep.
    static let keptWords = 0.75
    /// How much more of its three-word runs a revision may repeat.
    static let repetitionGain = 0.08

    static func verdict(original: DraftAssessment, revision: DraftAssessment) -> Verdict {
        guard revision.severity < original.severity else { return .notBetter }
        if original.opensWithBrief == true, revision.opensWithBrief == false { return .lostOpening }
        if let before = original.coverage, let after = revision.coverage, after < before - coverageLoss { return .lostAngle }
        if Double(revision.spokenWords) < Double(original.spokenWords) * keptWords { return .lostContent }
        if revision.isCut, !original.isCut { return .cutShort }
        if revision.repetition > original.repetition + repetitionGain { return .moreRepetitive }
        return .revision
    }
}
