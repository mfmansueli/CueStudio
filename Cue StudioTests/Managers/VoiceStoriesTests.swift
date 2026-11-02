//
//  VoiceStoriesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "Stories and facts" (the owner's item 9, 02/11/2026): true moments the creator told, read as examples of how they tell things and used only
/// when they fit the idea.
@MainActor
struct VoiceStoriesTests {
    private let start = VoiceStory(kind: .start, text: "I started filming in my car because it was the only quiet place at home.")
    private let client = VoiceStory(kind: .clientResult, text: "Ana ran her first 10K after twelve weeks of my plan.")

    @Test func aMomentIsKeptAsToldWithinItsLimits() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = CreatorProfileService(defaults: defaults.defaults)
        #expect(service.addStory("Too short", kind: .other) == .tooShort)
        #expect(service.addStory(start.text, kind: .start, said: true) == .added)
        #expect(service.profile.stories.first?.said == true && service.profile.stories.first?.text == start.text)
        for index in 1..<VoiceStory.limit { service.addStory("A true moment number \(index) from my work.", kind: .other) }
        #expect(service.addStory("One more true moment from my work.", kind: .other) == .limit)
        #expect(service.profile.stories.count == VoiceStory.limit)
        service.removeStory(service.profile.stories[0].id)
        #expect(service.profile.stories.count == VoiceStory.limit - 1)
    }

    @Test func theModelReadsThemAsTrueAndUsesOneOnlyWhenItFits() {
        var profile = CreatorProfile()
        profile.role = .educator
        profile.stories = [start, client]
        let brief = VoiceBriefBuilder.brief(for: profile.voice).text
        #expect(brief.contains(VoiceBriefBuilder.storiesHeader))
        #expect(brief.contains("- How they started: “\(start.text)”"))
        #expect(brief.contains("- A client's result (never name the person): “\(client.text)”"))
        profile.stories[1].mayName = true
        #expect(VoiceBriefBuilder.brief(for: profile.voice).text.contains("- A client's result: “\(client.text)”"))
    }

    @Test func theOneAboutTheIdeaGoesFirst() {
        var profile = CreatorProfile()
        profile.stories = [start, client]
        #expect(profile.voice(inLanguage: "en", idea: "My first 10K training plan").stories.first == client)
    }

    @Test func ultraAIAndTheCatalogOnlyRetryNeverGetThem() {
        var profile = CreatorProfile()
        profile.role = .educator
        profile.stories = [start]
        let ultra = VoiceBriefBuilder.ultraProjection(for: profile.voice, register: .casual)
        #expect(!(ultra.content + ultra.delivery).contains(start.text))
        #expect(profile.voice.catalogOnly.stories.isEmpty)
    }

    @Test func theyLastAcrossLaunches() throws {
        var profile = CreatorProfile()
        profile.stories = [client]
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(profile))
        #expect(decoded.stories == [client])
    }
}
