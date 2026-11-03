//
//  NicheTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The themes: broad ones (the owner, 03/11/2026: "Travel", not "Budget travel"), as many as cover most creators, the first flight and My Cue
/// Voice offering the same, each with its own name as a chip and in full for the AI.
@Suite("Niche")
struct NicheTests {
    @Test func everyThemeIsOfferedTheOnesThatCoverTheMostCreatorsFirst() {
        #expect(Niche.offered.count == 34 && Set(Niche.offered) == Set(Niche.allCases))
        #expect(Array(Niche.offered.prefix(5)) == [.lifestyle, .beauty, .business, .food, .fitness])
    }

    @Test func theThemesAreBroad() {
        #expect(Niche.travel.chipLabel == "Travel" && Niche.food.chipLabel == "Food & gastronomy")
        #expect(Niche.travel.promptName == "travel" && Niche.food.promptName == "food and gastronomy")
        #expect(!Niche.allCases.contains { $0.chipLabel.localizedCaseInsensitiveContains("budget") })
    }

    @Test func eachThemeHasItsOwnNameAsAChipAndForTheAI() {
        #expect(Set(Niche.allCases.map(\.chipLabel)).count == Niche.allCases.count, "no two themes share a name")
        #expect(Set(Niche.allCases.map(\.promptName)).count == Niche.allCases.count)
        #expect(Niche.allCases.allSatisfy { !$0.label.isEmpty && !$0.promptName.isEmpty })
    }

    @Test func aWorldIsCalledWhatTheCreatorPicked() {
        #expect(OnboardingTopic.niche(.lifestyle).label == "Lifestyle & daily life")
        #expect(OnboardingTopic.custom("Chess").label == "Chess")
    }

    @Test func aSavedNicheStillDecodes() throws {
        let decoded = try JSONDecoder().decode([Niche].self, from: Data(#"["lifestyle","wellness","tech","musicArts"]"#.utf8))
        #expect(decoded == [.lifestyle, .wellness, .tech, .musicArts])
    }
}
