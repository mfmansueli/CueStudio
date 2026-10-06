//
//  NicheTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The topics (09 §14b): ten offered in the first flight, in the board's order, each with its own name as a chip.
@Suite("Niche")
struct NicheTests {
    @Test func theFirstFlightOffersTenTopicsMostCommonFirst() {
        #expect(Niche.offered == [.fitness, .food, .beauty, .fashion, .finance, .tech, .travel, .productivity, .parenting, .lifestyle])
        #expect(Niche.offered.count == 10)
    }

    @Test func theTwoTopicsThatCameBeforeStayForCreatorsWhoChoseThem() {
        #expect(!Niche.offered.contains(.wellness) && !Niche.offered.contains(.education))
        #expect(Niche.allCases.count == 12)
    }

    @Test func eachChipHasTheBoardsName() {
        #expect(Niche.offered.map(\.chipLabel) == [
            "Fitness & wellness", "Food & cooking", "Beauty & skincare", "Fashion & style", "Personal finance", "Tech & AI", "Budget travel",
            "Productivity & career", "Parenting & family", "Morning routines",
        ])
        #expect(Set(Niche.allCases.map(\.chipLabel)).count == Niche.allCases.count, "no two topics share a name")
    }

    @Test func aWorldIsCalledWhatTheCreatorPicked() {
        #expect(OnboardingTopic.niche(.lifestyle).label == "Morning routines")
        #expect(OnboardingTopic.custom("Chess").label == "Chess")
    }

    @Test func aSavedNicheStillDecodes() throws {
        let decoded = try JSONDecoder().decode([Niche].self, from: Data(#"["lifestyle","wellness","tech"]"#.utf8))
        #expect(decoded == [.lifestyle, .wellness, .tech])
    }
}
