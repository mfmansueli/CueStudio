import Foundation

/// State shared by streamed planning/writing and their watchdog during one attempt.
@MainActor
struct ScriptDraftAttempt {
    let progress: GenerationProgress
    let meter: WritingProgressMeter?
    let budget: AIGenerationBudget
}
