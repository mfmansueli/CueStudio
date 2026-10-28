import Foundation
import FoundationModels

/// Cloud-only guided development. Spoken substance is generated in separate fields rather than
/// relying on a duration quota to make a one-line answer into a useful script.
@Generable
nonisolated struct PCCScriptDraft {
    @Guide(description: "Choose conciseStatement for a short factual notice, serious correction or brief supplied-event story that explicitly forbids invented follow-up. Choose fictionalScene only for an explicitly fictional scene or imagined POV: show the events, not advice on filming them. A factual anecdote alone is not permission to fictionalize it. Choose developed for teaching, explaining, comparing or arguing. Do not expand a brief correction merely because drafts can be generous.")
    var intent: PCCScriptIntent = .developed
    @Guide(description: "A short specific title in the selected script language.")
    var title: String
    @Guide(description: "Spoken opening on the actual subject. Use the supplied inspiration opening when relevant. For fictionalScene, start inside the action rather than introducing or explaining the story. May be empty for a brief factual correction. First-person opinions and illustrative examples are welcome; keep real biographical claims grounded.")
    var opening: String
    @Guide(description: "Empty for fictionalScene; use sceneBeats instead. For developed: distinct points addressing different decisions or mechanisms, not near-duplicates. If three steps were requested, include exactly three developed points. For conciseStatement: only the supplied information.")
    var points: [Point]
    @Guide(description: "Empty unless intent is fictionalScene. A connected sequence of spoken moments and responses: establish the situation, let an obstacle interrupt it, show attempts or reactions, and earn an everyday ending. Develop the action instead of explaining how a scene works. Use only as many beats as the story needs, with no duration quota. Only an explicitly fictional request permits invented events; supplied real stories retain their facts and limits.")
    var sceneBeats: [PCCSceneBeat] = []
    @Guide(description: "Empty for conciseStatement. For fictionalScene, the final concrete action or moment, not a moral, explanation or invitation to recreate the scene. For developed, an earned spoken conclusion or empty if complete. No automatic engagement CTA, new facts, promises or repeated summary.")
    var ending: String
    @Guide(description: "Whether the script makes externally checkable factual claims.")
    var statesFacts: Bool

    @Generable
    nonisolated struct Point {
        @Guide(description: "Short internal label describing this distinct point, not spoken.")
        var label: String
        @Guide(description: "For developed, the actual spoken point or action. For fictionalScene, a complete spoken story beat: show what happens, a concrete detail and the narrator's reaction where useful. Several connected sentences may build one beat. Keep the chosen grammatical narrator consistent; do not step outside the scene to give advice or explain why it is tense. Preserve supplied facts and who did what. Proposed opinions and preferences are welcome in developed drafts.")
        var statement: String
        @Guide(description: "Empty for conciseStatement and fictionalScene. For developed scripts, develop why or how this point works through connected spoken reasoning, not just a definition. Explain a useful consequence or tradeoff before moving on. Use the creator's opinions, analogies and vocabulary to give the explanation personality. Several short sentences build one substantial paragraph. Empty only when explanation would invent facts or is inappropriate to the requested brief announcement, correction or scene.")
        var explanation: String
        @Guide(description: "Empty for conciseStatement and fictionalScene. For developed scripts, spoken practical application: what to look for, a relevant tradeoff, or a clearly hypothetical example. When the request asks for a check, explain an observable check and what to adjust. Develop a miniature everyday example or useful check where relevant, giving the creator material to reshape. Add new useful substance, not a paraphrase. Empty if irrelevant or unsupported; never invent a personal test, universal diagnostic rule, number, price or commitment.")
        var application: String
    }

    var scriptDraft: ScriptDraft {
        let development: [ScriptDraft.Block]
        if intent == .fictionalScene {
            development = sceneBeats.map { beat in ScriptDraft.Block(label: "Scene", text: Self.join([beat.moment, beat.response])) }
        } else {
            development = points.map { point in
                let spoken = intent == .developed ? [point.statement, point.explanation, point.application] : [point.statement]
                return ScriptDraft.Block(label: point.label, text: Self.join(spoken))
            }
        }
        return ScriptDraft(
            title: title,
            blocks: [ScriptDraft.Block(label: "Opening", text: opening)] + development + [ScriptDraft.Block(label: "Ending", text: intent == .conciseStatement ? "" : ending)],
            statesFacts: statesFacts
        )
    }

    private static func join(_ parts: [String]) -> String {
        parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " ")
    }
}
