//
//  VoiceBriefBuilderTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The voice as the AI reads it (plan stage 3): the order of the pieces, what is known and what isn't, the rules in the positive and the
/// negative, the contradictions gone, and the 1200-character budget with its cutting order.
@Suite("Voice brief")
struct VoiceBriefBuilderTests {
    private func brief(_ voice: CreatorVoice) -> String { VoiceBriefBuilder.brief(for: voice).text }

    private let yoga = VoicePersonas.yogaTeacher.profile.voice

    // MARK: - What is in it

    @Test func aVoiceWithNothingAnsweredIsEmptyAndNeverJustTheHeader() {
        let empty = VoiceBriefBuilder.brief(for: CreatorProfile().voice)
        #expect(empty.isEmpty && empty.lines.isEmpty && empty.closingRules.isEmpty)
    }

    @Test func theDefaultsOfANewProfileAreNeverSent() {
        // The default tones and vocabulary are not the creator's answers; only the topic is.
        let profile = CreatorProfile(niches: [.tech])
        let text = brief(profile.voice)
        #expect(text.contains("Topics: tech and AI."))
        #expect(!text.contains("They sound"))
        #expect(!text.contains("audience"))
    }

    @Test func theOrderIsWhoIsTalkingThenWhoIsWatchingThenTopicsThenVoiceThenOpeningsThenRules() throws {
        let text = brief(yoga)
        let order = [
            "Write in the creator's own voice.", "Who they are:", "They are new to the topic", "Topics:", "They sound", "Delivery:",
            "Open with", "End by", "Rules:",
        ]
        let positions = try order.map { marker in try #require(text.range(of: marker)?.lowerBound, "\(marker)") }
        #expect(positions == positions.sorted())
        #expect(text.hasSuffix("."), "the rules close the brief")
    }

    @Test func theRulesComeLastEvenWithExamples() throws {
        var profile = VoicePersonas.saasFounder.profile
        profile.examples = [VoiceExample(text: "We ship every Friday and we tell you what broke.")]
        let text = brief(profile.voice)
        let examples = try #require(text.range(of: "Here is how they write")?.lowerBound)
        let rules = try #require(text.range(of: "Rules:")?.lowerBound)
        #expect(examples < rules)
    }

    @Test func topicsAreNamedInFullWithTheirSubtopicsAndTheTypedOnesAsTyped() {
        let profile = CreatorProfile(
            niches: [.travel, .lifestyle], customTopics: ["Van life"], topicDetails: ["travel": ["Cheap flights", "Solo travel"]]
        )
        let text = brief(profile.voice)
        #expect(text.contains("Topics: budget travel (Cheap flights, Solo travel); morning routines and daily life; Van life."))
    }

    @Test func aTopicOnlyTheVoiceOffersIsToldToo() {
        #expect(brief(CreatorProfile(voiceTopics: [.realEstate]).voice).contains("Topics: real estate."))
    }

    @Test func whoIsTalkingFollowsTheCreatorsChoiceThenTheKind() {
        #expect(brief(CreatorProfile(niches: [.tech], role: .business).voice).contains("say “we” and “our”, never “I”"))
        #expect(brief(CreatorProfile(niches: [.tech], role: .brands, speaksAs: .i).voice).contains("say “I” and “my”"))
        #expect(brief(CreatorProfile(niches: [.tech], customRole: "Chess coach").voice).contains("Who they are: Chess coach."))
        #expect(brief(CreatorProfile(niches: [.tech], role: .expert, credential: "Registered nurse").voice)
            .contains("Credential: Registered nurse. Mention it only where it fits; never invent another."))
    }

    @Test func theAudienceIsTheNoteOrTheGroupAndTheVocabularyOnlyWhenNothingBetterIsKnown() {
        let base = CreatorProfile(niches: [.tech], vocabulary: .genZ, confirmedVoiceSteps: [.audience])
        #expect(brief(base.voice).contains("Their audience is young"))
        var group = base
        group.audienceGroup = .parents
        #expect(brief(group.voice).contains("Their audience: parents."))
        #expect(!brief(group.voice).contains("young"))
        var note = group
        note.audienceNote = "Nurses on night shifts"
        #expect(brief(note.voice).contains("Their audience: Nurses on night shifts."))
        var words = base
        words.style.words = .expertTerms
        #expect(!brief(words.voice).contains("Their audience is young"), "the words the creator chose say it better")
    }

