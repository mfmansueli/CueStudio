import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("Informative duration experiment")
struct ScriptDurationPolicyTests {
    private func request() -> ScriptRequest {
        ScriptRequest(
            source: .prompt("Explain three window lighting adjustments. No follow CTA."), platform: .shorts,
            voice: QualityProfiles.english.full.voice, targetRange: 60...90, language: .english
        )
    }

    @Test func theExperimentRemovesPlatformAndHabitualLengthWithoutChangingOtherInputs() {
        let original = request()
        #expect(original.durationPolicy == .targeted)
        var free = original
        free.durationPolicy = .informative
        let targeted = AIRequestPolicy.prepare(original, on: .privateCloud)
        let informative = AIRequestPolicy.prepare(free, on: .privateCloud)
        let prompt = ScriptPromptBuilder.prompt(for: informative)
        let instructions = ScriptPromptBuilder.instructions(for: informative)
        #expect(!prompt.contains("Length: between"))
        #expect(!prompt.contains("spoken words"))
        #expect(!prompt.contains("within the requested length"))
        #expect(!instructions.contains("within the chosen duration"))
        #expect(informative.voice?.reach.length == nil)
        #expect(targeted.voice?.reach.length == nil, "a chosen length is the only length the request says")
        #expect(!ScriptPromptBuilder.instructions(for: targeted).lowercased().contains("videos are usually"))
        #expect(informative.voice?.style == targeted.voice?.style)
        #expect(informative.voice?.avoid == targeted.voice?.avoid)
        #expect(informative.source == targeted.source)
        #expect(informative.targetRange == targeted.targetRange, "reference range remains available for the informative bar")
        #expect(ScriptAIService.responseTokens(for: informative, on: .privateCloud) == 4_096,
                "informative writing has room to develop without using the platform duration as a token quota")
        #expect(ScriptPromptBuilder.prompt(for: targeted).contains("Length: between"))
    }

    @Test func explicitUserWordingAndLengthStillReachTheWriter() {
        var original = request()
        original.durationPolicy = .informative
        original.source = .prompt("In 30 seconds, explain light. Include exactly: Less rush, more intention.")
        let prepared = AIRequestPolicy.prepare(original, on: .privateCloud)
        let prompt = ScriptPromptBuilder.prompt(for: prepared)
        #expect(prompt.contains("In 30 seconds"))
        #expect(prompt.contains("Honor any length explicitly requested"))
        #expect(prepared.requiredPhrases == ["Less rush, more intention."])
        #expect(prompt.contains("Mandatory verbatim wording"))
    }

    @Test func informativeLengthDoesNotAddATooShortViolation() async throws {
        var original = request()
        original.voice = nil
        original.durationPolicy = .informative
        let writer = VoiceCheckedWriting(
            draft: { _, _ in GeneratedScript(title: "Update", text: "The event starts tomorrow.", usedLanguageModel: true) },
            isGuardrailRefusal: { _ in false }, report: { _, _ in }
        )
        let result = try await writer.write(original)
        #expect(!result.voiceViolations.contains(.tooShort))
    }

    @Test func aFreeCloudRequestCanPreserveTeamPerspectiveOverTheUsualProfile() async throws {
        var original = request()
        original.modelRoute = .privateCloud
        original.durationPolicy = .informative
        original.source = .prompt("Our team published the wrong time. Correct it to 14:35.")
        var attempts = 0
        let writer = VoiceCheckedWriting(
            draft: { _, _ in
                attempts += 1
                return GeneratedScript(title: "Correction", text: "We published the wrong time. The correct time is 14:35.", usedLanguageModel: true)
            }, isGuardrailRefusal: { _ in false }, report: { _, _ in }
        )
        let result = try await writer.write(original)
        #expect(attempts == 1)
        #expect(result.text.contains("We published"))
        #expect(!result.voiceViolations.contains(.pronoun))
    }

}
