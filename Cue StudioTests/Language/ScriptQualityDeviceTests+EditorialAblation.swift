//
//  ScriptQualityDeviceTests+EditorialAblation.swift
//  Cue StudioTests
//

import Foundation
import FoundationModels
import Testing
import UIKit
@testable import Cue_Studio

extension ScriptQualityDeviceTests {
    /// Explicit experimental conditions for one frozen case. None of these alternatives is installed in the normal writer.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CUE_QUALITY_EDITORIAL_ABLATION"] == "1"))
    func comparesEditorialPromptAblations() async throws {
        KeepScreenAwake.enable()
        let environment = ProcessInfo.processInfo.environment
        let settings = try #require(PCCEditorialExperimentSettings(environment: environment), "Invalid editorial experiment configuration")
        let wanted = try #require(environment["CUE_QUALITY_INTENT_CASE"])
        let item = try #require(ScriptIntentCase.load().first { $0.id == wanted })
        let profile = try #require(QualityProfiles.all.first { $0.language == item.language })
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let creator = CreatorProfileService(defaults: defaults.defaults)
        creator.profile = profile.profile(settings.voice)
        let factory = ScriptRequestFactory(
            profile: creator, scriptLanguage: item.language, interfaceLanguage: item.language
        )
        let request = factory.request(idea: item.prompt, platform: .reels, format: nil, formatChoice: item.formatChoice)
        let service = ScriptAIService(usesPrivateCloudCompute: true, preferredModel: .privateCloud, cloudReasoning: settings.reasoningLevel)
        guard service.availability.privateCloud else { try Test.cancel("PCC unavailable: not validated") }
        try #require(UIApplication.shared.applicationState == .active, "Unlock the iPhone and keep the test foreground")
        let run = environment["CUE_QUALITY_RUN"] ?? "editorial-ablation"
        for mode in settings.modes {
            if mode == "staged-raw" || mode == "angle-search-raw" {
                try #require(["pt-BR-editorial-draft", "pt-BR-equipment"].contains(item.id), "These probes are limited to opinions")
            }
            let editorial = mode.hasPrefix("editorial") || mode == "staged-raw" || mode == "angle-search-raw"
            let prompt = PCCEditorialExperimentPrompt(request: request, editorial: editorial)
            let started = ContinuousClock.now
            var sample = QualityRunSample(
                kind: "script", run: run, language: item.language.rawValue, condition: mode, index: 0,
                idea: item.prompt, hasBrief: false, seconds: 0
            )
            sample.caseID = item.id
            sample.expectedDirection = item.expectedDirection
            sample.requiredLiterals = item.requiredLiterals
            sample.reviewChecks = item.reviewChecks + [settings.description]
            sample.model = "privateCloud"
            sample.requestedModel = "privateCloud"
            sample.requestedReasoning = settings.reasoning
            sample.durationPolicy = request.durationPolicy.rawValue
            let responseCap = ScriptAIService.responseTokens(for: AIRequestPolicy.prepare(request, on: .privateCloud), on: .privateCloud)
            sample.responseCap = responseCap
            let prepared = AIRequestPolicy.prepare(request, on: .privateCloud)
            let stacked = mode == "baseline" || mode == "stack-guided"
            var instructions = stacked ? ScriptPromptBuilder.instructions(for: prepared) : prompt.instructions
            if mode == "editorial-demo-raw" {
                try #require(item.prompt != PCCEditorialDemonstration.request, "Never demonstrate the evaluated request’s answer")
                instructions += "\nThe prior exchange is a synthetic demonstration of developed reasoning, not this creator’s history or topic. Follow the current request and profile; do not reuse the example’s subject or wording."
                sample.editorialExampleInstructions = PCCEditorialDemonstration.auditText
            }
            if mode == "bare-raw" { instructions = "" }
            if mode == "editorial-pt-raw" {
                try #require(item.language.rawValue == "pt-BR", "Portuguese instruction probe only")
                instructions = PCCPortugueseEditorialInstructions.text
            }
            let writingInstructions = instructions
            let inputPrompt = mode == "bare-raw" ? item.prompt
                : (stacked ? ScriptPromptBuilder.prompt(for: prepared) : prompt.prompt)
            sample.instructions = instructions
            sample.prompt = inputPrompt
            let outcome: Result<PCCEditorialExperimentOutput, any Error>? = await AIRequestDeadline.value(within: .seconds(60)) { @MainActor in
                do {
                    let output = try await Self.ablationText(
                        mode: mode, service: service, request: request, instructions: writingInstructions,
                        prompt: inputPrompt, settings: settings, responseCap: responseCap
                    )
                    return .success(output)
                } catch { return .failure(error) }
            }
            sample.seconds = started.duration(to: .now).inSeconds
            do {
                let output = try #require(outcome, "PCC evaluation exceeded 60 seconds").get()
                sample.text = output.text
                sample.experimentalTrace = output.trace
                if output.prompts.count > 1 {
                    sample.prompt = output.prompts.enumerated().map { "CALL \($0.offset + 1):\n\($0.element)" }.joined(separator: "\n\n")
                }
                if mode != "baseline" { sample.attempts = output.prompts.count }
            } catch {
                sample.failure = String(describing: error)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            Attachment.record(try encoder.encode(sample), named: "quality-sample-\(run)-\(wanted)-\(mode).json")
            try #require(sample.failure == nil, "\(mode): \(sample.failure ?? "")")
            #expect(sample.wasWritten, "Nonempty output does not approve editorial quality")
            try await Task.sleep(for: .seconds(3))
        }
    }

    private static func ablationText(
        mode: String, service: ScriptAIService, request: ScriptRequest, instructions: String, prompt: String,
        settings: PCCEditorialExperimentSettings, responseCap: Int
    ) async throws -> PCCEditorialExperimentOutput {
        if mode == "baseline" {
            let result = try await service.generate(request)
            try #require(result.model == .privateCloud, "Unexpected fallback is not a PCC comparison")
            return PCCEditorialExperimentOutput(text: result.text, prompts: [prompt])
        }
        if mode == "staged-raw" {
            return try await PCCProgressiveDraftExperiment().write(
                instructions: instructions, original: prompt, settings: settings, responseCap: responseCap
            )
        }
        if mode == "angle-search-raw" {
            return try await PCCAngleSearchExperiment().write(
                instructions: instructions, original: prompt, settings: settings, responseCap: responseCap
            )
        }
        let model = PrivateCloudComputeLanguageModel()
        if mode == "bare-raw" {
            let session = LanguageModelSession(model: model)
            let text = try await session.respond(
                to: prompt, options: settings.options(responseCap: responseCap),
                contextOptions: ContextOptions(includeSchemaInPrompt: false, reasoningLevel: settings.reasoningLevel)
            ).content
            return PCCEditorialExperimentOutput(text: text, prompts: [prompt])
        }
        let session = mode == "editorial-demo-raw"
            ? LanguageModelSession(model: model, transcript: PCCEditorialDemonstration.transcript(instructions: instructions))
            : LanguageModelSession(model: model, instructions: instructions)
        let guided = mode.hasSuffix("-guided")
        let options = settings.options(responseCap: responseCap)
        let context = ContextOptions(includeSchemaInPrompt: guided, reasoningLevel: settings.reasoningLevel)
        if guided {
            let text = try await session.respond(
                to: prompt, generating: PCCProseDraft.self, options: options, contextOptions: context
            ).content.text
            return PCCEditorialExperimentOutput(text: text, prompts: [prompt])
        }
        let text = try await session.respond(to: prompt, options: options, contextOptions: context).content
        return PCCEditorialExperimentOutput(text: text, prompts: [prompt])
    }

}