    @Test func whyTheyWatchAndWhatTheVideosAreForAreTold() {
        let profile = CreatorProfile(niches: [.tech], watchReasons: [.learn, .feelUnderstood], contentGoals: [.teach, .winClients])
        let text = brief(profile.voice)
        #expect(text.contains("They watch to learn something and feel understood."))
        #expect(text.contains("Their videos aim to teach something useful and win new clients."))
    }

    // MARK: - The contradictions

    @Test func theLegacyDefaultStylesAreNeverSentAlone() {
        let text = brief(CreatorProfile(niches: [.tech]).voice)
        #expect(!text.contains("Style:") && !text.contains("short sentences"))
        let storyteller = CreatorProfile(niches: [.tech], styles: [.shortSentences, .storytelling, .opinionDriven])
        #expect(brief(storyteller.voice).contains("Style: storytelling, opinionated."))
    }

    @Test func theChoiceOfShortOrLongSentencesBeatsTheBaseRule() {
        func instructions(_ sentences: SentenceLength?) -> String {
            var voice = CreatorVoice(sounds: [], phrases: [], vocabulary: nil, styles: [], niches: [])
            voice.style.sentences = sentences
            let request = ScriptRequest(source: .prompt("x"), platform: .tiktok, tone: nil, voice: voice, targetRange: 30...45)
            return ScriptPromptBuilder.instructions(for: request)
        }
        #expect(instructions(nil).contains("natural spoken language with short sentences."))
        #expect(instructions(.short).contains("natural spoken language with short sentences."))
        #expect(instructions(.mixed).contains("a mix of short and longer sentences."))
        let long = instructions(.long)
        #expect(long.contains("natural spoken language with longer, flowing sentences."))
        #expect(!long.contains("with short sentences"))
    }

    @Test func aCatchphraseIsForTheOpeningOnlyWhenTheCreatorChoseNoOpening() {
        var profile = CreatorProfile(niches: [.tech], phrases: ["Hey fam"])
        #expect(brief(profile.voice).contains("— use one naturally, ideally in the opening."))
        profile.openings = ["Question"]
        let text = brief(profile.voice)
        #expect(text.contains("— use one once after the first sentence, never as the first words."))
        #expect(!text.contains("ideally in the opening"))
    }

    @Test func anOpeningStyleIsShownInTheScriptAndItsNameIsNeverWritten() {
        let text = brief(CreatorProfile(niches: [.tech], openings: ["Question", "Bold claim"]).voice)
        #expect(text.contains("Open with a question or a bold claim: show it in the script, never write the style's name."))
        let rule = ScriptPromptBuilder.hookRule(for: CreatorProfile(openings: ["Question"]).voice)
        #expect(rule.contains("in the creator's own way of opening"))
        #expect(ScriptPromptBuilder.hookRule(for: nil) == "Open with a hook that works in the first 3 seconds.")
    }

    @Test func anEndingIsAskedForInPlainEnglishAndWhatTheCreatorTypedIsQuoted() {
        let text = brief(CreatorProfile(niches: [.tech], endings: ["Save this", "See you Sunday"]).voice)
        #expect(text.contains("End by asking viewers to save the video or saying “See you Sunday”."))
    }

    @Test func anOpeningPickedInAnotherLanguageIsRecognizedAndATypedOneIsNot() {
        #expect(VoiceChoiceCatalog.opening("Question") == .known(id: "Question", guidance: "a question"))
        #expect(VoiceChoiceCatalog.opening("my own way") == .typed("my own way"))
        // What the interface says for it in any language the app has is the same opening.
        let translations = VoiceChoiceCatalog.translations(of: "Question")
        #expect(translations.contains("question") && translations.count > 1, "the app has “Question” in more than one language")
        for text in translations {
            #expect(VoiceChoiceCatalog.opening(text) == .known(id: "Question", guidance: "a question"), "“\(text)”")
        }
    }

    // MARK: - Rules in the positive and the negative

