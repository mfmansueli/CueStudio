import Foundation
import FoundationModels
import Testing
import UIKit
@testable import Cue_Studio

extension ScriptQualityDeviceTests {
    /// Four conditions for one frozen case. None of these alternatives is installed in the normal writer.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CUE_QUALITY_EDITORIAL_ABLATION"] == "1"))
    func comparesEditorialPromptAblations() async throws {
        KeepScreenAwake.enable()
        let environment = ProcessInfo.processInfo.environment
        let wanted = try #require(environment["CUE_QUALITY_INTENT_CASE"])
        let item = try #require(ScriptIntentCase.load().first { $0.id == wanted })
        let profile = try #require(QualityProfiles.all.first { $0.language == item.language })
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let creator = CreatorProfileService(defaults: defaults.defaults)
        creator.profile = profile.full
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: creator, scriptLanguage: item.language, interfaceLanguage: item.language
        )
        let request = factory.request(idea: item.prompt, platform: .reels, format: nil, formatChoice: item.formatChoice)
        let service = ScriptAIService(usesPrivateCloudCompute: true, preferredModel: .privateCloud)
        guard service.availability.privateCloud else { try Test.cancel("PCC unavailable: not validated") }
        try #require(UIApplication.shared.applicationState == .active, "Unlock the iPhone and keep the test foreground")
        let prompt = PCCEditorialExperimentPrompt(request: request)
        let run = environment["CUE_QUALITY_RUN"] ?? "editorial-ablation"
        let modes = environment["CUE_QUALITY_ABLATION_MODES"]?.split(separator: ",").map(String.init)
            ?? ["baseline", "stack-guided", "lean-guided", "lean-raw"]
        try #require(!modes.isEmpty && modes.allSatisfy { ["baseline", "stack-guided", "lean-guided", "lean-raw"].contains($0) })
        for mode in modes {
            let started = ContinuousClock.now
            var sample = QualityRunSample(
                kind: "script", run: run, language: item.language.rawValue, condition: mode, index: 0,
                idea: item.prompt, hasBrief: false, seconds: 0
            )
            sample.caseID = item.id
            sample.expectedDirection = item.expectedDirection
            sample.requiredLiterals = item.requiredLiterals
            sample.reviewChecks = item.reviewChecks
            sample.model = "privateCloud"
            sample.requestedModel = "privateCloud"
            sample.requestedReasoning = "default"
            sample.durationPolicy = request.durationPolicy.rawValue
            let responseCap = ScriptAIService.responseTokens(for: AIRequestPolicy.prepare(request, on: .privateCloud), on: .privateCloud)
            sample.responseCap = responseCap
            let prepared = AIRequestPolicy.prepare(request, on: .privateCloud)
            let stacked = mode == "baseline" || mode == "stack-guided"
            let instructions = stacked ? ScriptPromptBuilder.instructions(for: prepared) : prompt.instructions
            let inputPrompt = stacked ? ScriptPromptBuilder.prompt(for: prepared) : prompt.prompt
            sample.instructions = instructions
            sample.prompt = inputPrompt
            let outcome: Result<String, any Error>? = await AIRequestDeadline.value(within: .seconds(60)) { @MainActor in
                do {
                    let text: String
                    if mode == "baseline" {
                        let result = try await service.generate(request)
                        try #require(result.model == .privateCloud, "Unexpected fallback is not a PCC comparison")
                        text = result.text
                    } else {
                        let session = LanguageModelSession(model: PrivateCloudComputeLanguageModel(), instructions: instructions)
                        let options = GenerationOptions(maximumResponseTokens: responseCap)
                        if mode != "lean-raw" {
                            text = try await session.respond(to: inputPrompt, generating: PCCProseDraft.self, options: options).content.text
                        } else {
                            text = try await session.respond(to: inputPrompt, options: options).content
                        }
                    }
                    return .success(text)
                } catch { return .failure(error) }
            }
            sample.seconds = started.duration(to: .now).inSeconds
            do {
                sample.text = try #require(outcome, "PCC evaluation exceeded 60 seconds").get()
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
}
