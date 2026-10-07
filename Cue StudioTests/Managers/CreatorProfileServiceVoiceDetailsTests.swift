//
//  CreatorProfileServiceVoiceDetailsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The answers My Cue Voice for Apple Intelligence added (plan stage 2): topics of any kind and their subtopics, who is watching, what the
/// videos are for and who is talking.
@MainActor
@Suite("CreatorProfileService · voice details")
struct CreatorProfileServiceVoiceDetailsTests {
    private func service() -> (CreatorProfileService, TestDefaults) {
        let defaults = TestDefaults()
        return (CreatorProfileService(defaults: defaults.defaults), defaults)
    }

    // MARK: - Topics

    @Test func theTwentyFiveTopicsAreTheTenOfTheFirstFlightAndFifteenOnlyTheVoiceOffers() {
        let ids = VoiceQuestion.topics.options.map(\.id)
        #expect(ids.count == 25 && Set(ids).count == 25)
        #expect(ids.dropFirst(10).allSatisfy { VoiceTopic(rawValue: $0) != nil })
    }

    @Test func aTopicOfEitherKindIsPickedThroughTheSameAnswer() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        let fitness = VoiceQuestion.topics.options.first { $0.id == Niche.fitness.rawValue }
        let pets = VoiceQuestion.topics.options.first { $0.id == VoiceTopic.pets.rawValue }
        #expect(service.answer(.topics, with: fitness ?? VoiceOption(id: "", label: "")) == .added)
        #expect(service.answer(.topics, with: pets ?? VoiceOption(id: "", label: "")) == .added)
        #expect(service.profile.niches == [.fitness])
        #expect(service.profile.voiceTopics == [.pets])
        #expect(service.isSelected(pets ?? VoiceOption(id: "", label: ""), for: .topics))
        #expect(service.answer(.topics, with: pets ?? VoiceOption(id: "", label: "")) == .removed)
        #expect(service.profile.voiceTopics.isEmpty)
    }

    @Test func threeTopicsOfAnyKindIsTheLimitAndAFourthSaysSo() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        #expect(service.toggleTopic(.niche(.tech)) == .added)
        #expect(service.toggleTopic(.extra(.gaming)) == .added)
        #expect(service.addSomethingElse("Chess openings", for: .topics) == .added)
        #expect(service.profile.topicCount == 3)
        #expect(service.toggleTopic(.extra(.cars)) == .limit("Max 3 topics"))
        #expect(service.toggleTopic(.niche(.food)) == .limit("Max 3 topics"))
        #expect(service.addSomethingElse("Gardening", for: .topics) == .limit("Max 3 topics"))
        #expect(service.profile.topicCount == 3 && service.profile.voiceTopics == [.gaming])
    }

    @Test func dropAtopicAndItsSubtopicsGoWithIt() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        service.toggleTopic(.niche(.fitness))
        service.toggleSubtopic("Running", of: .niche(.fitness))
        #expect(service.profile.topicDetails == ["fitness": ["Running"]])
        service.toggleTopic(.niche(.fitness))
        #expect(service.profile.topicDetails.isEmpty)
    }

    @Test func subtopicsOfATopicTheCreatorHoldsUpToThreeAndAFourthSaysSo() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        let fitness = VoiceTopicRef.niche(.fitness)
        #expect(service.toggleSubtopic("Running", of: fitness) == .alreadyThere, "a topic that isn't held takes none")
        service.toggleTopic(fitness)
        #expect(service.toggleSubtopic("Running", of: fitness) == .added)
        #expect(service.toggleSubtopic("Home workouts", of: fitness) == .added)
        #expect(service.toggleSubtopic("Weight loss", of: fitness) == .added)
        #expect(service.toggleSubtopic("Yoga & stretching", of: fitness) == .limit("Max 3 subtopics"))
        #expect(service.toggleSubtopic("running", of: fitness) == .removed, "the same subtopic however it is cased")
        #expect(service.profile.subtopics(of: fitness) == ["Home workouts", "Weight loss"])
    }

    @Test func aTypedSubtopicIsCheckedLikeEveryTypedAnswerAndASuggestionTypedIsTheSuggestion() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        let fitness = VoiceTopicRef.niche(.fitness)
        service.toggleTopic(fitness)
        #expect(service.addSubtopic("a", to: fitness) == .rejected(.tooShort))
        #expect(service.addSubtopic("what the fuck", to: fitness) == .rejected(.blocked))
        #expect(service.addSubtopic("Kettlebell flows", to: fitness) == .added)
        #expect(service.addSubtopic("kettlebell flows", to: fitness) == .alreadyThere)
        #expect(service.addSubtopic("Runing", to: fitness) == .suggest(suggestion: "Running", original: "Runing"))
        #expect(service.addSubtopic("Runing", to: fitness, keepingTyped: true) == .added)
        #expect(service.addSubtopic("running", to: fitness) == .added, "a suggestion typed in is the suggestion, in Cue's own text")
        #expect(service.profile.subtopics(of: fitness) == ["Kettlebell flows", "Runing", "Running"])
    }

    @Test func aTypedTopicKeepsItsSubtopicsUnderItsName() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        service.addSomethingElse("Chess", for: .topics)
        let chess = VoiceTopicRef.custom("Chess")
        #expect(service.addSubtopic("Endgames", to: chess) == .added)
        #expect(service.profile.topicDetails == ["Chess": ["Endgames"]])
        service.toggleTopic(chess)
        #expect(service.profile.customTopics.isEmpty && service.profile.topicDetails.isEmpty)
    }

    // MARK: - Formats, openings, endings, avoid

    @Test func theNewFormatsOpeningsEndingsAndThingsToAvoidAreOffered() {
        #expect(VoiceQuestion.formats.options.count == 11)
        #expect(VoiceQuestion.openings.options.count == 7)
        #expect(VoiceQuestion.endings.options.count == 6)
        #expect(VoiceQuestion.avoid.options.count == 9)
        let ids = VoiceQuestion.formats.options.map(\.id)
        #expect(ids.contains(VoiceQuestion.dayInTheLifeID) && ids.contains(ScriptType.mythFact.rawValue))
        #expect(ids.contains(VoiceQuestion.questionsID) && ids.contains(VoiceQuestion.behindTheScenesID) && ids.contains(VoiceQuestion.beforeAfterID))
    }

    @Test func aFormatWithNoScriptTypeIsKeptAsATagAndCountsAgainstTheLimitOfThree() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        func option(_ id: String) -> VoiceOption { VoiceQuestion.formats.options.first { $0.id == id } ?? VoiceOption(id: id, label: id) }
        #expect(service.answer(.formats, with: option(VoiceQuestion.questionsID)) == .added)
        #expect(service.answer(.formats, with: option(VoiceQuestion.beforeAfterID)) == .added)
        #expect(service.answer(.formats, with: option(ScriptType.tutorial.rawValue)) == .added)
        #expect(service.profile.formatTags == ["Q&A", "Before/after"])
        #expect(service.profile.isFilled(VoiceField.formats))
        #expect(service.answer(.formats, with: option(VoiceQuestion.talkingHeadID)) == .limit("Max 3 formats"))
        #expect(service.answer(.formats, with: option(ScriptType.review.rawValue)) == .limit("Max 3 formats"))
        #expect(service.isSelected(option(VoiceQuestion.questionsID), for: .formats))
        #expect(service.answer(.formats, with: option(VoiceQuestion.questionsID)) == .removed)
        #expect(service.profile.value(for: .formats) == "Before/after · Tutorial")
    }

    // MARK: - Who is watching

    @Test func pickingAGroupAnswersWhoIsWatchingAndImpliesItsVocabulary() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        #expect(!service.profile.hasAnswered(.audience))
        service.setAudienceGroup(.teens)
        #expect(service.profile.hasAnswered(.audience) && service.profile.vocabulary == .genZ)
        #expect(service.profile.audienceGroup == .teens)
        service.answerAudienceLevel(.some)
        #expect(service.profile.value(for: .audience) == "Teenagers · Some basics")
    }

    @Test func theCreatorsOwnWordsReplaceTheGroupAndTheOtherWayAround() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        service.setAudienceGroup(.parents)
        #expect(service.setAudienceNote("Nurses on night shifts") == .added)
        #expect(service.profile.audienceNote == "Nurses on night shifts" && service.profile.audienceGroup == nil)
        service.setAudienceGroup(.students)
        #expect(service.profile.audienceNote == nil && service.profile.audienceGroup == .students)
        #expect(service.setAudienceNote("") == .removed)
        #expect(service.setAudienceNote("x") == .rejected(.tooShort))
        #expect(service.setAudienceNote(String(repeating: "a", count: 41)) == .rejected(.tooLong))
        #expect(service.setAudienceNote("what the fuck") == .rejected(.blocked))
        #expect(service.profile.audienceGroup == .students, "a refused text changes nothing")
    }

    @Test func twoReasonsToWatchAndAThirdSaysSo() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        #expect(service.toggleWatchReason(.learn) == .added)
        #expect(service.toggleWatchReason(.laugh) == .added)
        #expect(service.toggleWatchReason(.decideToBuy) == .limit("Max 2 reasons"))
        #expect(service.toggleWatchReason(.learn) == .removed)
        #expect(service.profile.watchReasons == [.laugh])
    }

    // MARK: - What the videos are for, and who is talking

    @Test func twoGoalsAndAThirdSaysSo() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        #expect(service.toggleContentGoal(.sell) == .added)
        #expect(service.toggleContentGoal(.teach) == .added)
        #expect(service.toggleContentGoal(.community) == .limit("Max 2 goals"))
        #expect(service.toggleContentGoal(.sell) == .removed)
        #expect(service.profile.contentGoals == [.teach])
    }

    @Test func aKindOfCreatorOfTheirOwnAndACredentialAreCheckedAndClearable() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        service.answer(.role, with: VoiceOption(id: CreatorRole.expert.rawValue, label: "Expert"))
        #expect(service.setCustomRole("Wedding photographer") == .added)
        #expect(service.profile.customRole == "Wedding photographer" && service.profile.role == .expert, "the closest of the eight stays")
        #expect(service.setCredential("Registered nurse") == .added)
        #expect(service.profile.credential == "Registered nurse")
        #expect(service.setCredential("a") == .rejected(.tooShort))
        #expect(service.profile.credential == "Registered nurse")
        #expect(service.setCustomRole("   ") == .removed && service.profile.customRole == nil)
        #expect(service.setCredential("") == .removed && service.profile.credential == nil)
    }

    @Test func sayingIOrWeIsTheCreatorsChoiceAndNilGoesBackToTheKindOfCreator() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        service.answer(.role, with: VoiceOption(id: CreatorRole.brands.rawValue, label: "Brands"))
        #expect(service.profile.resolvedSpeaksAs == .we)
        service.setSpeaksAs(.i)
        #expect(service.profile.resolvedSpeaksAs == .i)
        service.setSpeaksAs(nil)
        #expect(service.profile.resolvedSpeaksAs == .we)
    }

    @Test func everyNewAnswerIsKeptOnTheDevice() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let first = CreatorProfileService(defaults: defaults.defaults)
        first.toggleTopic(.extra(.faith))
        first.toggleSubtopic("Prayer", of: .extra(.faith))
        first.toggleWatchReason(.feelUnderstood)
        first.setAudienceGroup(.localCommunity)
        first.toggleContentGoal(.community)
        first.setSpeaksAs(.we)
        let second = CreatorProfileService(defaults: defaults.defaults)
        #expect(second.profile.voiceTopics == [.faith])
        #expect(second.profile.topicDetails == ["faith": ["Prayer"]])
        #expect(second.profile.watchReasons == [.feelUnderstood] && second.profile.audienceGroup == .localCommunity)
        #expect(second.profile.contentGoals == [.community] && second.profile.speaksAs == .we)
    }
}
