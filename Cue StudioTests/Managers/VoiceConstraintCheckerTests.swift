//
//  VoiceConstraintCheckerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The check after a script is written (plan stage 3, item 7): what it catches, and what it leaves alone.
@Suite("Voice constraint checker")
struct VoiceConstraintCheckerTests {
    private func voice(
        avoid: [String] = [], speaksAs: SpeaksAs = .i, openings: [String] = [], phrases: [String] = []
    ) -> CreatorVoice {
        var voice = CreatorVoice(sounds: [], phrases: phrases, vocabulary: nil, styles: [], niches: [])
        voice.avoid = avoid
        voice.speaksAs = speaksAs
        voice.openings = openings
        return voice
    }

    private func kinds(_ text: String, _ voice: CreatorVoice?, language: CueLanguage? = nil, minimum: Int = 0) -> [VoiceViolation.Kind] {
        VoiceConstraintChecker.violations(in: text, voice: voice, language: language, minimumWords: minimum).map(\.kind)
    }

    // MARK: - What they asked never to write

    @Test func aWordOfWhatCueOffersToAvoidIsCaught() {
        #expect(kinds("This is a total game-changer for your mornings.", voice(avoid: ["Hype words"])) == [.avoided])
        #expect(kinds("You won't believe what happened next.", voice(avoid: ["Clickbait"])) == [.avoided])
        #expect(Set(kinds("Act now, this is your last chance.", voice(avoid: ["False urgency"]))) == [.avoided], "one for each phrase")
        #expect(kinds("Honestly, this cures back pain.", voice(avoid: ["Medical claims"])) == [.avoided])
        #expect(kinds("The election changes nothing here.", voice(avoid: ["Politics"])) == [.avoided])
    }

    @Test func aSentenceThatKeepsToTheRuleIsLeftAlone() {
        let calm = "Here is a plain, specific plan for your mornings. Three steps. Nothing fancy."
        #expect(kinds(calm, voice(avoid: ["Hype words", "Clickbait", "False urgency", "Medical claims", "Politics"])).isEmpty)
        #expect(kinds("This is a game-changer.", voice(avoid: [])).isEmpty, "nothing is avoided, so nothing is caught")
    }

    @Test func whatTheCreatorTypedIsLookedForAsTypedInAnyCase() {
        #expect(kinds("It is a get RICH quick scheme.", voice(avoid: ["get rich quick"])) == [.avoided])
        #expect(kinds("Fresh and fast.", voice(avoid: ["get rich quick"])).isEmpty)
    }

    @Test func emojisAreCaughtOnlyWhenTheCreatorWantsNone() {
        let text = "Rise and shine ☀️ today 🔥"
        #expect(kinds(text, voice(avoid: ["Emojis in captions"])) == [.emoji])
        #expect(kinds(text, voice(avoid: [])).isEmpty)
        #expect(kinds("Step 1: breathe. Step 2: stretch #2.", voice(avoid: ["Emojis in captions"])).isEmpty, "digits and hashes are not emojis")
    }

    @Test func theViolationSaysWhatToFixInEnglish() {
        let found = VoiceConstraintChecker.violations(in: "Pure insane energy.", voice: voice(avoid: ["Hype words"]))
        #expect(found.count == 1 && found[0].detail.hasPrefix("It says “insane”: no hype words"))
    }

    // MARK: - I or we

    @Test func aScriptOfWeThatSaysIIsCaught() {
        let text = "I started this company because I wanted better tools. My team and I ship weekly."
        #expect(kinds(text, voice(speaksAs: .we)) == [.pronoun])
        #expect(kinds("We started this company because we wanted better tools. Our team ships weekly.", voice(speaksAs: .we)).isEmpty)
        #expect(kinds("We shipped it. I will show you how.", voice(speaksAs: .we)).isEmpty, "one “I” among “we” is a person speaking for a team")
    }

    @Test func aScriptOfIThatSaysWeIsCaughtOnlyWhenItIsMostlyWe() {
        #expect(kinds("We tried it. We loved it. Our whole family did. We will do it again.", voice(speaksAs: .i)) == [.pronoun])
        #expect(kinds("We all struggle with mornings. I did too, and I found my way. My trick is simple.", voice(speaksAs: .i)).isEmpty)
    }

