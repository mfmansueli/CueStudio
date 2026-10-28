#if DEBUG
import Foundation
import FoundationModels

/// Evaluation only. Diagnosis is generated before the revised spoken draft.
@Generable
nonisolated struct PCCEditorialReview {
    @Guide(description: "Specific weaknesses in the supplied draft relative to the actual request: missing requirements, repeated reasoning, unexplained claims, vague examples or unsupported factual precision. Empty if there is no useful edit. Do not treat first-person editorial opinions as fabricated biography.")
    var issues: [String]
    @Guide(description: "The complete improved spoken draft addressing those weaknesses. Keep the creator's position, useful details, selected opening and required wording. Develop the reasoning rather than adding synonyms, metaphors or generic motivation. No duration or word quota. Do not invent real experiences, evidence, technical certainty or promises. If no useful change is needed, preserve the original.")
    var revisedText: String
    @Guide(description: "A short specific title in the selected script language.")
    var revisedTitle: String
    @Guide(description: "Whether the revised script makes externally checkable factual claims.")
    var statesFacts: Bool
}
#endif
