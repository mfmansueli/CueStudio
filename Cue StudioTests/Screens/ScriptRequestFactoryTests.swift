//
//  ScriptRequestFactoryTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// How an idea becomes a request: the platform, the length, the voice, the format and the language.
@MainActor
@Suite("Script request factory")
struct ScriptRequestFactoryTests {
    private func makeFactory(
        scriptLanguage: CueLanguage? = nil, voiceSetUp: Bool = true, defaults: TestDefaults
    ) -> (ScriptRequestFactory, CreatorProfileService) {
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.addPhrase("Hey fam")
        if voiceSetUp { profile.saveVoiceSetup(niches: [.tech], vocabulary: .simple, sounds: [.casual]) }
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: profile, scriptLanguage: scriptLanguage, interfaceLanguage: .english
        )
        return (factory, profile)
    }

    @Test func theIdeaIsTheVideoAndTheVoiceComesAlong() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (factory, _) = makeFactory(defaults: defaults)
        let request = factory.request(idea: "  Why I quit coffee  ", platform: .reels, format: nil)
        #expect(request.source == .prompt("Why I quit coffee"))
        #expect(request.platform == .reels)
        #expect(request.voice?.phrases == ["Hey fam"])
        #expect(request.type == nil)
    }

    @Test func withoutAChosenPlatformItIsTheCreatorsDefaultOrTikTok() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (factory, profile) = makeFactory(defaults: defaults)
        #expect(factory.request(idea: "x", platform: nil, format: nil).platform == profile.profile.defaultPlatform)
        profile.profile.defaultPlatform = .stories
        // Stories isn't a platform the card offers by default: it falls back to TikTok.
        #expect(factory.defaultPlatform == .tiktok)
    }

    @Test func theVoiceIsNeverAppliedFromTheDefaultsOfANewProfileOrWhenOff() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (fresh, _) = makeFactory(voiceSetUp: false, defaults: defaults)
        #expect(fresh.request(idea: "x", platform: nil, format: nil).voice == nil)
        let (set, profile) = makeFactory(defaults: defaults)
        profile.setWritesInMyVoice(false)
        #expect(set.request(idea: "x", platform: nil, format: nil).voice == nil)
    }

    @Test func aSeriousFormatNeverUsesTheVoiceAndTheFormatRidesInTheRequest() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (factory, _) = makeFactory(defaults: defaults)
        let apology = factory.request(idea: "Last week's video", platform: nil, format: .apology)
        #expect(apology.voice == nil)
        #expect(apology.type == .apology && apology.structure.isSerious)
        let review = factory.request(idea: "A lamp", platform: nil, format: .review)
        #expect(review.voice != nil)
        #expect(review.type == .review)
        #expect(ScriptPromptBuilder.prompt(for: review).contains("review"))
    }

    @Test func twoMinutesAimsForAboutThreeHundredWords() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (factory, _) = makeFactory(defaults: defaults)
        let request = factory.request(idea: "x", platform: .youtube, format: nil, length: .minutes2)
        #expect(request.targetRange == 108...132)
    }

    @Test func autoLengthReadsThePromptOrFollowsThePlatformsIdealRange() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (factory, _) = makeFactory(defaults: defaults)
        let detected = factory.request(idea: "a 30-second video about tea", platform: .tiktok, format: nil)
        #expect(detected.targetRange == 27...33)
        let preset = TestData.rulesService().preset(for: .shorts, monetizationGoals: factory.profile.profile.monetizationGoals)
        #expect(factory.request(idea: "tea", platform: .shorts, format: nil).targetRange == preset.idealRange)
    }

    @Test func theScriptLanguageWinsThenWhatWasTypedThenTheInterface() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (fixed, _) = makeFactory(scriptLanguage: .portugueseBrazil, defaults: defaults)
        #expect(fixed.request(idea: "Why I quit coffee for thirty days", platform: nil, format: nil).language == .portugueseBrazil)
        let (auto, _) = makeFactory(defaults: defaults)
        #expect(auto.request(idea: "Por que eu parei de tomar café por trinta dias", platform: nil, format: nil).language == .portugueseBrazil)
        #expect(auto.request(idea: "Café", platform: nil, format: nil).language == .english)
    }

    // MARK: - Regional variants

    private func makeFactory(
        scriptLanguage: CueLanguage? = nil, interface: CueLanguage? = .english, preferred: [String], defaults: TestDefaults
    ) -> ScriptRequestFactory {
        ScriptRequestFactory(
            rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults),
            scriptLanguage: scriptLanguage, interfaceLanguage: interface, preferredLanguages: preferred
        )
    }

    /// An idea read as English on an iPhone set to British English is written in British English.
    @Test func aLanguageReadFromTheIdeaKeepsTheCreatorsOwnVariant() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let factory = makeFactory(preferred: ["en-GB", "it-IT"], defaults: defaults)
        let request = factory.request(idea: "Why I quit coffee for thirty days", platform: nil, format: nil)
        #expect(request.language == .english)
        #expect(request.languageVariant?.identifier(.bcp47) == "en-GB")
        #expect(ScriptPromptBuilder.instructions(for: request).contains("English (United Kingdom)"))
    }

    @Test func europeanPortugueseIsKeptWhenOnlyTheLanguageWasRead() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let factory = makeFactory(preferred: ["pt-PT"], defaults: defaults)
        let request = factory.request(idea: "Por que eu parei de tomar café por trinta dias", platform: nil, format: nil)
        #expect(request.language == .portugueseBrazil)
        #expect(request.languageVariant?.identifier(.bcp47) == "pt-PT")
        #expect(ScriptPromptBuilder.instructions(for: request).contains("Portuguese (Portugal)"))
    }

    /// A language picked in Language & Region is the creator's choice: never refined into a variant they didn't pick.
    @Test func aChosenScriptLanguageIsNeverRefined() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let factory = makeFactory(scriptLanguage: .portugueseBrazil, preferred: ["pt-PT", "en-GB"], defaults: defaults)
        let request = factory.request(idea: "Por que eu parei de tomar café", platform: nil, format: nil)
        #expect(request.language == .portugueseBrazil && request.languageVariant == nil)
        #expect(ScriptPromptBuilder.instructions(for: request).contains("Portuguese (Brazil)"))
        let english = makeFactory(scriptLanguage: .english, preferred: ["en-GB"], defaults: defaults)
        #expect(english.request(idea: "Why I quit coffee for thirty days", platform: nil, format: nil).languageVariant == nil)
    }

    /// The country the iPhone is set to says nothing about who the script is for.
    @Test func noVariantComesFromAnIPhoneWithoutOneInItsLanguages() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let factory = makeFactory(preferred: ["it-IT"], defaults: defaults)
        let request = factory.request(idea: "Why I quit coffee for thirty days", platform: nil, format: nil)
        #expect(request.language == .english && request.languageVariant == nil)
        #expect(ScriptPromptBuilder.languageRule(.english) == "Write the title and every block in English.")
    }

    @Test func theInterfaceLanguageGetsTheCreatorsVariantToo() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let factory = makeFactory(interface: .spanish, preferred: ["es-MX"], defaults: defaults)
        let request = factory.request(idea: "Café", platform: nil, format: nil)
        #expect(request.language == .spanish && request.languageVariant?.identifier(.bcp47) == "es-MX")
    }

    @Test func aTraditionalIdeaIsWrittenInTraditionalChinese() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let factory = makeFactory(preferred: ["en-US"], defaults: defaults)
        let request = factory.request(idea: "為什麼我三十天不喝咖啡，改變了我的早晨。", platform: nil, format: nil)
        #expect(request.language == .chineseTraditional)
    }
}
