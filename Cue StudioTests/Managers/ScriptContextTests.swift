//
//  ScriptContextTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the platform, the format and the creator's voice and topics tell the AI together (plan: the platform, the format, My Cue Voice and the
/// niche all feed one prompt): each says its part in English, short, and none contradicts another.
@MainActor
@Suite("Script context")
struct ScriptContextTests {
    private func request(
        _ idea: String = "Why mornings are hard", platform: Platform = .tiktok, format: ScriptType? = nil, voice: CreatorVoice? = nil,
        range: ClosedRange<TimeInterval> = 60...90
    ) -> ScriptRequest {
        ScriptRequest(source: .prompt(idea), platform: platform, tone: nil, voice: voice, targetRange: range, format: format)
    }

    // MARK: - Platform

    @Test func everyPlatformSaysWhatWorksThere() {
        for platform in Platform.allCases {
            let line = PlatformGuide.line(for: platform)
            #expect(line.hasPrefix("Platform: ") && line.contains(platform.promptName.components(separatedBy: " ").first ?? ""), "\(platform)")
            let english = line.unicodeScalars.allSatisfy { $0.isASCII }
            #expect(english, "\(platform): English only")
        }
        #expect(Set(Platform.allCases.map { PlatformGuide.line(for: $0) }).count == Platform.allCases.count)
    }

    @Test func theInstructionsCarryThePlatformsGuideAndThePromptNamesItInEnglish() {
        let linkedin = request(platform: .linkedin)
        #expect(ScriptPromptBuilder.instructions(for: linkedin).contains(PlatformGuide.line(for: .linkedin)))
        #expect(ScriptPromptBuilder.prompt(for: linkedin).contains("script for LinkedIn."))
        #expect(ScriptPromptBuilder.prompt(for: request(platform: .reels)).contains("for Instagram Reels."))
    }

    @Test func aSeriousFormatHasNoPlatformHookOrCallToAction() {
        let apology = request("I am sorry", format: .apology)
        let instructions = ScriptPromptBuilder.instructions(for: apology)
        #expect(!instructions.contains("Platform:") && !instructions.contains("Never invent personal stories"))
        #expect(instructions.contains(ScriptPromptBuilder.seriousRule))
    }

    @Test func aProfessionalPlatformCapsTheVoiceWhateverItAllowsElsewhere() {
        let comedian = VoicePersonas.comedian.profile.voice
        let tiktok = ScriptPromptBuilder.instructions(for: request(platform: .tiktok, voice: comedian))
        #expect(tiktok.contains("Mild swearing is fine now and then") && tiktok.contains("words: some casual slang"))
        let linkedin = ScriptPromptBuilder.instructions(for: request(platform: .linkedin, voice: comedian))
        #expect(!linkedin.contains("Mild swearing") && linkedin.contains("Never swear."))
        #expect(!linkedin.contains("some casual slang") && linkedin.contains("words: plain and everyday"))
        let linkedinPrompt = ScriptPromptBuilder.prompt(for: request(platform: .linkedin, voice: comedian))
        #expect(linkedinPrompt.contains("Keep it professional: no slang, no swearing, no emojis."))
        #expect(!ScriptPromptBuilder.prompt(for: request(platform: .tiktok, voice: comedian)).contains("Keep it professional"))
    }

    @Test func onlyLinkedInIsProfessional() {
        #expect(Platform.allCases.filter { PlatformRegister($0) == .professional } == [.linkedin])
    }

    // MARK: - Format

    @Test func everyFormatNamesItsBlocksInEnglishWithWhatEachOneIsFor() {
        for type in ScriptType.allCases {
            let guide = FormatGuide.guide(for: type)
            #expect(guide.blocks.count == guide.purposes.count && guide.blocks.count >= 3, "\(type)")
            let english = (guide.blocks + guide.purposes + [guide.name]).allSatisfy { text in
                text.unicodeScalars.allSatisfy { $0.isASCII || $0 == "“" || $0 == "”" }
            }
            #expect(english, "\(type)")
            // The same blocks the creator sees, in the same order: only the language of the name differs.
            #expect(guide.blocks.count == type.structure.blocks.count, "\(type)")
        }
        #expect(FormatGuide.generic.blocks.count == ScriptStructure.generic.blocks.count)
    }

