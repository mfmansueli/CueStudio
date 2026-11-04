//
//  VoiceRestrictionsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The voice's rules hold everywhere, its style only where it was asked for (the owner's B9, 02/11/2026; `reports/entradas-do-criador-2026-11-01-completo.md`
/// §11, A2 and A4). Measured before (01/11/2026): "Shorter" and "Translate" sent none of the creator's Avoid, and a serious statement dropped the
/// voice whole, "I" or "we" included.
@MainActor
struct VoiceRestrictionsTests {
    private var voice: CreatorVoice {
        var voice = CreatorVoice(sounds: [.casual], phrases: ["Bora lá"], vocabulary: .simple, styles: [])
        voice.avoid = ["Hype words", "não fale de dieta"]
        voice.speaksAs = .we
        voice.style.swearing = .never
        voice.openings = ["Question"]
        return voice
    }

    @Test func theRulesKeepNothingOfTheStyle() {
        let rules = voice.restrictionsOnly
        #expect(rules.avoid == voice.avoid && rules.speaksAs == .we && rules.style.swearing == .never)
        #expect(rules.phrases.isEmpty && rules.sounds.isEmpty && rules.openings.isEmpty && rules.vocabulary == nil)
    }

    @Test func everyToolOtherThanInMyVoiceKeepsTheRulesAndNotTheStyle() {
        let lines = ScriptPromptBuilder.rewriteInstructions(rules: voice.restrictionsOnly)
        #expect(lines.contains("The creator speaks as a team: keep “we” and “our”, never “I”."))
        #expect(lines.contains("Their rules, unless the request asks otherwise in so many words: "))
        #expect(lines.contains("no hype words") || lines.contains("hype"), "\(lines)")
        #expect(lines.contains("não fale de dieta"))
        #expect(lines.contains("Never swear."))
        #expect(!lines.contains("Bora lá"), "a catchphrase is style")
        #expect(lines.contains(ScriptPromptBuilder.editHonestyRule))
    }

    @Test func aTranslationAvoidsTheSameThingsInTheOtherLanguage() {
        let lines = ScriptPromptBuilder.rewriteInstructions(rules: voice.restrictionsOnly, translatingTo: "Spanish")
        #expect(lines.contains("In Spanish, what they avoid includes the same things said in Spanish."))
    }

    @Test func aProfessionalPlatformSaysItsRegisterInsteadOfSwearing() {
        let lines = ScriptPromptBuilder.rewriteInstructions(rules: voice.restrictionsOnly, register: .professional)
        #expect(lines.contains("Keep it professional: no slang, no swearing, no emojis."))
        #expect(!lines.contains("Never swear."))
    }

    @Test func withoutTheVoiceSwitchNoRulesGo() {
        let lines = ScriptPromptBuilder.rewriteInstructions()
        #expect(!lines.contains("Their rules") && !lines.contains("speaks as"))
        #expect(lines.contains(ScriptPromptBuilder.editHonestyRule), "never inventing a result holds for everyone")
    }

    @Test func aSeriousStatementKeepsTheRulesWithoutTheStyle() {
        var request = ScriptRequest(source: .prompt("Our apology for the late orders"), platform: .reels, voice: nil, targetRange: 30...60,
                                    language: .english)
        request.format = .apology
        request.rules = voice.restrictionsOnly
        let instructions = ScriptPromptBuilder.instructions(for: request)
        #expect(instructions.contains(ScriptPromptBuilder.seriousRule))
        #expect(instructions.contains("keep “we” and “our”, never “I”"))
        #expect(instructions.contains("não fale de dieta"))
        #expect(!instructions.contains("Bora lá"))
        let ultra = UltraPayload(request).draft.prompt
        #expect(ultra.contains("The creator's rules (they hold; not a new request):"), "\(ultra)")
    }

    @Test func theFactoryGivesASeriousStatementItsRulesOnly() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.saveVoiceSetup(niches: [.tech], vocabulary: .simple, sounds: [.casual])
        profile.profile.avoid = ["Hype words"]
        profile.profile.speaksAs = .we
        profile.profile.phrases.append("Hey fam")
        let factory = ScriptRequestFactory(profile: profile, scriptLanguage: nil, interfaceLanguage: .english)
        let serious = factory.request(idea: "We are sorry about the delays", platform: .reels, format: .apology)
        #expect(serious.voice == nil, "no style, no voice preview, no voice counted")
        #expect(serious.rules?.avoid == ["Hype words"] && serious.rules?.speaksAs == .we && serious.rules?.phrases.isEmpty == true)
        #expect(factory.request(idea: "Three desk tips", platform: .reels, format: .list).rules == nil, "a draft takes the whole voice")
    }

    @Test func ultrasFitKeepsTheRulesThroughTheCut() {
        let fit = UltraFitRequest(script: "We think this is great.", platform: .tiktok, range: 30...45, voice: voice, language: nil)
        #expect(fit.stage.prompt.contains("The creator's rules (they hold through the cut):"))
        #expect(fit.stage.prompt.contains("keep “we” and “our”"))
    }

    // MARK: - B12 in the draft

    @Test func aFirstPersonStoryMayHaveRoutineNumbersButNoResult() {
        var story = ScriptRequest(source: .prompt("O dia em que eu desisti da dieta"), platform: .tiktok, voice: nil, targetRange: 30...60,
                                  language: .portugueseBrazil)
        #expect(ScriptPromptBuilder.isFirstPersonStory(story))
        #expect(ScriptPromptBuilder.instructions(for: story).contains(ScriptPromptBuilder.storyHonestyRule))
        story.source = .prompt("Três dicas para dormir melhor")
        #expect(!ScriptPromptBuilder.isFirstPersonStory(story))
        #expect(ScriptPromptBuilder.instructions(for: story).contains(ScriptPromptBuilder.honestyRule))
        story.source = .prompt("Minha rotina de manhã em 3 passos")
        story.format = .tutorial
        #expect(!ScriptPromptBuilder.isFirstPersonStory(story), "a tutorial in the first person is advice")
        story.format = .story
        #expect(ScriptPromptBuilder.isFirstPersonStory(story), "the storytime format is a story")
        story.modelRoute = .privateCloud
        #expect(ScriptPromptBuilder.instructions(for: story).contains(ScriptPromptBuilder.resultRule))
    }
}