    @Test func eachThingToAvoidSaysWhatNotToDoAndWhatToDoInstead() {
        let text = brief(CreatorProfile(niches: [.tech], avoid: ["Hype words", "Clickbait", "Naming competitors", "get rich quick"]).voice)
        #expect(text.contains("no hype words (game-changer, insane, mind-blowing, unbelievable): use plain, specific words"))
        #expect(text.contains("no clickbait (“you won't believe…”, “what happens next”): say the real point up front"))
        #expect(text.contains("never name competitors or rival brands"))
        #expect(text.contains("never write “get rich quick”"), "what the creator typed is told as typed")
    }

    @Test func theRulesAreSaidAgainAtTheEndOfTheRequest() {
        let request = ScriptRequest(
            source: .prompt("Why we killed a feature"), platform: .tiktok, tone: nil, voice: VoicePersonas.saasFounder.profile.voice, targetRange: 30...45
        )
        let prompt = ScriptPromptBuilder.prompt(for: request)
        let last = prompt.components(separatedBy: "\n").last ?? ""
        #expect(last.hasPrefix("Remember: Say “we”, never “I”."))
        #expect(last.contains("Avoid: hype words, clickbait."))
        #expect(last.contains("Never write the name of an opening style or open with a catchphrase."))
        let plain = ScriptRequest(source: .prompt("x"), platform: .tiktok, tone: nil, voice: nil, targetRange: 30...45)
        #expect(!ScriptPromptBuilder.prompt(for: plain).contains("Remember:"))
    }

    @Test func aSeriousFormatNeverGetsTheVoice() {
        let request = ScriptRequest(
            source: .prompt("I'm sorry"), platform: .tiktok, tone: nil, voice: yoga, targetRange: 30...45, format: .apology
        )
        let instructions = ScriptPromptBuilder.instructions(for: request)
        #expect(!instructions.contains("creator's own voice") && !instructions.contains("Topics:"))
        #expect(!ScriptPromptBuilder.prompt(for: request).contains("Remember:"))
    }

    @Test func theCorrectionNamesWhatTheLastDraftGotWrong() {
        let note = ScriptPromptBuilder.correctionNote(for: [
            VoiceViolation(kind: .avoided, detail: "It says “insane”."), VoiceViolation(kind: .tooShort, detail: "It has only 40 words."),
        ])
        #expect(note == "Your last draft broke these rules: It says “insane”. It has only 40 words. Write the whole script again and follow them.")
    }

    // MARK: - The budget

    private func crowded() -> CreatorVoice {
        var profile = VoicePersonas.saasFounder.profile
        profile.customTags = ["Talking head", "Always shows the dashboard", "Drinks too much coffee", "Left-handed", "Bilingual at home"]
        profile.reach = VoiceReach(platforms: [.tiktok, .reels, .shorts], length: .thirtyToSixty, humor: .little)
        profile.examples = (1...3).map { VoiceExample(text: String(repeating: "Example \($0) of how I sound. ", count: 10)) }
        return profile.voice
    }

    @Test func aVoiceThatFitsIsSentWholeAndMeasuredByTheSameText() {
        let small = VoiceBriefBuilder.brief(for: yoga)
        #expect(small.trimmed.isEmpty && !small.isLong && small.text == small.fullText)
        #expect(small.length == small.text.count && small.cost <= VoiceBrief.budget)
    }

    @Test func aLongVoiceIsCutToTheBudgetExamplesFirst() {
        let voice = crowded()
        // The app's budget is larger than this voice; the cut is checked against a smaller one.
        let budget = 1200
        let full = VoiceBriefBuilder.brief(for: voice, budget: 100_000)
        #expect(full.fullCost > budget, "the test voice is long on purpose")
        let brief = VoiceBriefBuilder.brief(for: voice, budget: budget)
        #expect(brief.cost <= budget)
        #expect(brief.fullLength == full.fullLength && brief.fullCost > budget)
        #expect(brief.trimmed.first == .examples, "the examples go first")
        #expect(brief.text.contains("Rules:"), "the rules are what stays")
    }

