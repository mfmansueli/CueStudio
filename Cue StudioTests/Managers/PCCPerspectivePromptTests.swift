import Testing
@testable import Cue_Studio

@Suite("PCC request perspective overrides voice defaults")
struct PCCPerspectivePromptTests {
    private static func request(_ perspective: SpeaksAs, route: AIModelRoute) -> ScriptRequest {
        var voice = VoicePersonas.saasFounder.profile.voice
        voice.speaksAs = perspective
        var request = ScriptRequest(
            source: .prompt("Write a second-person scene: you rehearse, but the camera was not recording. No first-person narrator."),
            platform: .reels, tone: nil, voice: voice, targetRange: 60...90, language: .english
        )
        request.durationPolicy = .informative
        request.modelRoute = route
        request.format = .pov
        request.formatChoice = .type(.pov)
        return request
    }

    @Test(arguments: [SpeaksAs.i, .we])
    func cloudDoesNotContradictTheRequestedNarrator(perspective: SpeaksAs) {
        let request = Self.request(perspective, route: .privateCloud)
        let instructions = ScriptPromptBuilder.instructions(for: request)
        let prompt = ScriptPromptBuilder.prompt(for: request)
        #expect(instructions.contains("Use the creator's usual perspective only when the request leaves it unspecified."))
        #expect(!instructions.contains("Write in the first person, as the creator"))
        #expect(!instructions.contains("They speak as a team: say “we” and “our”, never “I”."))
        #expect(!instructions.contains("They speak as one person: say “I” and “my”."))
        #expect(prompt.contains("If the current request specifies another narrator, grammatical person or supplied agency, preserve that instead."))
        #expect(!prompt.contains("Say “we”, never “I”."))
        #expect(!prompt.contains("Speak as one person (“I”)."))
        #expect(prompt.contains("you rehearse, but the camera was not recording"))
        #expect(instructions.contains("Rules:"), "Contextual perspective must not soften avoid rules")
    }

    @Test func theMeasuredLocalInstructionsRetainTheirOriginalPerspectiveRules() {
        let request = Self.request(.we, route: .onDevice)
        #expect(ScriptPromptBuilder.instructions(for: request).contains("They speak as a team: say “we” and “our”, never “I”."))
        #expect(ScriptPromptBuilder.prompt(for: request).contains("Say “we”, never “I”."))
    }

    @Test func seriousTeamFactsDoNotAcquireAPersonalNarratorInstruction() {
        var request = Self.request(.i, route: .privateCloud)
        request.source = .prompt("Publicamos o horário errado. O correto é 14:35.")
        request.format = .apology
        request.language = .portugueseBrazil
        let instructions = ScriptPromptBuilder.instructions(for: request)
        let prompt = ScriptPromptBuilder.prompt(for: request)
        #expect(!instructions.contains("Write in the first person, as the creator"))
        #expect(!prompt.contains("Speak as one person (“I”)."))
        #expect(prompt.contains("Publicamos o horário errado. O correto é 14:35."))
    }
}
