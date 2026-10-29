#if DEBUG
import Foundation
import FoundationModels

/// Evaluation only: asks for connected prose without per-point explanation/application fields.
@Generable
nonisolated struct PCCProseDraft {
    @Guide(description: "Choose conciseStatement for a brief factual notice or correction; otherwise developed. An explicitly fictional scene is creative material, not a claim about the creator's real past.")
    var intent: PCCScriptIntent
    @Guide(description: "A short specific title in the selected script language.")
    var title: String
    @Guide(description: "The complete spoken script, arranged freely in connected paragraphs. Fulfill the current request, chosen format and inspiration angle/opening. Build reasoning with concrete examples and useful consequences rather than a list of slogans. For explicit fiction, show the scene through actions and spoken details rather than explaining what the tension is. A brief factual notice contains only supplied information. Preserve exact wording and agency. No headings, field names, editorial explanations or automatic CTA. No duration quota.")
    var text: String
    @Guide(description: "Whether the script makes externally checkable factual claims.")
    var statesFacts: Bool

    var scriptDraft: ScriptDraft {
        ScriptDraft(title: title, blocks: [.init(label: "Script", text: text)], statesFacts: statesFacts)
    }
}
#endif