    @Test func theFormatTheCreatorChoseShapesThePromptWithWhatEachBlockDoes() {
        let prompt = ScriptPromptBuilder.prompt(for: request(format: .tutorial))
        #expect(prompt.contains("Write a tutorial script for TikTok."))
        #expect(prompt.contains("Blocks, in this order: Hook → Promise → Steps → CTA."))
        #expect(prompt.contains("What each block does: Hook: show the result or the problem. Promise:"))
        #expect(prompt.contains("Steps: one action per step, concrete."))
    }

    @Test func aFreeIdeaWithNoFormatTakesTheOneItAsksFor() {
        #expect(ScriptPromptBuilder.prompt(for: request("How to start running when you hate it")).contains("Write a tutorial script"))
        #expect(ScriptPromptBuilder.prompt(for: request("5 habits that fixed my mornings")).contains("Write a list of tips script"))
        #expect(ScriptPromptBuilder.prompt(for: request("The myth about stretching before a run")).contains("Write a myth vs fact script"))
        #expect(ScriptPromptBuilder.prompt(for: request("Something about my day")).contains("Write a talking video script"))
    }

    @Test func theChosenFormatAlwaysBeatsTheGuess() {
        let prompt = ScriptPromptBuilder.prompt(for: request("How to start running", format: .story))
        #expect(prompt.contains("Write a storytime script") && !prompt.contains("tutorial"))
    }

    @Test func theGuessReadsTheIdeaAndThenWhatTheCreatorFilmsMost() {
        #expect(FormatGuess.format(for: "How I save 500 a month", usual: []) == .tutorial)
        #expect(FormatGuess.format(for: "3 things nobody tells new parents", usual: []) == .list)
        #expect(FormatGuess.format(for: "POV: you finally stopped snoozing", usual: []) == .pov)
        #expect(FormatGuess.format(for: "Unpopular opinion about cardio", usual: []) == .opinion)
        #expect(FormatGuess.format(for: "Honest review of my new camera", usual: []) == .review)
        #expect(FormatGuess.format(for: "Why I quit my job", usual: []) == .story)
        #expect(FormatGuess.format(for: "Something about my day", usual: []) == nil)
        #expect(FormatGuess.format(for: "Something about my day", usual: [.review, .list]) == .list, "a vague idea takes what they film most that suits it")
        #expect(FormatGuess.format(for: "Something about my day", usual: [.ad, .apology, .pov, .launch]) == nil, "never an ad, a serious format or one that needs its own subject")
        #expect(FormatGuess.format(for: "Honest review of my camera", usual: [.tutorial]) == .tutorial, "a creator who only films tutorials gets one")
        #expect(FormatGuess.format(for: "3 tips for sleep", usual: [.review]) == .list, "an unmistakable shape wins")
    }

    @Test func theGuessIsOnlyForTheAINothingIsSavedUnderIt() {
        let free = request("How to start running")
        #expect(free.type == nil && free.format == nil)
        #expect(ScriptPromptBuilder.formatGuide(for: free).name == "tutorial")
    }

    // MARK: - Honesty

    @Test func theAIIsToldNeverToInventTheCreatorsStoriesResultsOrCredentials() {
        let instructions = ScriptPromptBuilder.instructions(for: request(voice: VoicePersonas.nurseEducator.profile.voice))
        #expect(instructions.contains(ScriptPromptBuilder.honestyRule))
        #expect(ScriptPromptBuilder.instructions(for: request(format: .tutorial)).contains(ScriptPromptBuilder.honestyRule))
    }

    // MARK: - Length

    private func factory(voice: (CreatorProfile) -> CreatorProfile) -> (ScriptRequestFactory, TestDefaults) {
        let defaults = TestDefaults()
        let service = CreatorProfileService(defaults: defaults.defaults)
        service.profile = voice(VoicePersonas.yogaTeacher.profile)
        return (ScriptRequestFactory(rules: TestData.rulesService(), profile: service, scriptLanguage: nil, interfaceLanguage: .english), defaults)
    }

