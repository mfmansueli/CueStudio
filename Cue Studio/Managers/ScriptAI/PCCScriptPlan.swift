#if DEBUG
import Foundation
import FoundationModels

/// A small editorial plan separates deciding what to say from phrasing it in the creator's voice.
/// It is never displayed or saved as spoken content.
@Generable
nonisolated struct PCCScriptPlan {
    @Guide(description: "One specific, useful point of view that answers this request. Propose an authored stance when appropriate, not a generic promise to explain.")
    var angle: String
    @Guide(description: "The creator's actual requirements: requested number of points, benefits and limits, perspective, supplied facts, exact wording and ending restrictions. Do not invent requirements from profile topics.")
    var requirements: [String]
    @Guide(description: "Distinct speaking beats that develop the argument or requested actions. For each, specify the concrete insight, its reasoning and useful consequence or tradeoff. Honor an explicit point count. A single argument needs a coherent development, not several paraphrases. Brief notices need only their supplied information.")
    var beats: [String]
    @Guide(description: "One tangible illustrative example or sustained analogy that makes the reasoning understandable. Empty if inappropriate to the request. This may be proposed creative material, not a claim about a real past testimonial. Avoid a chain of unrelated metaphors.")
    var example: String
    @Guide(description: "True only for a factual announcement, correction or other request whose complete answer should be brief, without invented development.")
    var briefOnly: Bool

    var writingDirection: String {
        let coverage = requirements.map { "- \($0)" }.joined(separator: "\n")
        let development = beats.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let depth = briefOnly
            ? "This is a brief notice: preserve the supplied information and stop."
            : "Develop each beat through connected spoken reasoning and useful application. This is material for the creator to reshape, not an outline. Follow through on the argument before moving to the next beat."
        return """
        Internal editorial plan, never spoken or explained to the viewer:
        Point of view: \(angle)
        Requirements to fulfill:
        \(coverage)
        Speaking development:
        \(development)
        Illustrative material, use only where it helps: \(example)
        \(depth)
        Write the complete spoken draft, not this plan. Keep the selected voice, language and exact wording.
        """
    }
}

#endif
