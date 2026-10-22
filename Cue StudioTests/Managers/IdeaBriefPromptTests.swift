//
//  IdeaBriefPromptTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Find inspiration's ideas as the model is asked for them and as they come back (`IdeaBriefReader`), and a script asked from one: it follows the
/// angle and opens with the line, without a hook of its own and without the checker taking the line for a catchphrase.
@Suite("Idea briefs · prompts")
struct IdeaBriefPromptTests {
    private let topics = [
        IdeaTopic(name: "Daily Routine", label: "Daily Routine", niche: nil, subtopics: ["Bureaucracy"]),
        IdeaTopic(name: Niche.finance.promptName, label: Niche.finance.label, niche: .finance),
    ]

    // MARK: - Asking

    @Test func briefsAreAskedAsATitleAnAngleAndAnOpeningLineThatAreOneIdea() {
        let slots = IdeaTaste().slots(round: 0, among: topics)
        let prompt = ScriptPromptBuilder.themesPrompt(slots: slots, language: .german, asBriefs: true)
        #expect(prompt.contains("a title of at most eight words"))
        #expect(prompt.contains("an angle, one short sentence"))
        #expect(prompt.contains("an opening line"))
        #expect(prompt.contains("1. \(slots[0].angle.ask) about \(slots[0].topic.name)"))
        #expect(prompt.contains(ScriptPromptBuilder.openingHonestyRule), "nothing invented is put in the creator's mouth")
        #expect(prompt.hasSuffix("Write the ideas in German."))
        #expect(!prompt.contains("names its topic"), "the slot says the topic; the model is not asked for it")
    }

    @Test func aBatchOfBriefsCostsLittleOfTheModelsWindow() {
        let slots = IdeaTaste().slots(round: 0, among: topics)
        let briefs = ScriptPromptBuilder.themesPrompt(slots: slots, inspiration: ["Why Italian forms take three tries"], asBriefs: true)
        let titles = ScriptPromptBuilder.themesPrompt(slots: slots, inspiration: ["Why Italian forms take three tries"])
        let instructions = ScriptPromptBuilder.themesInstructions()
        // English characters ≈ 0.21 tokens each (`PromptCost`): a few hundred tokens of a 4096 window.
        let cost = PromptCost.units(of: briefs + instructions)
        print("IDEAS prompt: briefs \(PromptCost.units(of: briefs)) units, titles \(PromptCost.units(of: titles)) units")
        #expect(cost < 1_500, "\(cost)")
        #expect(PromptCost.units(of: briefs) - PromptCost.units(of: titles) < 450)
    }

    // MARK: - Reading

    @Test func anAnswerBecomesAnIdeaOfItsSlotWithItsBrief() throws {
        let slot = IdeaSlot(angle: .myth, topic: topics[0])
        let answer = IdeaBriefReader.Answer(
            title: "**Bureaucracy myths that waste your morning**", angle: "Angle: Bust two myths about filling forms.",
            openingLine: "Opening line: “You don’t need three tries to fill a form.”"
        )
        let idea = try #require(IdeaBriefReader.idea(from: answer, slot: slot, language: "en"))
        #expect(idea.title == "Bureaucracy myths that waste your morning")
        #expect(idea.kind == IdeaAngle.myth.kind && idea.angle == "myth" && idea.topic == "Daily Routine")
        let brief = try #require(idea.brief)
        #expect(brief.subject == idea.title)
        #expect(brief.angle == "Bust two myths about filling forms.")
        #expect(brief.openingLine == "You don’t need three tries to fill a form.")
        #expect(brief.subtopic == "Bureaucracy")
        #expect(brief.angleKind == "myth" && brief.topicKey == "Daily Routine" && brief.language == "en")
    }

