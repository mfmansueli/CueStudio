//
//  CreatorProfileVoiceV2Tests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The fields My Cue Voice for Apple Intelligence added to `CreatorProfile` (plan stage 1): everything optional, nothing saved before is lost.
@Suite("CreatorProfile · voice v2")
struct CreatorProfileVoiceV2Tests {
    // MARK: - Profiles saved before

    @Test func everyOlderProfileOpensWithTheNewFieldsEmpty() throws {
        for (name, json) in [("v1", CreatorProfileFixtures.v1), ("v29", CreatorProfileFixtures.v29), ("v30", CreatorProfileFixtures.v30)] {
            let profile = try CreatorProfileFixtures.decode(json)
            #expect(profile.voiceTopics.isEmpty, "\(name)")
            #expect(profile.topicDetails.isEmpty, "\(name)")
            #expect(profile.audienceGroup == nil && profile.audienceNote == nil, "\(name)")
            #expect(profile.watchReasons.isEmpty && profile.contentGoals.isEmpty, "\(name)")
            #expect(profile.customRole == nil && profile.credential == nil && profile.speaksAs == nil, "\(name)")
            #expect(profile.approvedSamples.isEmpty, "\(name)")
            #expect(profile.voiceSchemaVersion == 1, "\(name): saved before the version existed")
        }
    }

    @Test func aV30ProfileKeepsEveryAnswerItHad() throws {
        let profile = try CreatorProfileFixtures.decode(CreatorProfileFixtures.v30)
        #expect(profile.niches == [.fitness])
        #expect(profile.role == .expert)
        #expect(profile.sounds == [.warmCalm, .educational])
        #expect(profile.style == VoiceDelivery(energy: .calm, sentences: .mixed, words: .plain, swearing: .never))
        #expect(profile.avoid == ["Medical claims", "Hype words"])
        #expect(profile.reach == VoiceReach(platforms: [.tiktok], length: .thirtyToSixty, humor: .little))
        #expect(profile.audienceLevel == .new)
        #expect(profile.approvals == 4)
        #expect(profile.examples.map(\.text) == ["Okay, real talk. Mornings are hard."])
        #expect(profile.styles == [.shortSentences, .conversational], "the legacy styles are read as they were")
    }

    @Test func aV29ProfileKeepsItsSwearingAndItsTypedTopic() throws {
        let profile = try CreatorProfileFixtures.decode(CreatorProfileFixtures.v29)
        #expect(profile.style.swearing == .mild)
        #expect(profile.customTopics == ["Chess"])
        #expect(profile.topics.map(\.label) == ["Tech & AI", "Productivity & career", "Chess"])
        #expect(profile.hasMinimumVoice)
    }

    @Test func theMeterDoesNotDropForAnyoneWhoAlreadyHadPoints() throws {
        // Essentials 40 + Personality 40 (style, formats, openings, endings, phrases, avoid, reach) + Proof 20 (one example and two approvals twice).
        #expect(try CreatorProfileFixtures.decode(CreatorProfileFixtures.v30).voiceStrength == 100)
        // Role, topics and tone (the audience needs its level, which v29 didn't ask), then formats, openings, endings and phrases.
        #expect(try CreatorProfileFixtures.decode(CreatorProfileFixtures.v29).voiceStrength == 30 + 4 * 6)
    }

    @Test func theNewFieldsAreWorthNothingToTheMeter() throws {
        var profile = try CreatorProfileFixtures.decode(CreatorProfileFixtures.v29)
        let before = profile.voiceStrength
        profile.topicDetails = ["tech": ["AI tools"]]
        profile.audienceGroup = .insiders
        profile.audienceNote = "Chess coaches"
        profile.watchReasons = [.learn]
        profile.contentGoals = [.teach]
        profile.credential = "FIDE master"
        profile.speaksAs = .i
        #expect(profile.voiceStrength == before)
    }

    // MARK: - Writing and reading

