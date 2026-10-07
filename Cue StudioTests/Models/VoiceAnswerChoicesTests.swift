//
//  VoiceAnswerChoicesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The small answer lists the voice editor offers (why they watch, what the videos are for, who is watching, who is talking).
@Suite("Voice answer choices")
struct VoiceAnswerChoicesTests {
    @Test func everyChoiceHasALabelAndAnEnglishPhraseForTheAI() {
        for reason in WatchReason.allCases { #expect(!reason.label.isEmpty && !reason.promptPhrase.isEmpty, "\(reason)") }
        for goal in ContentGoal.allCases { #expect(!goal.label.isEmpty && !goal.promptPhrase.isEmpty, "\(goal)") }
        for group in AudienceGroup.allCases { #expect(!group.label.isEmpty && !group.promptName.isEmpty, "\(group)") }
        #expect(SpeaksAs.i.promptPronoun == "I" && SpeaksAs.we.promptPronoun == "we")
        #expect(WatchReason.allCases.count == 6 && ContentGoal.allCases.count == 7 && AudienceGroup.allCases.count == 8)
    }

    @Test func theChoicesAreUniqueSoWhatIsSavedMeansOneThing() {
        #expect(Set(WatchReason.allCases.map(\.promptPhrase)).count == WatchReason.allCases.count)
        #expect(Set(ContentGoal.allCases.map(\.promptPhrase)).count == ContentGoal.allCases.count)
        #expect(Set(AudienceGroup.allCases.map(\.promptName)).count == AudienceGroup.allCases.count)
    }

    @Test func eachAudienceImpliesTheVocabularyItsWordsNeed() {
        #expect(AudienceGroup.teens.vocabulary == .genZ)
        #expect(AudienceGroup.professionals.vocabulary == .professional)
        #expect(AudienceGroup.insiders.vocabulary == .technical)
        #expect(AudienceGroup.parents.vocabulary == .simple)
    }

    @Test func theAudienceListPutsTheLikelyGroupsOfAKindOfCreatorFirstAndKeepsEveryGroupOnce() {
        for role in CreatorRole.allCases.map(Optional.some) + [nil] {
            let ordered = AudienceGroup.ordered(for: role)
            #expect(ordered.count == AudienceGroup.allCases.count && Set(ordered).count == ordered.count, "\(String(describing: role))")
        }
        #expect(AudienceGroup.ordered(for: .business).first == .localCommunity)
        #expect(AudienceGroup.ordered(for: .educator).first == .students)
        #expect(AudienceGroup.ordered(for: nil) == AudienceGroup.allCases)
    }
}
