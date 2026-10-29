//
//  PCCAngleSearchExperiment.swift
//  Cue StudioTests
//

import Foundation
import FoundationModels
import Testing

/// Diverge before choosing: unlike the previous single-angle plan, compares three substantive explanations in the first call.
@MainActor
struct PCCAngleSearchExperiment {
    func write(
        instructions: String, original: String, settings: PCCEditorialExperimentSettings, responseCap: Int
    ) async throws -> PCCEditorialExperimentOutput {
        try #require(responseCap >= 512)
        let model = PrivateCloudComputeLanguageModel()
        let planningInstructions = """
        Develop three different substantive answers to the current request, then select the strongest explanation.
        They must differ in what explains the result, not just in imagery or vocabulary. Prefer a claim that can be demonstrated through
        an observable contrast. Preserve the current request's facts, narrator and requirements. Do not invent biography, credentials,
        measurements or evidence. This is an internal editorial brief, not the spoken script. Delivery habits must not replace substance.
        """
        let planner = LanguageModelSession(model: model, instructions: planningInstructions)
        let planningCap = responseCap * 3 / 8
        let context = ContextOptions(includeSchemaInPrompt: true, reasoningLevel: settings.reasoningLevel)
        let selection = try await planner.respond(
            to: original, generating: PCCEditorialAngleSelection.self, options: settings.options(responseCap: planningCap), contextOptions: context
        ).content
        try #require(selection.candidates.indices.contains(selection.selectedIndex), "The selected angle must exist")
        try Task.checkCancellation()
        let selected = selection.candidates[selection.selectedIndex]
        let prompt = original + "\n\nSelected substantive direction (develop it, do not recite these labels):\n" + selected.writingBrief
            + "\nWrite the complete spoken text. Honor every explicit requirement of the original request, including its analogy if asked."
        let writer = LanguageModelSession(model: model, instructions: instructions)
        let response = try await writer.respond(
            to: prompt, options: settings.options(responseCap: responseCap - planningCap),
            contextOptions: ContextOptions(reasoningLevel: settings.reasoningLevel)
        )
        let trace = selection.candidates.enumerated().map { "CANDIDATE \($0.offset):\n" + $0.element.writingBrief }.joined(separator: "\n\n")
            + "\n\nSELECTED: \(selection.selectedIndex)\n" + selection.selectionReason
        return PCCEditorialExperimentOutput(
            text: response.content,
            prompts: ["PLANNING INSTRUCTIONS:\n" + planningInstructions + "\nUSER INPUT:\n" + original, prompt], trace: trace
        )
    }
}