    @Test func theBudgetHoldsTheWholeOfAFullVoice() {
        let brief = VoiceBriefBuilder.brief(for: crowded())
        #expect(brief.trimmed.isEmpty && !brief.isLong, "a creator with everything filled in loses none of it")
        #expect(brief.cost <= VoiceBrief.budget)
    }

    @Test func theTagsGoAfterTheExamplesAndTheReachAfterTheTags() {
        var voice = crowded()
        let squeezed = VoiceBriefBuilder.brief(for: voice, budget: 700)
        #expect(squeezed.trimmed == [.examples, .tags, .reach] || squeezed.trimmed == [.examples, .tags], "\(squeezed.trimmed)")
        #expect(!squeezed.text.contains("Also true of them"))
        voice.customTags = []
        voice.reach = VoiceReach()
        #expect(VoiceBriefBuilder.brief(for: voice, budget: 100_000).trimmed.isEmpty)
    }

    @Test func examplesAreShortenedAtAWordBeforeTheyAreDropped() {
        var profile = VoicePersonas.yogaTeacher.profile
        profile.examples = [VoiceExample(text: String(repeating: "Okay real talk mornings are hard. ", count: 9))]
        let voice = profile.voice
        let roomy = VoiceBriefBuilder.brief(for: voice, budget: VoiceBriefBuilder.brief(for: voice, budget: 100_000).fullCost - 40)
        #expect(roomy.trimmed == [.examples])
        #expect(roomy.text.contains("…”"), "the example is cut, with an ellipsis")
        #expect(roomy.cost <= roomy.fullCost - 40)
        let none = VoiceBriefBuilder.brief(for: voice, budget: VoiceBriefBuilder.brief(for: CreatorVoice.withoutExamples(voice), budget: 100_000).cost + 20)
        #expect(!none.text.contains("Here is how they write"))
    }

    @Test func approvedScriptsJoinThePastedExamplesNewestFirst() {
        var profile = VoicePersonas.yogaTeacher.profile
        profile.examples = [VoiceExample(text: "Pasted by me: breathe in and let the shoulders drop.")]
        profile.approvedSamples = [
            VoiceExample(text: "Older approved sample about slow mornings."), VoiceExample(text: "Newer approved sample about stretching."),
        ]
        let text = brief(profile.voice)
        let lines = text.components(separatedBy: "\n").filter { $0.hasPrefix("- “") }
        #expect(lines.count == 3)
        #expect(lines[0].contains("Pasted by me") && lines[1].contains("Newer approved") && lines[2].contains("Older approved"))
    }

    @Test func atMostThreeExamplesAreSent() {
        var profile = VoicePersonas.yogaTeacher.profile
        profile.examples = (1...3).map { VoiceExample(text: "Example number \($0) of how the creator really writes things.") }
        profile.approvedSamples = [VoiceExample(text: "An approved script that comes after the three pasted examples.")]
        #expect(brief(profile.voice).components(separatedBy: "\n").filter { $0.hasPrefix("- “") }.count == 3)
    }

    @Test func everythingTheAIReadsIsEnglishWhateverTheCreatorsLanguageIs() {
        for persona in VoicePersonas.all {
            let text = brief(persona.profile.voice)
            // The creator's own words (a catchphrase, a typed topic) are the only things that may not be English; the personas'
            // are, so anything non-ASCII except the typographic quotes and dashes would be an interface-language label leaking.
            #expect(text.unicodeScalars.allSatisfy { $0.isASCII || "“”’—…‑¡¿".unicodeScalars.contains($0) }, "\(persona.id)")
        }
    }

    @Test func everyPersonaFitsTheBudgetWithRoomForTheIdea() {
        for persona in VoicePersonas.all + VoicePersonas.languageVariants {
            let brief = VoiceBriefBuilder.brief(for: persona.profile.voice)
            #expect(brief.cost <= VoiceBrief.budget && !brief.isEmpty, "\(persona.id): \(brief.cost)")
        }
    }
}

private extension CreatorVoice {
    /// The same voice with no examples, to measure what is left.
    static func withoutExamples(_ voice: CreatorVoice) -> CreatorVoice {
        var copy = voice
        copy.examples = []
        copy.approvedSamples = []
        return copy
    }
}
