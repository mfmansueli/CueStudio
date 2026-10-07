//
//  IdeaAngleTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Each batch of ideas is ordered differently (`IdeaAngle`), because the model copies a list of what to avoid.
struct IdeaAngleTests {
    private let topics = [
        IdeaTopic(name: "Daily Routine", label: "Daily Routine", niche: nil, subtopics: ["Bureaucracy"]),
        IdeaTopic(name: "language learning", label: "Languages", niche: nil, subtopics: ["Italian"]),
    ]

    @Test func eachRoundStartsWhereTheLastOneStopped() {
        let first = IdeaAngle.batch(round: 0)
        let second = IdeaAngle.batch(round: 1)
        #expect(first.count == 6 && second.count == 6)
        #expect(Set(first).isDisjoint(with: Set(second)), "no angle is asked twice in two rounds")
        #expect(IdeaAngle.batch(round: 0) == IdeaAngle.batch(round: 0))
    }

    @Test func theTopicsTakeTurnsAndStartOneFurtherEachRound() {
        let round0 = (0..<4).compactMap { IdeaAngle.topic(at: $0, round: 0, among: topics)?.name }
        let round1 = (0..<4).compactMap { IdeaAngle.topic(at: $0, round: 1, among: topics)?.name }
        #expect(round0 == ["Daily Routine", "language learning", "Daily Routine", "language learning"])
        #expect(round1 == ["language learning", "Daily Routine", "language learning", "Daily Routine"])
        #expect(IdeaAngle.topic(at: 0, round: 0, among: []) == nil)
    }

    @Test func thePromptOrdersEveryIdeaByAngleAndTopicWithoutListingWhatCameBefore() {
        let prompt = ScriptPromptBuilder.themesPrompt(about: topics, round: 0)
        #expect(prompt.contains("Daily Routine (Bureaucracy); language learning (Italian)"))
        #expect(prompt.contains("1. a list of things about Daily Routine; 2. a common mistake and how to fix it about language learning"))
        #expect(!prompt.contains("Do not repeat"))
        #expect(ScriptPromptBuilder.themesPrompt(about: topics, round: 1) != prompt)
    }

    @Test func wordsInADifferentOrderAreTheSameIdea() {
        let one = IdeaSimilarity.words(in: "Morning Check-Ins: Daily Routine")
        #expect(IdeaSimilarity.areAlike(one, IdeaSimilarity.words(in: "Daily Routine Morning Check-Ins")))
        #expect(!IdeaSimilarity.areAlike(one, IdeaSimilarity.words(in: "Italian Basics: 10 Words to Learn")))
    }
}
