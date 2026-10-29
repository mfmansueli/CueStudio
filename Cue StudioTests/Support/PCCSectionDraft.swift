import FoundationModels

/// Evaluation-only semantic slots: each requested point must explain the action and its check.
@Generable
nonisolated struct PCCSectionDraft {
    @Guide(description: "Explain this action and why it helps in at least four complete spoken sentences, in the selected language and voice. No headings or extra points.")
    var actionAndReason: String
    @Guide(description: "Explain how to check this same action and what to adjust if needed, in at least four complete spoken sentences. Do not repeat the explanation or invent a personal test or a universal diagnostic rule.")
    var checkAndAdjustment: String
}