    @Test func anIdeaComesBackWithoutDashesAndItsLabelsStillGo() throws {
        let slot = IdeaSlot(angle: .myth, topic: topics[1])
        let answer = IdeaBriefReader.Answer(
            title: "Saving — the easy way", angle: "Angle — Explain one habit that makes saving easier.",
            openingLine: "Opening line: Saving isn't willpower — it's what you automate."
        )
        let idea = try #require(IdeaBriefReader.idea(from: answer, slot: slot, language: "en"))
        let brief = try #require(idea.brief)
        #expect(idea.title == "Saving: the easy way")
        #expect(brief.angle == "Explain one habit that makes saving easier.")
        #expect(brief.openingLine == "Saving isn't willpower. It's what you automate.")
        let french = try #require(IdeaBriefReader.idea(
            from: .init(title: "Épargner", angle: "Angle — Expliquez une habitude.", openingLine: "Épargner — c’est automatiser."), slot: slot, language: "fr"
        ))
        #expect(french.brief?.angle == "Expliquez une habitude.", "the label goes even with French spacing before the colon")
    }

    @Test func anIdeaKeptByAnOlderVersionLosesItsDashes() {
        var idea = ThemeIdea(title: "Saving — the easy way", kind: "Myth", length: .minute1, niche: .finance)
        idea.brief = IdeaBrief(
            subject: "Saving — the easy way", angle: "Explain one habit — the one that sticks.",
            openingLine: "Saving isn't willpower — it's what you automate.", subtopic: nil, language: "en", angleKind: "myth", topicKey: "finance"
        )
        let clean = IdeaBriefReader.withoutDashes(idea)
        #expect(clean.title == "Saving: the easy way" && clean.brief?.subject == "Saving: the easy way")
        #expect(clean.brief?.angle == "Explain one habit. The one that sticks.")
        #expect(clean.brief?.openingLine == "Saving isn't willpower. It's what you automate.")
    }

    @Test func aFirstFlightTopicIsKeptByItsNiche() throws {
        let slot = IdeaSlot(angle: .list, topic: topics[1])
        let idea = try #require(IdeaBriefReader.idea(
            from: .init(title: "Three apps for saving", angle: "List them.", openingLine: "Here are three."), slot: slot, language: nil
        ))
        #expect(idea.niche == .finance && idea.topic == nil && idea.brief?.topicKey == "finance")
        #expect(IdeaTopicFilter.topic(topics[1]).includes(idea) && !IdeaTopicFilter.topic(topics[0]).includes(idea))
    }

    @Test func anAnswerWithoutATitleOrALineIsNoIdea() {
        let slot = IdeaSlot(angle: .list, topic: topics[1])
        #expect(IdeaBriefReader.idea(from: .init(title: " ", angle: "A.", openingLine: "O."), slot: slot, language: nil) == nil)
        #expect(IdeaBriefReader.idea(from: .init(title: "T", angle: "A.", openingLine: "\"\""), slot: slot, language: nil) == nil)
    }

    @Test func aLongAnswerIsFittedToTheFieldAtAWord() throws {
        let slot = IdeaSlot(angle: .story, topic: topics[1])
        let answer = IdeaBriefReader.Answer(
            title: "Why your savings plan keeps failing every single month",
            angle: "Walk through the three hidden reasons savings plans fail and give one simple fix for each of them, step by step.",
            openingLine: "Most savings plans don’t fail because of willpower, they fail because of how they are built. Let’s fix yours today, together."
        )
        let idea = try #require(IdeaBriefReader.idea(from: answer, slot: slot, language: "en"))
        #expect((idea.brief?.composerText.count ?? 999) <= IdeaPromptDraft.maxCharacters)
        #expect(idea.length == .minutes2, "a story takes longer")
    }

    // MARK: - A script from a brief

    private func request(brief: IdeaBrief?, voice: CreatorVoice? = nil) -> ScriptRequest {
        ScriptRequest(
            source: .prompt(brief?.composerText ?? "Why saving feels harder than spending"), platform: .tiktok, tone: nil, voice: voice,
            targetRange: 60...90, brief: brief
        )
    }

    private let brief = IdeaBrief(
        subject: "Why saving feels harder than spending", angle: "Explain one small habit that makes saving easier.",
        openingLine: "Saving isn’t just about willpower."
    )

    @Test func theScriptOpensWithTheLineAndFollowsTheAngleInsteadOfAHookOfItsOwn() {
        let prompt = ScriptPromptBuilder.prompt(for: request(brief: brief))
        #expect(prompt.contains("Open with this line, as it is or adapted only to the creator's way of speaking: “Saving isn’t just about willpower.”"))
        #expect(!prompt.contains("Open with a hook that works in the first 3 seconds"))
        #expect(prompt.contains("Follow this angle all the way through: Explain one small habit that makes saving easier."))
    }

    @Test func withoutABriefTheRequestIsWhatItWas() {
        let prompt = ScriptPromptBuilder.prompt(for: request(brief: nil))
        #expect(prompt.contains("Open with a hook that works in the first 3 seconds."))
        #expect(!prompt.contains("Open with this line") && !prompt.contains("Follow this angle"))
    }

    @Test func whatTheCreatorRemovedIsNotAskedFor() {
        var partial = brief
        partial.angle = ""
        partial.openingLine = ""
        let prompt = ScriptPromptBuilder.prompt(for: request(brief: partial))
        #expect(prompt.contains("Open with a hook that works in the first 3 seconds."))
        #expect(!prompt.contains("Follow this angle"))
    }

    @Test func theCheckerLetsTheScriptOpenWithTheLineItWasGiven() {
        let voice = CreatorProfile(phrases: ["Saving isn’t just"], openings: ["Question"]).voice
        let script = "Saving isn’t just about willpower. [pause]\n\nHere is one habit.\n\nTry it this week."
        let without = VoiceConstraintChecker.violations(in: script, voice: voice)
        #expect(without.contains { $0.kind == .catchphraseFirst }, "the line starts like the catchphrase")
        let with = VoiceConstraintChecker.violations(in: script, voice: voice, openingLine: brief.openingLine)
        #expect(!with.contains { $0.kind == .catchphraseFirst || $0.kind == .styleName })
        let other = VoiceConstraintChecker.violations(in: script, voice: voice, openingLine: "Here is something else entirely.")
        #expect(other.contains { $0.kind == .catchphraseFirst }, "only the line it was given is let through")
    }
}
