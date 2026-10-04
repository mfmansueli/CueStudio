//
//  VoiceStrengthTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// 04 · F9: strength = Essentials 60% (kind of creator, topics, audience, tone) + Personality 25% (openings,
/// endings, catchphrases, formats, swearing) + Proof 15% (1–3 examples).
@Suite("My Cue Voice strength")
struct VoiceStrengthTests {
    private var essentials: CreatorProfile {
        var profile = CreatorProfile(niches: [.tech], role: .personal)
        profile.confirm(.audience)
        profile.confirm(.tone)
        return profile
    }

    @Test func aNewProfileKnowsNothing() {
        #expect(CreatorProfile().voiceStrength == 0)
    }

    @Test func essentialsAreWorthSixtyPercent() {
        #expect(essentials.voiceStrength == 60)
    }

    @Test func eachEssentialIsFifteen() {
        #expect(CreatorProfile(role: .personal).voiceStrength == 15)
        #expect(CreatorProfile(niches: [.tech]).voiceStrength == 15)
        var audience = CreatorProfile()
        audience.confirm(.audience)
        #expect(audience.voiceStrength == 15)
    }

    @Test func personalityIsTwentyFivePercentAtFiveEach() {
        var profile = essentials
        profile.openings = ["Okay, real talk."]
        #expect(profile.voiceStrength == 65)
        profile.endings = ["Save this."]
        profile.phrases = ["Hey fam"]
        profile.formats = [.tutorial]
        profile.swearing = .never
        #expect(profile.voiceStrength == 85)
    }

    @Test func proofIsFifteenPercentAndStopsAtThreeExamples() {
        var profile = essentials
        profile.examples = [VoiceExample(text: "One")]
        #expect(profile.voiceStrength == 65)
        profile.examples = (1...5).map { VoiceExample(text: "Example \($0)") }
        #expect(profile.voiceStrength == 75)
    }

    @Test func aFullProfileIsOneHundred() {
        var profile = essentials
        profile.openings = ["a"]
        profile.endings = ["b"]
        profile.phrases = ["c"]
        profile.formats = [.list]
        profile.swearing = .mild
        profile.examples = (1...3).map { VoiceExample(text: "Example \($0)") }
        #expect(profile.voiceStrength == 100)
        #expect(profile.nextQuestion == nil)
    }

    @Test func theNextQuestionIsTheFirstEmptyPersonalityItem() {
        var profile = essentials
        #expect(profile.nextQuestion == .endings)
        profile.endings = ["Save this."]
        #expect(profile.nextQuestion == .openings)
        profile.openings = ["Okay."]
        #expect(profile.nextQuestion == .formats)
        profile.formats = [.review]
        #expect(profile.nextQuestion == .swearing)
        profile.swearing = .never
        #expect(profile.nextQuestion == .phrases)
    }

    @Test func aQuestionPutOffIsSkippedNotAnswered() {
        let profile = essentials
        #expect(profile.nextQuestion(excluding: [.endings]) == .openings)
        #expect(profile.nextQuestion(excluding: Set(VoicePersonalityItem.allCases)) == nil)
        #expect(profile.voiceStrength == 60)
    }

    @Test func theNewFieldsRoundTrip() throws {
        var profile = essentials
        profile.openings = ["Okay, real talk."]
        profile.endings = ["Save this."]
        profile.formats = [.mythFact, .pov]
        profile.swearing = .mild
        profile.examples = [VoiceExample(text: "My own words", source: "Pasted")]
        profile.customTags = ["Slow living"]
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(profile))
        #expect(decoded.openings == profile.openings)
        #expect(decoded.formats == [.mythFact, .pov])
        #expect(decoded.swearing == .mild)
        #expect(decoded.examples.first?.text == "My own words")
        #expect(decoded.customTags == ["Slow living"])
    }

    @Test func aFormatFromANewerBuildIsDroppedButTheProfileOpens() throws {
        let json = #"{"name":"A","formats":["tutorial","holographic"],"swearing":"extreme"}"#
        let profile = try JSONDecoder().decode(CreatorProfile.self, from: Data(json.utf8))
        #expect(profile.formats == [.tutorial])
        #expect(profile.swearing == nil)
        #expect(profile.name == "A")
    }

    @Test func onlyThreeExamplesAreKeptOnDecoding() throws {
        var profile = CreatorProfile()
        profile.examples = (1...3).map { VoiceExample(text: "E\($0)") }
        var data = try JSONEncoder().encode(profile)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let first = try #require((object["examples"] as? [[String: Any]])?.first)
        object["examples"] = Array(repeating: first, count: 5)
        data = try JSONSerialization.data(withJSONObject: object)
        #expect(try JSONDecoder().decode(CreatorProfile.self, from: data).examples.count == 3)
    }

    @Test func anExampleSendsOnlyItsFirstThreeHundredCharacters() {
        let long = VoiceExample(text: String(repeating: "a", count: 500))
        #expect(long.sentText.count == VoiceExample.sentCharacters + 1)
        #expect(VoiceExample(text: "  Short  ").sentText == "Short")
    }
}