    @Test func onAutoTheLengthIsHowLongTheCreatorsVideosUsuallyAre() {
        let (factory, defaults) = factory { var profile = $0; profile.reach.length = .under30; return profile }
        defer { defaults.tearDown() }
        let range = factory.request(idea: "Why mornings are hard", platform: .reels, format: nil).targetRange
        #expect(range == 25...30, "a spoken video is never under 25 s, whatever “under 30 s” was")
    }

    @Test func aLengthTheCreatorChoseNowOrTypedInTheIdeaBeatsTheUsualOne() {
        let (factory, defaults) = factory { var profile = $0; profile.reach.length = .under30; return profile }
        defer { defaults.tearDown() }
        #expect(factory.request(idea: "x", platform: .tiktok, format: nil, length: .minutes2).targetRange == 108...132)
        #expect(factory.request(idea: "a 2 minute video about mornings", platform: .tiktok, format: nil).targetRange == 108...132)
    }

    @Test func withNoUsualLengthLongOrALongFormPlatformTheIdealStands() {
        let (none, noneDefaults) = factory { var profile = $0; profile.reach.length = nil; return profile }
        defer { noneDefaults.tearDown() }
        let ideal = TestData.preset(.tiktok).idealRange
        #expect(none.request(idea: "x", platform: .tiktok, format: nil).targetRange == ideal)
        let (longer, longerDefaults) = factory { var profile = $0; profile.reach.length = .longer; return profile }
        defer { longerDefaults.tearDown() }
        #expect(longer.request(idea: "x", platform: .tiktok, format: nil).targetRange == ideal)
        let (short, shortDefaults) = factory { var profile = $0; profile.reach.length = .under30; return profile }
        defer { shortDefaults.tearDown() }
        #expect(short.request(idea: "x", platform: .youtube, format: nil).targetRange == TestData.preset(.youtube).idealRange, "long-form keeps its own")
    }

    @Test func aStoryKeepsItsOwnLengthWhateverTheCreatorsOtherVideosAre() {
        let (factory, defaults) = factory { var profile = $0; profile.reach.length = .oneToThree; return profile }
        defer { defaults.tearDown() }
        #expect(factory.request(idea: "x", platform: .stories, format: nil).targetRange == TestData.preset(.stories).idealRange)
        #expect(factory.request(idea: "x", platform: .reels, format: nil).targetRange == 60...180)
    }

    @Test func theUsualLengthIsPartOfTheVoiceSoWithTheVoiceOffItIsIgnored() {
        let (factory, defaults) = factory { var profile = $0; profile.reach.length = .under30; profile.usesVoiceInAI = false; return profile }
        defer { defaults.tearDown() }
        #expect(factory.request(idea: "x", platform: .tiktok, format: nil).targetRange == TestData.preset(.tiktok).idealRange)
    }

    // MARK: - Together

    @Test func everythingTheCreatorGaveReachesOneRequestInOrderOfWhoSaysWhat() throws {
        var profile = VoicePersonas.yogaTeacher.profile
        profile.voiceTopics = [.pets]
        profile.topicDetails = ["fitness": ["Yoga & stretching"]]
        let request = request("How to start a practice", platform: .shorts, format: .tutorial, voice: profile.voice)
        let instructions = ScriptPromptBuilder.instructions(for: request)
        let prompt = ScriptPromptBuilder.prompt(for: request)
        let platform = try #require(instructions.range(of: "Platform: YouTube Shorts")?.lowerBound)
        let voice = try #require(instructions.range(of: "Write in the creator's own voice.")?.lowerBound)
        #expect(platform < voice, "where it is posted comes before who is posting")
        #expect(instructions.contains("Topics: fitness and wellness (Yoga & stretching); pets and animals."))
        #expect(prompt.contains("Write a tutorial script for YouTube Shorts."))
        #expect(prompt.contains("The video: How to start a practice"))
        #expect(instructions.count + prompt.count < 3_500, "a small model's room: \(instructions.count + prompt.count) characters")
    }
}
