import Foundation
import FoundationModels

extension ScriptAIService {
    /// One streamed call, sharing the existing watchdog and two-attempt correction budget.
    /// Incomplete guided content is never passed off as a completed developed script.
    func streamDevelopedCloudDraft(
        _ request: ScriptRequest, since begin: ContinuousClock.Instant, insistsOnLanguage: Bool,
        correcting violations: [VoiceViolation], progress: GenerationProgress, meter: WritingProgressMeter?
    ) async throws -> GeneratedScript {
        let clock = ContinuousClock()
        let instructions = ScriptPromptBuilder.instructions(for: request, insistsOnLanguage: insistsOnLanguage)
            + "\nEvery nonempty content field is spoken script in the selected language and voice. Each point's statement, explanation and application are consecutive parts of the same paragraph. Short sentences do not mean shallow explanations. Complete the requested reasoning; do not force extra content into a simple factual announcement. Never output editorial notes or field names."
        let session = session(on: .privateCloud, instructions: instructions)
        var prompt = ScriptPromptBuilder.prompt(for: request)
        if !violations.isEmpty { prompt += "\n" + ScriptPromptBuilder.correctionNote(for: violations) }
        prompt += ScriptVerbatimSlots(phrases: request.requiredPhrases).instruction
        let started = clock.now
        var firstResponse: Duration?
        var latest: GeneratedContent?
        var counted: ContinuousClock.Instant?
        let options = GenerationOptions(maximumResponseTokens: Self.responseTokens(for: request, on: .privateCloud))
        let context = ContextOptions(includeSchemaInPrompt: true, reasoningLevel: cloudReasoning)
        meter?.record(.drafting)
        for try await snapshot in session.streamResponse(to: prompt, generating: PCCScriptDraft.self, options: options, contextOptions: context) {
            if firstResponse == nil { firstResponse = started.duration(to: clock.now) }
            progress.noteProgress()
            latest = snapshot.rawContent
            if let meter, counted.map({ $0.duration(to: clock.now) >= .milliseconds(250) }) ?? true {
                counted = clock.now
                let parts = [snapshot.content.opening ?? ""] + (snapshot.content.points ?? []).flatMap {
                    [$0.statement ?? "", $0.explanation ?? "", $0.application ?? ""]
                } + [snapshot.content.ending ?? ""]
                meter.record(.wrote(words: ReadTime.wordCount(in: parts.joined(separator: " "))))
            }
        }
        try Task.checkCancellation()
        guard let latest else { throw ScriptAIError.emptyResponse }
        let draft = try PCCScriptDraft(latest).scriptDraft
        return try finishedDraft(draft, request: request, model: .privateCloud, timings: GenerationTimings(
            prepare: begin.duration(to: started), firstResponse: firstResponse, generation: started.duration(to: clock.now)
        ))
    }
}
