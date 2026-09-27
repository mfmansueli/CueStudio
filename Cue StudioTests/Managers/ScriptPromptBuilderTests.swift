//
//  ScriptPromptBuilderTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ScriptPromptBuilder")
struct ScriptPromptBuilderTests {
    private func request(type: ScriptType = .list, phrases: [String] = ["Hey fam"]) -> ScriptRequest {
        ScriptRequest(
            type: type, brief: ["topic": "Morning habits"], platform: .tiktok, tone: .casual,
            phrases: phrases, niches: [.wellness], idealRange: 60...90
        )
    }

    @Test func promptCarriesStructureLengthAndBrief() {
        let prompt = ScriptPromptBuilder.prompt(for: request())
        #expect(prompt.contains("Hook → Tips → CTA"))
        #expect(prompt.contains("between 150 and 225 spoken words"))
        #expect(prompt.contains("- Topic: Morning habits"))
    }

    @Test func instructionsUseTheCreatorsPhrases() {
        #expect(ScriptPromptBuilder.instructions(for: request()).contains("\"Hey fam\""))
    }

    @Test func seriousFormatsForbidHype() {
        let instructions = ScriptPromptBuilder.instructions(for: request(type: .apology))
        #expect(instructions.contains("No hooks, jokes, hype"))
        #expect(!ScriptPromptBuilder.prompt(for: request(type: .apology)).contains("hook that works"))
    }

    @Test func cleanRemovesMarkdownAndBlockLabels() {
        let response = """
        Title: Morning habits
        ## Hook
        **Hook:** Okay, real talk. [pause]

        Body: Number one — no phone.
        """
        #expect(ScriptPromptBuilder.clean(response) == "Okay, real talk. [pause]\n\nNumber one — no phone.")
    }

    @Test func cleanRemovesWrappingQuotes() {
        #expect(ScriptPromptBuilder.clean("\"Hello there.\"") == "Hello there.")
    }

    @Test func cleanKeepsOrdinaryColons() {
        #expect(ScriptPromptBuilder.clean("Here's the thing: it works.") == "Here's the thing: it works.")
    }

    @Test func fitToTimeTargetsTheIdealWordCount() {
        let context = RewriteContext(structure: .generic, platform: .tiktok, idealRange: 60...90)
        #expect(ScriptPromptBuilder.instruction(for: .fitToTime, context: context).contains("between 150 and 225 spoken words"))
    }
}
