//
//  IdeaFocusTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The idea says what the video is about, the voice says how they sound (`IdeaFocus`): the creator who asked for "my daily routine with AI is not going so
/// well" and got "Bureaucracy in 5 Minutes" because their topics were "Daily Routine (Bureaucracy)" and "Languages (Italian)".
@MainActor
@Suite("Idea focus")
struct IdeaFocusTests {
    /// What was found on the owner's iPhone, in the fields that matter here.
    private static let owner = """
    {"customRole":"Daily Routine","voiceTopics":["languages"],"customTopics":["Daily Routine"],
     "topicDetails":{"Daily Routine":["Bureaucracy"],"languages":["Italian"]},"audienceGroup":"youngAdults",
     "sounds":["casual","funny"],"usesVoiceInAI":true,"voiceApproved":true}
    """

    private static func profile() throws -> CreatorProfile {
        try JSONDecoder().decode(CreatorProfile.self, from: Data(owner.utf8))
    }

    private func topics(_ profile: CreatorProfile, idea: String?) -> [String] {
        profile.voice(inLanguage: "en", idea: idea).topics.map { entry in
            entry.subtopics.isEmpty ? entry.topic.promptName : "\(entry.topic.promptName) (\(entry.subtopics.joined(separator: ", ")))"
        }
    }

    @Test func theCreatorHasBothTopicsAndTheirSubtopics() throws {
        #expect(topics(try Self.profile(), idea: nil) == ["language learning (Italian)", "Daily Routine (Bureaucracy)"])
    }

    @Test func anIdeaOutsideTheirTopicsSendsNone() throws {
        #expect(topics(try Self.profile(), idea: "why my cat sleeps on the keyboard").isEmpty)
        #expect(topics(try Self.profile(), idea: "three mistakes when you start investing").isEmpty)
    }

    @Test func anIdeaAboutATopicKeepsItWithoutSubtopicsItDidNotName() throws {
        #expect(topics(try Self.profile(), idea: "my daily routine with AI is not going so well") == ["Daily Routine"])
    }

    @Test func aSubtopicTheIdeaNamesStays() throws {
        #expect(topics(try Self.profile(), idea: "my daily routine fighting bureaucracy at the town hall") == ["Daily Routine (Bureaucracy)"])
        #expect(topics(try Self.profile(), idea: "learning Italian in ten minutes a day") == ["language learning (Italian)"])
    }

    @Test func aWordThatStartsLikeTheTopicIsTheTopic() throws {
        #expect(topics(try Self.profile(), idea: "routines that changed my mornings") == ["Daily Routine"])
        #expect(topics(try Self.profile(), idea: "what I learned about languages this year") == ["language learning"])
    }

    @Test func noIdeaOrAHintOfOneKeepsEveryTopic() throws {
        #expect(topics(try Self.profile(), idea: "").count == 2)
        #expect(topics(try Self.profile(), idea: "tips").count == 2, "one word says too little to tell what it is about")
    }

    @Test func accentsAndCaseDoNotMatter() throws {
        var profile = try Self.profile()
        profile.customTopics = ["Educação"]
        #expect(profile.voice(inLanguage: "pt", idea: "EDUCACAO financeira para crianças").topics.map(\.topic.promptName) == ["Educação"])
    }

    @Test func theRequestSentToTheModelIsAboutTheIdea() throws {
        let profile = try Self.profile()
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = CreatorProfileService(defaults: defaults.defaults)
        service.profile = profile
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: service, scriptLanguage: nil, interfaceLanguage: .english, preferredLanguages: ["en-US"]
        )
        let request = factory.request(idea: "my daily routine with AI is not going so well", platform: .tiktok, format: nil)
        let sent = ScriptPromptBuilder.instructions(for: request) + "\n" + ScriptPromptBuilder.prompt(for: request)
        #expect(!sent.contains("Bureaucracy") && !sent.contains("Italian"), "a subtopic the idea never named reached the model")
        #expect(sent.contains("Topics: Daily Routine."))
        #expect(sent.contains("The video: my daily routine with AI is not going so well"))
        #expect(sent.contains("Write about this idea and only this one"))
        #expect(sent.hasSuffix(" Stay on the idea: my daily routine with AI is not going so well"))
    }
}
