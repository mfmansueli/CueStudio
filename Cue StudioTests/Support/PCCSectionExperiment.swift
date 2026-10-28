import Foundation
import FoundationModels
@testable import Cue_Studio

/// Isolated four-call quality experiment. Never used by the app or a default test run.
@MainActor
struct PCCSectionExperiment {
    func write(_ original: ScriptRequest) async throws -> (title: String, text: String, instructions: String, prompts: [String]) {
        let request = AIRequestPolicy.prepare(original, on: .privateCloud)
        let model = PrivateCloudComputeLanguageModel()
        let language = request.language.map { ScriptPromptBuilder.languageName($0, variant: request.languageVariant) } ?? "the creator's language"
        let source = ScriptPromptBuilder.videoText(for: request)
        let planningInstructions = "Plan exactly three distinct adjustments for the current request. Use general, reliable explanations, not invented personal stories or unsupported diagnostic rules. The plan and title are in \(language)."
        let planning = LanguageModelSession(model: model, instructions: planningInstructions)
        let plan = try await planning.respond(to: source, generating: PCCSectionPlan.self).content
        var lines = [
            "Write only what the creator says aloud, in \(language). This is one section of a continuous video script, not a standalone video.",
            "The current request defines the subject. Preserve supplied facts and restrictions. Never invent a biography, personal test, result, source or measurement.",
            "Use direct, natural speech. Develop the requested action with a reason and a useful observation. Do not add greetings, headings, markdown, stage cues, motivational filler or a follow/like/share CTA.",
            "The voice profile controls wording and rhythm, not the subject. Optional habits must not become repeated formulas.",
        ]
        if let voice = request.voice {
            lines += ScriptPromptBuilder.voiceLines(voice, platform: request.platform, budget: request.voiceBudget, contextualPreferences: true)
        }
        let instructions = lines.joined(separator: "\n")
        var completed: [String] = []
        var prompts = [source]
        for (index, section) in plan.sections.enumerated() {
            let session = LanguageModelSession(model: model, instructions: instructions)
            let transition = index == 0 ? "Start directly on the subject." : "Continue without restarting the video."
            let prompt = """
            Current request: \(source)
            Complete outline: \(plan.sections.joined(separator: "; "))
            Write section \(index + 1) only: \(section)
            Write 90–110 spoken words for this section, in several connected sentences. Keep the action distinct from the other sections.
            \(transition)
            Already written, for continuity only; do not repeat it:
            <previous>\(completed.joined(separator: "\n\n"))</previous>
            """
            prompts.append(prompt)
            let response = try await session.respond(
                to: prompt, generating: PCCSectionDraft.self, options: GenerationOptions(maximumResponseTokens: 2_048)
            )
            completed.append([response.content.actionAndReason, response.content.checkAndAdjustment]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: "\n\n"))
        }
        return (
            plan.title, completed.joined(separator: "\n\n"),
            "PLANNING:\n" + planningInstructions + "\nSECTION WRITING:\n" + instructions, prompts
        )
    }
}
