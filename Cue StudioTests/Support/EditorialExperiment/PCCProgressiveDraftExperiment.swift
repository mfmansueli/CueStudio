//
//  PCCProgressiveDraftExperiment.swift
//  Cue StudioTests
//

import Foundation
import FoundationModels
import Testing

/// Opinion-only probe: three continuations with different semantic jobs, no duration or minimum-word quota.
@MainActor
struct PCCProgressiveDraftExperiment {
    static let phases = [
        "Open directly on a meaningful distinction that answers the request. Explain why that distinction matters to the listener. Develop this first movement; do not announce an outline, add a metaphor or close the script yet.",
        "Continue the argument: explain the connection between cause and consequence, then work through a concrete hypothetical contrast that demonstrates it. If an analogy was requested, use one and explain its connection. Do not restart or conclude yet.",
        "Continue with a useful implication or boundary that adds something not already explained. Resolve the question raised at the opening. End with a thought earned by the argument, without asking for engagement. Do not summarize or rewrite the previous paragraphs.",
    ]

    func write(
        instructions: String, original: String, settings: PCCEditorialExperimentSettings, responseCap: Int
    ) async throws -> PCCEditorialExperimentOutput {
        let model = PrivateCloudComputeLanguageModel()
        var written: [String] = []
        var prompts: [String] = []
        for phase in Self.phases {
            try Task.checkCancellation()
            let prompt = """
            Original request and context (retain every explicit requirement):
            \(original)

            Spoken script already written (continue it, do not repeat it):
            \(written.joined(separator: "\n\n"))

            Write only the next spoken continuation, with this job:
            \(phase)
            """
            prompts.append(prompt)
            let session = LanguageModelSession(model: model, instructions: instructions)
            let response = try await session.respond(
                to: prompt, options: settings.options(responseCap: max(1, responseCap / Self.phases.count)),
                contextOptions: ContextOptions(reasoningLevel: settings.reasoningLevel)
            )
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            try #require(!text.isEmpty, "An empty stage is not a finished draft")
            written.append(text)
        }
        return PCCEditorialExperimentOutput(text: written.joined(separator: "\n\n"), prompts: prompts)
    }
}
