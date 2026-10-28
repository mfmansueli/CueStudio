import Foundation
import FoundationModels

/// Cloud-only guided development. Spoken substance is generated in separate fields rather than
/// relying on a duration quota to make a one-line answer into a useful script.
@Generable
nonisolated struct PCCScriptDraft {
    @Guide(description: "A short specific title in the selected script language.")
    var title: String
    @Guide(description: "Spoken opening on the actual subject. Use the supplied inspiration opening when relevant. May be empty for a brief factual correction. Never invent a personal experience.")
    var opening: String
    @Guide(description: "All distinct points needed to fulfill the current request, in speaking order. Each point must address a different decision or mechanism, not another version of the same action. If three steps were requested, include exactly three developed points. For a simple announcement, include only the supplied information, without invented context.")
    var points: [Point]
    @Guide(description: "An earned spoken conclusion, or empty if the answer is already complete. No automatic engagement CTA, new facts, promises or repeated summary.")
    var ending: String
    @Guide(description: "Whether the script makes externally checkable factual claims.")
    var statesFacts: Bool

    @Generable
    nonisolated struct Point {
        @Guide(description: "Short internal label describing this distinct point, not spoken.")
        var label: String
        @Guide(description: "The actual spoken point or action. Preserve supplied facts and who did what. Match the requested perspective; general advice is not a claim that the creator personally tried it.")
        var statement: String
        @Guide(description: "Spoken explanation of why or how this point works, with connected, concrete reasoning. Several short sentences may develop one point. Empty only when explanation would invent facts or is inappropriate to the requested brief announcement, correction or scene.")
        var explanation: String
        @Guide(description: "Spoken practical application: what to look for, a relevant tradeoff, or a clearly hypothetical example. When the request asks for a check, explain an observable check and what to adjust. Add new useful substance, not a paraphrase. Empty if irrelevant or unsupported; never invent a personal test, universal diagnostic rule, number, price or commitment.")
        var application: String
    }

    var scriptDraft: ScriptDraft {
        let development = points.map { point in
            ScriptDraft.Block(label: point.label, text: Self.join([point.statement, point.explanation, point.application]))
        }
        return ScriptDraft(
            title: title,
            blocks: [ScriptDraft.Block(label: "Opening", text: opening)] + development + [ScriptDraft.Block(label: "Ending", text: ending)],
            statesFacts: statesFacts
        )
    }

    private static func join(_ parts: [String]) -> String {
        parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " ")
    }
}
