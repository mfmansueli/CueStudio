//
//  IdeaRepeatTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// When an idea is the same idea said again (`IdeaSimilarity.repeats`) and when a brief is too weak to show (`IdeaSpecificity`): the model keeps a
/// title new and brings back the same angle and opening, and it writes angles that only say the title again. Ideas that look at a subject another way,
/// or the same kind of angle about another topic, are other ideas.
@Suite("Idea repeats and weak briefs")
struct IdeaRepeatTests {
    private static func idea(_ title: String, angle: String, opening: String, topic: String = "fitness") -> ThemeIdea {
        var idea = ThemeIdea(title: title, kind: "Tips", length: .minute1, niche: .fitness)
        idea.brief = IdeaBrief(subject: title, angle: angle, openingLine: opening, topicKey: topic)
        idea.angle = IdeaAngle.mistake.rawValue
        return idea
    }

    @Test func aNewTitleOnTheSameAngleAndOpeningIsARepeat() {
        let first = Self.idea(
            "The warm-up everyone skips", angle: "Show a five-minute warm-up for hips and shoulders.",
            opening: "Your workout starts before the first squat."
        )
        let again = Self.idea(
            "Stop skipping this before you train", angle: "Show a quick warm-up for your hips and shoulders.",
            opening: "Your workout starts before your first squat, not after."
        )
        #expect(!IdeaSimilarity.areAlike(IdeaEcho(first).title, IdeaEcho(again).title), "the titles alone don't tell")
        #expect(IdeaSimilarity.repeats(IdeaEcho(again), IdeaEcho(first)))
    }

    @Test func aRewordedTitleIsARepeatAsBefore() {
        let first = Self.idea("Morning check-ins for your daily routine", angle: "Plan the day in two minutes.", opening: "Two minutes. That's it.")
        let again = Self.idea("Daily routine morning check-ins", angle: "Something else entirely about sleep.", opening: "Sleep is a skill.")
        #expect(IdeaSimilarity.repeats(IdeaEcho(again), IdeaEcho(first)))
    }

    @Test func anotherLookAtTheSameSubjectIsAnotherIdea() {
        let mistake = Self.idea(
            "The squat mistake that hurts your knees", angle: "Fix knees caving in with one cue.", opening: "Watch your knees on the way down."
        )
        let myth = Self.idea(
            "Deep squats aren't bad for your knees", angle: "Bust the myth that going low ruins your joints.", opening: "Going low is not the problem."
        )
        #expect(!IdeaSimilarity.repeats(IdeaEcho(myth), IdeaEcho(mistake)))
    }

    @Test func theSameKindOfAngleAboutAnotherTopicIsAnotherIdea() {
        let fitness = Self.idea(
            "Three mistakes beginners make at the gym", angle: "Show three mistakes beginners make and fix each one.",
            opening: "Most beginners make these three mistakes.", topic: "fitness"
        )
        let cooking = Self.idea(
            "Three kitchen mistakes new cooks make", angle: "Show three mistakes beginners make and how to fix them.",
            opening: "Most beginners make these three mistakes.", topic: "food"
        )
        #expect(!IdeaSimilarity.repeats(IdeaEcho(cooking), IdeaEcho(fitness)))
    }

    @Test func anIdeaRememberedByItsTitleAloneStillCatchesAReword() {
        let old = IdeaEcho(title: "Why rest days make you stronger")
        let again = IdeaEcho(Self.idea("Rest days make you stronger: here's why", angle: "Explain recovery.", opening: "Muscles grow when you rest."))
        #expect(IdeaSimilarity.repeats(again, old))
    }

    // MARK: - Weak briefs

    @Test func anAngleThatOnlySaysTheTitleAgainIsAWeakness() {
        let idea = Self.idea("Morning stretches for runners", angle: "Show morning stretches for runners.", opening: "Runners, stretch before you run.")
        #expect(IdeaSpecificity.weaknesses(of: idea) == [.angleRestatesTitle])
        #expect(!IdeaSpecificity.isUnusable(idea), "one weakness is a brief to show later, not one to drop")
    }

    @Test func aStockHeadlineWithAnAngleThatRestatesItIsNoIdea() {
        let idea = Self.idea("5 fitness tips", angle: "Share five fitness tips.", opening: "Here are my best fitness tips.")
        #expect(Set(IdeaSpecificity.weaknesses(of: idea)) == [.angleRestatesTitle, .genericTitle])
        #expect(IdeaSpecificity.isUnusable(idea))
    }

    @Test func aSpecificBriefHasNoWeakness() {
        let idea = Self.idea(
            "Dicas de skincare com três produtos de farmácia", angle: "Monte uma rotina noturna barata em três passos.",
            opening: "Você não precisa de dez produtos para cuidar da pele.", topic: "beauty"
        )
        #expect(IdeaSpecificity.weaknesses(of: idea).isEmpty)
    }
}
