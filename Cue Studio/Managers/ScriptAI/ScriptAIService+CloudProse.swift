#if DEBUG
import Foundation
import FoundationModels

extension ScriptAIService {
    /// Uses the same attempt, watchdog, token allowance and output checks as the normal cloud draft.
    func streamCloudProse(
        _ request: ScriptRequest, since begin: ContinuousClock.Instant, insistsOnLanguage: Bool,
        correcting violations: [VoiceViolation], attempt: ScriptDraftAttempt
    ) async throws -> GeneratedScript {
        let instructions = ScriptPromptBuilder.instructions(for: request, insistsOnLanguage: insistsOnLanguage)
            + "\nFor this evaluation, return a complete spoken script as connected prose. Choose paragraph structure to serve the request. Do not expose schema labels. The creator's request determines what happens and what is argued."
        let session = session(on: .privateCloud, instructions: instructions)
        var prompt = ScriptPromptBuilder.prompt(for: request)
        if !violations.isEmpty { prompt += "\n" + ScriptPromptBuilder.correctionNote(for: violations) }
        prompt += ScriptVerbatimSlots(phrases: request.requiredPhrases).instruction
        let started = ContinuousClock.now
        var firstResponse: Duration?
        var counted: ContinuousClock.Instant?
        var latest: GeneratedContent?
        let options = GenerationOptions(maximumResponseTokens: Self.responseTokens(for: request, on: .privateCloud))
        let context = ContextOptions(includeSchemaInPrompt: true, reasoningLevel: cloudReasoning)
        attempt.meter?.record(.drafting)
        for try await snapshot in session.streamResponse(to: prompt, generating: PCCProseDraft.self, options: options, contextOptions: context) {
            if firstResponse == nil { firstResponse = started.duration(to: .now) }
            attempt.progress.noteProgress()
            latest = snapshot.rawContent
            if let meter = attempt.meter, counted.map({ $0.duration(to: .now) >= .milliseconds(250) }) ?? true {
                counted = .now
                meter.record(.wrote(words: ReadTime.wordCount(in: snapshot.content.text ?? "")))
            }
        }
        try Task.checkCancellation()
        guard let latest else { throw ScriptAIError.emptyResponse }
        let prose = try PCCProseDraft(latest)
        var result = try finishedDraft(prose.scriptDraft, request: request, model: .privateCloud, timings: GenerationTimings(
            prepare: begin.duration(to: started), firstResponse: firstResponse, generation: started.duration(to: .now)
        ))
        result.isConciseStatement = prose.intent == .conciseStatement
        result.cloudDraftIntent = prose.intent.measurementName
        return result
    }

    func editorialEvaluationRequest(_ request: ScriptRequest, on route: AIModelRoute) -> ScriptRequest {
        evaluatesDeliveryOnlyVoice ? PCCDeliveryVoice.prepare(request, on: route) : request
    }
}
#endif
