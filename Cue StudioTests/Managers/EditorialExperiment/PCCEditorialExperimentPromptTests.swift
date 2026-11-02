//
//  PCCEditorialExperimentPromptTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@MainActor
@Suite("Editorial prompt ablation contracts")
struct PCCEditorialExperimentPromptTests {
    @Test func keepsTheCurrentRequestAndInspirationWithoutAddingDurationQuota() {
        let idea = "Compare two cameras. Include exactly: Keep the useful parts."
        var request = ScriptRequest(
            source: .prompt(idea), platform: .reels, voice: nil, targetRange: 60...90, language: .english
        )
        request.durationPolicy = .informative
        request.formatChoice = .talkingHead
        request.brief = IdeaBrief(subject: "Two cameras", angle: "Choose for the problem", openingLine: "Start with the problem.")
        let prompt = PCCEditorialExperimentPrompt(request: request)
        #expect(prompt.prompt.contains(idea))
        #expect(prompt.prompt.contains("Choose for the problem"))
        #expect(prompt.prompt.contains("Start with the problem."))
        #expect(prompt.prompt.contains("talkingHead"))
        #expect(!prompt.prompt.contains("Requested duration"))
        #expect(!prompt.prompt.contains("Length: between"))
        #expect(prompt.instructions.contains("English"))
    }

    @Test func keepsExplicitDurationAndTheVoiceSamplesTheAppSends() {
        var voice = VoicePersonas.saasFounder.profile.voice
        voice.examples = [VoiceExample(text: "PRIVATE_PASTED_EXAMPLE")]
        let request = ScriptRequest(
            source: .prompt("Explain camera choices"), platform: .reels, voice: voice, targetRange: 60...90, language: .english
        )
        let prompt = PCCEditorialExperimentPrompt(request: request)
        #expect(prompt.prompt.contains("Requested duration: 60–90 seconds"))
        #expect(prompt.prompt.contains("PRIVATE_PASTED_EXAMPLE"), "Private Cloud Compute gets the examples (D1)")
        #expect(prompt.prompt.contains("Creator profile"))
        #expect(request.voice?.examples.first?.text == "PRIVATE_PASTED_EXAMPLE", "Never mutate the saved voice")
    }
}
