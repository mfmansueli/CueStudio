//
//  ScriptPromptBuilderTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ScriptPromptBuilder")
struct ScriptPromptBuilderTests {
    private let voice = CreatorVoice(
        sounds: [.casual, .confident], phrases: ["Hey fam"], vocabulary: .genZ,
        styles: [.shortSentences, .storytelling], niches: [.wellness], topics: [VoiceTopicEntry(topic: .niche(.wellness))]
    )

    private func formatRequest(type: ScriptType = .list, voice: CreatorVoice? = nil) -> ScriptRequest {
        ScriptRequest(
            source: .format(type, brief: ["topic": "Morning habits"]), platform: .tiktok, tone: .casual,
            voice: voice, targetRange: 60...90
        )
    }

    private func promptRequest(_ text: String, voice: CreatorVoice? = nil) -> ScriptRequest {
        ScriptRequest(source: .prompt(text), platform: .youtube, tone: nil, voice: voice, targetRange: 108...132)
    }

    /// The model is told the language by its English name, whatever the interface is in.
    @Test func instructionsNameTheLanguageToWriteIn() {
        var request = promptRequest("Minha rotina de manhã")
        #expect(!ScriptPromptBuilder.instructions(for: request).contains("Write the title and every block in"))
        request.language = .portugueseBrazil
        #expect(ScriptPromptBuilder.instructions(for: request).contains("Write the title and every block in Portuguese (Brazil)."))
    }

    @Test func rewritesKeepTheScriptsLanguage() {
        #expect(ScriptPromptBuilder.rewriteInstructions().contains("Keep the script in the language it is written in"))
        let context = RewriteContext(structure: .generic, platform: .tiktok, idealRange: 60...90, language: .japanese)
        #expect(ScriptPromptBuilder.instruction(for: .translate, context: context).contains("into Japanese"))
    }

    @Test func themeIdeasAreWrittenInTheInterfaceLanguage() {
        #expect(ScriptPromptBuilder.themesPrompt(for: [.wellness], language: .german).hasSuffix("Write the ideas in German."))
    }

    @Test func formatPromptCarriesStructureLengthAndBrief() {
        let prompt = ScriptPromptBuilder.prompt(for: formatRequest())
        #expect(prompt.contains("Hook → Tips → CTA"))
        let asked = ScriptPromptBuilder.askedRange(for: 60...90)
        #expect(prompt.contains("between \(asked.low) and \(asked.high) spoken words"))
        #expect(prompt.contains("- Topic: Morning habits"))
        #expect(prompt.contains("Tone: casual."))
    }

    @Test func freePromptCarriesTheIdeaAndItsLength() {
        let prompt = ScriptPromptBuilder.prompt(for: promptRequest("How the electric shower was invented"))
        #expect(prompt.contains("The video: How the electric shower was invented"))
        let asked = ScriptPromptBuilder.askedRange(for: 108...132)
        #expect(prompt.contains("between \(asked.low) and \(asked.high) spoken words"))
        #expect(prompt.contains("for YouTube (long-form)."), "the platform is named in English whatever the interface says")
        #expect(!prompt.contains("Tone:"))
    }

    @Test func freePromptsAskForAccuracy() {
        #expect(ScriptPromptBuilder.instructions(for: promptRequest("Anything")).contains(ScriptPromptBuilder.accuracyRule))
        #expect(!ScriptPromptBuilder.instructions(for: formatRequest()).contains(ScriptPromptBuilder.accuracyRule))
    }

    @Test func instructionsCarryTheCreatorsVoice() {
        let instructions = ScriptPromptBuilder.instructions(for: formatRequest(voice: voice))
        #expect(instructions.contains("“Hey fam”"))
        #expect(instructions.contains("They sound casual and confident."))
        #expect(instructions.contains("casual slang"))
        #expect(instructions.contains("Their audience is young"))
        #expect(instructions.contains("Style: storytelling."), "short sentences is what every profile holds: it is not told")
        #expect(instructions.contains("Topics: wellness."))
    }

    @Test func withoutAVoiceTheInstructionsStayNeutral() {
        #expect(!ScriptPromptBuilder.instructions(for: formatRequest()).contains("Write in the creator's own voice."))
    }

    @Test func seriousFormatsForbidHypeAndIgnoreTheVoice() {
        let instructions = ScriptPromptBuilder.instructions(for: formatRequest(type: .apology, voice: voice))
        #expect(instructions.contains("No hooks, jokes, hype"))
        #expect(!instructions.contains("Hey fam"))
        #expect(!ScriptPromptBuilder.prompt(for: formatRequest(type: .apology)).contains("hook that works"))
    }

    @Test func inMyVoiceRewritesWithTheVoiceInTheInstructions() {
        let instructions = ScriptPromptBuilder.rewriteInstructions(voice: voice)
        #expect(instructions.contains("They sound casual and confident."))
        let context = RewriteContext(structure: .generic, platform: .tiktok, idealRange: 60...90, voice: voice)
        #expect(ScriptPromptBuilder.instruction(for: .inMyVoice, context: context).contains("sounds like the creator"))
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

    @Test func cleanTitleKeepsOneLineWithoutDecoration() {
        #expect(ScriptPromptBuilder.cleanTitle("**“How Brazil got the electric shower”**\nextra") == "How Brazil got the electric shower")
        #expect(ScriptPromptBuilder.cleanTitle("# My morning") == "My morning")
    }

    @Test func fitToTimeTargetsTheIdealWordCount() {
        let context = RewriteContext(structure: .generic, platform: .tiktok, idealRange: 60...90)
        #expect(ScriptPromptBuilder.instruction(for: .fitToTime, context: context).contains("between \(ReadTime.words(for: 60)) and \(ReadTime.words(for: 90)) spoken words"))
    }

    @Test func withoutVocabularyThePromptSaysNothingAboutIt() {
        var free = voice
        free.vocabulary = nil
        free.styles = []
        let lines = ScriptPromptBuilder.voiceLines(free)
        #expect(!lines.contains { $0.contains("slang") || $0.contains("words") && $0.hasPrefix("Use") })
        #expect(!lines.contains { $0.hasPrefix("Their style") })
        #expect(lines.contains { $0.contains("Hey fam") })
    }

    // MARK: - Short videos and a model stuck on a cue

    @Test func aShortVideoIsAskedAsItIsAndNeverForMoreThanTwoMinutes() {
        // One to three minutes of a creator's usual length: 150 to 450 words. For one line of idea, no more than two minutes.
        let asked = ScriptPromptBuilder.askedRange(for: 60...180)
        #expect(asked.low == 150)
        #expect(asked.high == ScriptPromptBuilder.shortFormCeiling)
        #expect(ScriptPromptBuilder.askedWords(75) == 75, "a TikTok minimum is not multiplied")
        #expect(ScriptPromptBuilder.askedWords(600) > 600, "a long video still is")
        #expect(!ScriptPromptBuilder.lengthRule(minimumWords: 150).contains("sentences in every block"))
    }

    @Test func aCueRepeatedOverAndOverStaysOnce() {
        let stuck = "I start here. [pause]... [pause]... [pause]... [pause]... [pause]... and go on. [smile] [smile] [smile] Done."
        #expect(ScriptPromptBuilder.collapsingRepeatedCues(stuck) == "I start here. [pause] and go on. [smile] Done.")
        let fine = "One. [pause] Two. [pause] Three. [pause] [smile] Four. [pause][pause]"
        #expect(ScriptPromptBuilder.collapsingRepeatedCues(fine) == fine, "two in a row, or the same cue far apart, is the creator's own")
    }
}
