//
//  RevisionChoiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Which of two drafts the creator gets (`RevisionChoice`): the second only when what it breaks is less serious and it lost nothing that made the
/// first worth having.
@Suite("Revision choice")
struct RevisionChoiceTests {
    private static let body = "Warm up your hips first. Then open your chest slowly. Breathe out on every stretch. Save this for your next workout."

    private static func request(brief: IdeaBrief? = nil, idea: String = "A warm-up for home workouts") -> ScriptRequest {
        ScriptRequest(
            source: .prompt(idea), platform: .tiktok, tone: nil, voice: nil, targetRange: 30...45, language: .english, brief: brief
        )
    }

    private static func assess(_ text: String, _ kinds: [VoiceViolation.Kind] = [], request: ScriptRequest = request()) -> DraftAssessment {
        DraftAssessment(text: text, violations: kinds.map { VoiceViolation(kind: $0, detail: "") }, request: request)
    }

    @Test func aRevisionThatIsLessSeriousAndLosesNothingIsTaken() {
        let verdict = RevisionChoice.verdict(original: Self.assess(Self.body, [.avoided]), revision: Self.assess(Self.body))
        #expect(verdict == .revision)
    }

    @Test func asManyViolationsOfALighterKindIsBetter() {
        // One word they asked never to say becomes a catchphrase said too early: the same count, a lighter one.
        let verdict = RevisionChoice.verdict(original: Self.assess(Self.body, [.avoided]), revision: Self.assess(Self.body, [.catchphraseFirst]))
        #expect(verdict == .revision)
    }

    @Test func fewerViolationsOfAHeavierKindIsNot() {
        // Two slips (catchphrases too early) traded for one forbidden word: fewer, and worse.
        let verdict = RevisionChoice.verdict(
            original: Self.assess(Self.body, [.catchphraseFirst, .catchphraseFirst]), revision: Self.assess(Self.body, [.avoided])
        )
        #expect(verdict == .notBetter)
    }

    @Test func asSeriousIsNotBetter() {
        let verdict = RevisionChoice.verdict(original: Self.assess(Self.body, [.pronoun]), revision: Self.assess(Self.body, [.emoji]))
        #expect(verdict == .notBetter, "the old rule took a draft that was merely no worse")
    }

    @Test func whatIsOnlyCountedNeverMakesARevisionBetter() {
        let verdict = RevisionChoice.verdict(
            original: Self.assess(Self.body, [.sentenceLength, .exclamation]), revision: Self.assess(Self.body)
        )
        #expect(verdict == .notBetter)
    }

    @Test func aRevisionThatDropsTheOpeningLineTheCreatorPickedIsNotTaken() {
        let brief = IdeaBrief(subject: "The warm-up most people skip", angle: "", openingLine: "Your workout starts before the first squat.")
        let request = Self.request(brief: brief)
        let original = Self.assess("Your workout starts before the first squat. " + Self.body, [.avoided], request: request)
        let revision = Self.assess("Here is a quick warm-up. " + Self.body, request: request)
        #expect(original.opensWithBrief == true && revision.opensWithBrief == false)
        #expect(RevisionChoice.verdict(original: original, revision: revision) == .lostOpening)
    }

    @Test func aRevisionThatLeavesTheAngleIsNotTaken() {
        let brief = IdeaBrief(subject: "Warm-up", angle: "Show a five-minute warm-up for hips, chest and shoulders.", openingLine: "")
        let request = Self.request(brief: brief)
        let original = Self.assess("A five-minute warm-up: hips, then chest, then shoulders. Move slowly and breathe.", [.avoided], request: request)
        let revision = Self.assess("Working out at home is great. Stay consistent and you will see results soon.", request: request)
        #expect(RevisionChoice.verdict(original: original, revision: revision) == .lostAngle)
    }

    @Test func aRevisionThatSaysMuchLessIsNotTaken() {
        let original = Self.assess(Self.body + " " + Self.body.replacingOccurrences(of: "Save this", with: "Share this"), [.avoided])
        let revision = Self.assess("Warm up your hips before every home workout. Save this.")
        #expect(RevisionChoice.verdict(original: original, revision: revision) == .lostContent)
    }

    @Test func aRevisionCutMidSentenceIsNotTaken() {
        let original = Self.assess(Self.body, [.avoided])
        let revision = Self.assess("Warm up your hips before a home workout. Then open your chest slowly. Breathe out on every stretch. Save this for your")
        #expect(revision.isCut && !original.isCut)
        #expect(RevisionChoice.verdict(original: original, revision: revision) == .cutShort)
    }

    @Test func aRevisionThatRepeatsItselfIsNotTaken() {
        let original = Self.assess(Self.body, [.avoided])
        let looped = "Warm up your hips first. Then open your chest slowly. Warm up your hips first. Then open your chest slowly. Save this for your next workout."
        #expect(RevisionChoice.verdict(original: original, revision: Self.assess(looped)) == .moreRepetitive)
    }

    @Test func stageCuesDontCountAsAnEnding() {
        let cut = Self.assess("Warm up your hips first and then [pause]")
        #expect(cut.isCut)
        #expect(!Self.assess("Warm up your hips first. [smile]").isCut)
    }
}
