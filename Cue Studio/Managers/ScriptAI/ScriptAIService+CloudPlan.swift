#if DEBUG
import Foundation
import FoundationModels

extension ScriptAIService {
    func planCloudDraft(
        _ request: ScriptRequest, progress: GenerationProgress
    ) async throws -> (plan: PCCScriptPlan, firstResponse: Duration?) {
        let instructions = ScriptPromptBuilder.instructions(for: request)
            + "\nFor this planning stage, return only the requested editorial plan schema, not a script. Choose substance before wording: an authored angle, complete requirement coverage, distinct reasoning beats and one useful example. Voice affects delivery, not the topic. Be specific enough that a writer can develop the argument without repeating it."
        let session = session(on: .privateCloud, instructions: instructions)
        let prompt = ScriptPromptBuilder.prompt(for: request)
            + "\nThis call plans the draft. Return the editorial plan, not spoken blocks. Preserve all current-request requirements for the writing stage."
        let started = ContinuousClock.now
        var firstResponse: Duration?
        var latest: GeneratedContent?
        let options = GenerationOptions(maximumResponseTokens: 1_536)
        let context = ContextOptions(includeSchemaInPrompt: true, reasoningLevel: cloudReasoning)
        for try await snapshot in session.streamResponse(to: prompt, generating: PCCScriptPlan.self, options: options, contextOptions: context) {
            if firstResponse == nil { firstResponse = started.duration(to: .now) }
            progress.noteProgress()
            latest = snapshot.rawContent
        }
        try Task.checkCancellation()
        guard let latest else { throw ScriptAIError.emptyResponse }
        return (try PCCScriptPlan(latest), firstResponse)
    }
}

#endif
