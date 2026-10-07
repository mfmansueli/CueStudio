//
//  VoiceRunMetricsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The yardstick the before and after of My Cue Voice are measured with (plan §6), on scripts written by hand.
@MainActor
@Suite("Voice run metrics")
struct VoiceRunMetricsTests {
    private func sample(_ persona: String, _ text: String?, condition: String = "voice", index: Int = 0) -> VoiceRunSample {
        VoiceRunSample(
            persona: persona, ideaIndex: index, idea: "idea", condition: condition, run: "test", title: nil, text: text,
            failure: text == nil ? "refused" : nil, seconds: 1, attempts: 1
        )
    }

    private let long = Array(repeating: "plain words about the mat and the breath", count: 20).joined(separator: ". ") + "."

    @Test func theHardConstraintsAreCountedByWhatThePersonaSaysNotByTheApp() {
        let summary = VoiceRunMetrics([
            sample("yoga-teacher", "This is a game-changer for your shoulders. " + long),
            sample("yoga-teacher", long),
            sample("yoga-teacher", nil),
        ]).byCondition["voice"]
        #expect(summary?.scripts == 3 && summary?.written == 2)
        #expect(summary?.avoided == 1, "“game-changer” is on the yoga teacher's list")
    }

    @Test func aScriptOfWeThatSaysIIsCountedAgainstTheCreatorWhoSaysWe() {
        let summary = VoiceRunMetrics([
            sample("saas-founder", "I built this. My team and I ship weekly. " + long),
            sample("saas-founder", "We built this. Our team ships weekly. " + long),
        ]).byCondition["voice"]
        #expect(summary?.pronoun == 1)
    }

    @Test func aCatchphraseOrAStyleNameOpeningIsCounted() {
        let summary = VoiceRunMetrics([
            sample("yoga-teacher", "Breathe in. " + long),
            sample("yoga-teacher", "Question. " + long),
            sample("yoga-teacher", "What if your shoulders could rest? " + long),
        ]).byCondition["voice"]
        #expect(summary?.catchphraseFirst == 1 && summary?.styleName == 1)
    }

    @Test func conditionsAreKeptApartAndLengthIsAveraged() {
        let metrics = VoiceRunMetrics([sample("yoga-teacher", long, condition: "no-voice"), sample("yoga-teacher", "Short one here.")])
        #expect(metrics.byCondition["no-voice"]?.written == 1 && metrics.byCondition["voice"]?.written == 1)
        #expect(metrics.byCondition["voice"]?.averageWords == 3)
        #expect(metrics.byCondition["voice"]?.tooShort == 1)
    }

    @Test func topicTermsShowTheTopicWasHeard() {
        let summary = VoiceRunMetrics([
            sample("yoga-teacher", "Take a slow breath and stretch your shoulders on the mat."),
            sample("yoga-teacher", "Spreadsheets and quarterly planning."),
        ]).byCondition["voice"]
        #expect(summary?.topicHits == 1 && summary?.topicRate == 0.5)
    }

    @Test func sentencesAreJudgedAgainstWhatTheCreatorChose() {
        #expect(VoiceRunMetrics.sentenceFit(of: "Short one. Another short one. Tiny.", wanted: .short) == true)
        #expect(VoiceRunMetrics.sentenceFit(of: "Short one. Another short one. Tiny.", wanted: .long) == false)
        let longSentence = "This is a much longer sentence that keeps building an argument with several clauses and a point to make."
        #expect(VoiceRunMetrics.sentenceFit(of: longSentence, wanted: .long) == true)
        #expect(VoiceRunMetrics.sentenceFit(of: longSentence, wanted: .short) == false)
        #expect(VoiceRunMetrics.sentenceFit(of: "Anything.", wanted: nil) == nil)
    }

    @Test func anOpeningIsJudgedOnlyWhenACountCanTellAndAQuestionEndsWithAQuestionMark() {
        #expect(VoiceRunMetrics.openingFollowed(by: "Why do mornings hurt? Because of this.", openings: ["Question"]) == true)
        #expect(VoiceRunMetrics.openingFollowed(by: "Breathe in. Why do mornings hurt?", openings: ["Question"]) == false)
        #expect(VoiceRunMetrics.openingFollowed(by: "Here are 3 ways to start.", openings: ["Start with a number"]) == true)
        #expect(VoiceRunMetrics.openingFollowed(by: "POV: you stopped snoozing.", openings: ["POV"]) == true)
        #expect(VoiceRunMetrics.openingFollowed(by: "A bold claim.", openings: ["Bold claim"]) == nil)
    }

    @Test func twoCreatorsWritingTheSameWordsAreNotDistinctAndTwoWritingDifferentOnesAre() {
        let same = [sample("a", "the quick brown fox jumps over the lazy dog today"), sample("b", "the quick brown fox jumps over the lazy dog today")]
        #expect(VoiceRunMetrics.distinction(same, condition: "voice") == 0)
        let apart = [sample("a", "the quick brown fox jumps over the lazy dog today"), sample("b", "nothing here resembles that other sentence at all")]
        #expect(VoiceRunMetrics.distinction(apart, condition: "voice") == 1)
        #expect(VoiceRunMetrics.distinction([], condition: "voice") == 0)
    }

    @Test func theRecordedBaselineHasEveryCreatorAndBothConditions() throws {
        let samples = try VoiceRunFixture.samples("before")
        #expect(samples.count == 84, "14 creators, 3 ideas, 2 conditions")
        #expect(Set(samples.map(\.persona)).count == 14)
        let metrics = VoiceRunMetrics(samples)
        #expect(metrics.byCondition["no-voice"]?.scripts == 42 && metrics.byCondition["voice"]?.scripts == 42)
    }
}
