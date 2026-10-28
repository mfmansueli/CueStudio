#if DEBUG
import Foundation

/// Mechanical regression guards, not an editorial quality score or factual verification.
nonisolated enum EditorialRevisionChoice {
    static func accepts(original: DraftAssessment, revision: DraftAssessment) -> Bool {
        guard revision.severity <= original.severity else { return false }
        if original.opensWithBrief == true, revision.opensWithBrief == false { return false }
        if let before = original.coverage, let after = revision.coverage, after < before - RevisionChoice.coverageLoss { return false }
        if Double(revision.spokenWords) < Double(original.spokenWords) * RevisionChoice.keptWords { return false }
        if revision.isCut, !original.isCut { return false }
        if revision.repetition > original.repetition + RevisionChoice.repetitionGain { return false }
        return true
    }
}
#endif