    @Test func thePronounIsReadInPortugueseAndSpanishToo() {
        #expect(kinds("Eu criei isso. Meu time e eu lançamos toda semana. Meu jeito é simples.", voice(speaksAs: .we), language: .portugueseBrazil) == [.pronoun])
        #expect(kinds("Nosotros lo hicimos. Nuestro equipo lo lanza.", voice(speaksAs: .we), language: .spanish).isEmpty)
        #expect(kinds("Yo lo hice. Mi equipo y yo lo lanzamos.", voice(speaksAs: .we), language: .spanish) == [.pronoun])
    }

    @Test func aLanguageTheCheckerDoesNotReadIsLeftAlone() {
        #expect(kinds("私は毎日これをやっています。私の方法です。", voice(speaksAs: .we), language: .japanese).isEmpty)
    }

    // MARK: - The opening

    @Test func theCatchphraseOpeningAScriptWhoseOpeningIsChosenIsCaught() {
        let withOpening = voice(openings: ["Question"], phrases: ["Hey fam"])
        #expect(kinds("Hey fam! Why do mornings feel like a fight?", withOpening) == [.catchphraseFirst])
        #expect(kinds("[smile] Hey fam, why do mornings feel like a fight?", withOpening) == [.catchphraseFirst])
        #expect(kinds("Why do mornings feel like a fight? Hey fam, here is the fix.", withOpening).isEmpty)
        let free = voice(openings: [], phrases: ["Hey fam"])
        #expect(kinds("Hey fam! Why do mornings feel like a fight?", free).isEmpty, "with no opening chosen the catchphrase may open it")
    }

    @Test func theNameOfAnOpeningStyleWrittenOutIsCaught() {
        let asked = voice(openings: ["Question"])
        #expect(kinds("Question. Why do mornings feel like a fight?", asked) == [.styleName])
        #expect(kinds("Question: why do mornings feel like a fight?", asked) == [.styleName])
        #expect(kinds("Why do mornings feel like a fight? Good question.", asked).isEmpty)
        #expect(kinds("Questions like this one keep me up.", asked).isEmpty, "a word that merely starts with it is fine")
        #expect(kinds("Bold claim. Your mornings aren't broken.", voice(openings: ["Bold claim"])) == [.styleName])
        #expect(kinds("POV: you finally stopped losing your mornings.", voice(openings: ["POV"])).isEmpty, "“POV:” is what that style looks like")
    }

    // MARK: - Length

    @Test func aScriptFarShorterThanAskedIsCaught() {
        let short = Array(repeating: "word", count: 40).joined(separator: " ")
        #expect(kinds(short, nil, minimum: 150) == [.tooShort])
        let enough = Array(repeating: "word", count: 110).joined(separator: " ")
        #expect(kinds(enough, nil, minimum: 150).isEmpty, "110 of 150 words is 73%: short, but not a failure to write it")
        #expect(kinds("[pause] " + short, nil, minimum: 150) == [.tooShort], "stage cues are not words")
        #expect(kinds(short, nil, minimum: 0).isEmpty)
    }

    @Test func noVoiceMeansOnlyTheLengthIsChecked() {
        #expect(kinds("This is a game-changer. I love it.", nil, minimum: 3).isEmpty)
    }

    @Test func anEmptyScriptHasNothingToCheck() {
        #expect(kinds("   ", voice(avoid: ["Hype words"]), minimum: 100).isEmpty)
    }

    // MARK: - What the baseline measured

    @Test func theScriptsTheModelWroteBeforeV2ShowedWhatTheCheckerIsFor() throws {
        // `Fixtures/VoiceRuns/before.json` was written by the model on an iPhone before this engine: with the voice on, nearly every script started with
        // the name of the opening style or with the catchphrase. The checker must see that in the scripts it will be handed.
        let samples = try VoiceRunFixture.samples("before").filter { $0.condition == "voice" && $0.wasWritten }
        #expect(samples.count >= 30, "the baseline has the voiced scripts")
        var caught = 0
        for sample in samples {
            guard let persona = VoicePersonas.persona(sample.persona), let text = sample.text else { continue }
            let found = VoiceConstraintChecker.violations(in: text, voice: persona.profile.voice, language: persona.language)
            if found.contains(where: { $0.kind == .styleName || $0.kind == .catchphraseFirst }) { caught += 1 }
        }
        #expect(caught >= samples.count / 2, "\(caught) of \(samples.count) voiced scripts open with a style's name or the catchphrase")
    }
}
