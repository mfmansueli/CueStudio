//
//  VoiceSubtopicCatalogTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("Voice topics and subtopics")
struct VoiceSubtopicCatalogTests {
    private let everyTopic: [VoiceTopicRef] = Niche.allCases.map(VoiceTopicRef.niche) + VoiceTopic.allCases.map(VoiceTopicRef.extra)

    @Test func aTopicOnlyTheVoiceOffersNeverSharesANicheValue() {
        let niches = Set(Niche.allCases.map(\.rawValue))
        #expect(VoiceTopic.allCases.allSatisfy { !niches.contains($0.rawValue) }, "a saved topic must mean one thing")
        #expect(VoiceTopic.allCases.count == 15)
    }

    @Test func everyTopicSuggestsSevenSubtopicsThatFitTheLimit() {
        #expect(everyTopic.count == 27)
        for topic in everyTopic {
            let options = topic.suggestedSubtopics
            #expect(options.count == 7, "\(topic.id)")
            #expect(Set(options.map(\.id)).count == options.count, "\(topic.id): no repeats")
            for option in options {
                #expect(VoiceTextValidator.lengths.contains(option.id.count), "\(topic.id): “\(option.id)” fits the 2–40 characters")
                #expect(!option.label.isEmpty)
            }
        }
    }

    @Test func aTypedTopicHasNoSuggestionsAndKeepsItsName() {
        let chess = VoiceTopicRef.custom("Chess")
        #expect(chess.suggestedSubtopics.isEmpty)
        #expect(chess.label == "Chess" && chess.promptName == "Chess" && chess.id == "Chess")
    }

    @Test func theAIReadsEnglishNamesWhateverTheInterfaceSays() {
        for topic in everyTopic {
            #expect(!topic.promptName.isEmpty && topic.promptName.allSatisfy(\.isASCII), "\(topic.id): English words only")
        }
        #expect(VoiceTopicRef.niche(.travel).promptName == "budget travel", "“Travel” alone told the model little")
        #expect(VoiceTopicRef.niche(.lifestyle).promptName == "morning routines and daily life")
        #expect(Set(everyTopic.map(\.promptName)).count == everyTopic.count)
    }

    @Test func aSubtopicOfCuesIsKeptAsItsEnglishTextAndShownInTheInterfaceLanguage() {
        let option = VoiceTopicRef.niche(.fitness).suggestedSubtopics[0]
        #expect(option.id == "Strength training")
        #expect(VoiceSubtopicCatalog.displayName(of: option.id) == option.label)
        #expect(VoiceSubtopicCatalog.displayName(of: "My own thing") == "My own thing", "what the creator typed is shown as typed")
    }

    @Test func theLimitsOfTheNewAnswersAreWhatThePlanSays() {
        #expect(VoiceLimits.details == 3)
        #expect(VoiceLimits.watchReasons == 2)
        #expect(VoiceLimits.contentGoals == 2)
        #expect(VoiceLimits.approvedSamples == 3)
        #expect(VoiceLimits.topics == 3)
    }
}