    @Test func theNewFieldsRoundTrip() throws {
        var profile = try CreatorProfileFixtures.decode(CreatorProfileFixtures.v30)
        profile.voiceTopics = [.pets, .gaming]
        profile.topicDetails = ["fitness": ["Yoga & stretching", "Sleep & recovery"], "pets": ["Dogs"], "Chess club": ["Openings"]]
        profile.audienceGroup = .parents
        profile.audienceNote = "Parents of toddlers"
        profile.watchReasons = [.learn, .feelUnderstood]
        profile.contentGoals = [.teach, .community]
        profile.customRole = "Chess coach"
        profile.credential = "Registered nurse"
        profile.speaksAs = .we
        profile.approvedSamples = [VoiceExample(text: "Okay, real talk.", source: "Sounds like me")]
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(profile))
        #expect(decoded == profile.with(schema: CreatorProfile.currentVoiceSchema))
    }

    @Test func whatThisBuildWritesIsOfTheCurrentVersion() throws {
        let old = try CreatorProfileFixtures.decode(CreatorProfileFixtures.v30)
        #expect(old.voiceSchemaVersion == 1)
        let rewritten = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(old))
        #expect(rewritten.voiceSchemaVersion == CreatorProfile.currentVoiceSchema)
        #expect(CreatorProfile().voiceSchemaVersion == CreatorProfile.currentVoiceSchema)
    }

    @Test func aValueFromANewerBuildReadsAsAbsentAndTheProfileStillOpens() throws {
        let json = """
        {"name":"Ana","niches":["fitness"],"voiceTopics":["gaming","hologram"],"audienceGroup":"aliens","speaksAs":"they",
         "watchReasons":["learn","teleport"],"contentGoals":["sell","conquer"]}
        """
        let profile = try CreatorProfileFixtures.decode(json)
        #expect(profile.name == "Ana")
        #expect(profile.voiceTopics == [.gaming])
        #expect(profile.audienceGroup == nil)
        #expect(profile.speaksAs == nil)
        #expect(profile.watchReasons == [.learn])
        #expect(profile.contentGoals == [.sell])
    }

    @Test func answersOverTheirLimitsAreCutWhenRead() throws {
        let json = """
        {"watchReasons":["learn","laugh","getInspired"],"contentGoals":["grow","sell","teach"],
         "approvedSamples":[{"id":"6F1D8C58-1B5C-4C3D-9E0A-2F7B5E9A1C01","text":"one","addedAt":781000001},
         {"id":"6F1D8C58-1B5C-4C3D-9E0A-2F7B5E9A1C02","text":"two","addedAt":781000002},
         {"id":"6F1D8C58-1B5C-4C3D-9E0A-2F7B5E9A1C03","text":"three","addedAt":781000003},
         {"id":"6F1D8C58-1B5C-4C3D-9E0A-2F7B5E9A1C04","text":"four","addedAt":781000004}]}
        """
        let profile = try CreatorProfileFixtures.decode(json)
        #expect(profile.watchReasons == [.learn, .laugh])
        #expect(profile.contentGoals == [.grow, .sell])
        #expect(profile.approvedSamples.map(\.text) == ["two", "three", "four"], "the oldest goes")
    }

    @Test func subtopicsAreTidiedWhenRead() throws {
        let json = """
        {"topicDetails":{"fitness":[" Running ","running","","Yoga & stretching","Home workouts","Weight loss"],"pets":[],"faith":["  "]}}
        """
        let profile = try CreatorProfileFixtures.decode(json)
        #expect(profile.topicDetails == ["fitness": ["Running", "Yoga & stretching", "Home workouts"]])
    }

    @Test func typedTextIsTrimmedAndEmptyIsNil() throws {
        let json = #"{"audienceNote":"  Nurses on night shifts ","customRole":"   ","credential":""}"#
        let profile = try CreatorProfileFixtures.decode(json)
        #expect(profile.audienceNote == "Nurses on night shifts")
        #expect(profile.customRole == nil)
        #expect(profile.credential == nil)
    }

    // MARK: - Topics

    @Test func topicsAreThePickedOnesThenTheVoiceOnesThenTheTypedOnes() {
        let profile = CreatorProfile(niches: [.tech], customTopics: ["Chess"], voiceTopics: [.pets])
        #expect(profile.topics == [.niche(.tech), .extra(.pets), .custom("Chess")])
        #expect(profile.topicCount == 3)
    }

    /// A topic only the voice offers tells the AI what the videos are about and is never a world in the universe.
    @MainActor
    @Test func aTopicOnlyTheVoiceOffersIsNeverAWorldInTheUniverse() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.profile = CreatorProfile(niches: [.tech], customTopics: ["Chess"], voiceTopics: [.pets, .gaming])
        let tagging = TopicTaggingService(
            library: ScriptLibraryService(repository: FakeScriptRepository(), now: { .now }), profile: profile,
            personalization: PersonalizationService(defaults: defaults.defaults), writer: FakeScriptWriter()
        )
        #expect(tagging.topics == [.niche(.tech), .custom("Chess")])
    }

    @Test func aTopicOnlyTheVoiceOffersIsAnAnswer() {
        var profile = CreatorProfile(role: .business, sounds: [.casual], confirmedVoiceSteps: [.audience, .tone])
        #expect(!profile.hasAnswered(.niche))
        profile.voiceTopics = [.realEstate]
        #expect(profile.hasAnswered(.niche))
        #expect(profile.isFilled(.topics))
    }

    @Test func subtopicsAreKeptUnderTheirTopic() {
        let profile = CreatorProfile(niches: [.fitness], customTopics: ["Chess"], topicDetails: ["fitness": ["Running"], "Chess": ["Openings"]])
        #expect(profile.subtopics(of: .niche(.fitness)) == ["Running"])
        #expect(profile.subtopics(of: .custom("Chess")) == ["Openings"])
        #expect(profile.subtopics(of: .niche(.food)).isEmpty)
    }

    // MARK: - Who is talking

    @Test func theKindOfCreatorSuggestsIOrWeAndTheCreatorsOwnChoiceWins() {
        #expect(CreatorProfile(role: .business).resolvedSpeaksAs == .we)
        #expect(CreatorProfile(role: .brands).resolvedSpeaksAs == .we)
        #expect(CreatorProfile(role: .expert).resolvedSpeaksAs == .i)
        #expect(CreatorProfile().resolvedSpeaksAs == .i)
        #expect(CreatorProfile(role: .brands, speaksAs: .i).resolvedSpeaksAs == .i, "a UGC creator says “I” though the role suggests “we”")
        #expect(CreatorProfile(role: .expert, speaksAs: .we).resolvedSpeaksAs == .we)
    }

    // MARK: - The voice the AI is given

    @Test func theVoiceCarriesTheNewFieldsAndTheTopicsWithTheirSubtopics() {
        let profile = CreatorProfile(
            niches: [.travel], customTopics: ["Van life"], role: .brands,
            voiceTopics: [.cars], topicDetails: ["travel": ["Cheap flights"]], audienceGroup: .youngAdults, audienceNote: "Gap-year people",
            watchReasons: [.solveProblem], contentGoals: [.sell], customRole: "Travel photographer", credential: "Pilot", speaksAs: .i
        )
        let voice = profile.voice
        #expect(voice.topics == [
            VoiceTopicEntry(topic: .niche(.travel), subtopics: ["Cheap flights"]),
            VoiceTopicEntry(topic: .extra(.cars)),
            VoiceTopicEntry(topic: .custom("Van life")),
        ])
        #expect(voice.niches == [.travel])
        #expect(voice.speaksAs == .i)
        #expect(voice.audienceGroup == .youngAdults && voice.audienceNote == "Gap-year people")
        #expect(voice.watchReasons == [.solveProblem] && voice.contentGoals == [.sell])
        #expect(voice.customRole == "Travel photographer" && voice.credential == "Pilot")
    }
}

private extension CreatorProfile {
    /// The same profile as it reads back after being written by this build.
    func with(schema: Int) -> CreatorProfile {
        var copy = self
        copy.voiceSchemaVersion = schema
        return copy
    }
}
