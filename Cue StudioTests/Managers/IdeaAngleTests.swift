//
//  IdeaAngleTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Each batch of ideas is ordered by angle and topic (`IdeaSlot`), because the model copies a list of what to avoid.
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

    @Test func thePromptOrdersEveryIdeaByAngleAndTopicWithoutListingWhatCameBefore() {
        let slots = IdeaTaste().slots(round: 0, among: topics)
        let prompt = ScriptPromptBuilder.themesPrompt(slots: slots)
        #expect(slots.count == 6)
        #expect(prompt.contains("Daily Routine (Bureaucracy); language learning (Italian)"))
        #expect(prompt.contains("1. \(slots[0].angle.ask) about \(slots[0].topic.name)"))
        #expect(!prompt.contains("Do not repeat or reword"))
        #expect(ScriptPromptBuilder.themesPrompt(slots: IdeaTaste().slots(round: 1, among: topics)) != prompt)
    }

    @Test func whatTheCreatorWroteLatelyIsWhatTheIdeasGrowFrom() {
        let slots = IdeaTaste().slots(round: 0, among: topics)
        let prompt = ScriptPromptBuilder.themesPrompt(slots: slots, inspiration: ["Why Italian forms take three tries", "My morning with the AI planner"])
        #expect(prompt.contains("The creator has been thinking about: “Why Italian forms take three tries”; “My morning with the AI planner”"))
        #expect(prompt.contains("never repeat these"))
        #expect(!ScriptPromptBuilder.themesPrompt(slots: slots).contains("has been thinking about"))
    }

    @Test func wordsInADifferentOrderAreTheSameIdea() {
        let one = IdeaSimilarity.words(in: "Morning Check-Ins: Daily Routine")
        #expect(IdeaSimilarity.areAlike(one, IdeaSimilarity.words(in: "Daily Routine Morning Check-Ins")))
        #expect(!IdeaSimilarity.areAlike(one, IdeaSimilarity.words(in: "Italian Basics: 10 Words to Learn")))
    }

    @Test func theInspirationIsTheNotesFirstThenTheLatestScriptTitlesWithoutRepeats() {
        let notes = [LogbookEntry(text: "A video about slow mornings", createdAt: .now), LogbookEntry(text: "Italian forms", createdAt: .now)]
        let scripts = [
            TestData.script(title: "Italian forms"), TestData.script(title: "   "), TestData.script(title: "Cold showers: one month in"),
        ]
        let found = IdeaInspiration.recent(scripts: scripts, notes: notes)
        #expect(found.first == "A video about slow mornings")
        #expect(found.filter { $0.lowercased() == "italian forms" }.count == 1)
        #expect(found.contains("Cold showers: one month in") && !found.contains(""))
        #expect(found.count <= IdeaInspiration.limit)
    }
}
