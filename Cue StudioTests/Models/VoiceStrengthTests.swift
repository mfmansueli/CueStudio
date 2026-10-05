//
//  VoiceStrengthTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// 08 §1: strength = Essentials 40 (kind of creator, topics, audience with its level, tone, 10 each) + Personality 40 (style, formats,
/// openings, endings and phrases at 6 each, what to avoid and reach at 5 each) + Proof 20 (1 example 8, 2 → 14, 3 → 20).
@Suite("My Cue Voice strength")
struct VoiceStrengthTests {
    private var essentials: CreatorProfile {
        var profile = CreatorProfile(niches: [.tech], role: .personal)
        profile.confirm(.audience)
        profile.confirm(.tone)
        profile.audienceLevel = .some
        return profile
    }

    @Test func aNewProfileKnowsNothing() {
        #expect(CreatorProfile().voiceStrength == 0)
    }

    @Test func essentialsAreWorthFortyPercent() {
        #expect(essentials.voiceStrength == 40)
    }

    @Test func eachEssentialIsTen() {
        #expect(CreatorProfile(role: .personal).voiceStrength == 10)
        #expect(CreatorProfile(niches: [.tech]).voiceStrength == 10)
        var tone = CreatorProfile()
        tone.confirm(.tone)
        #expect(tone.voiceStrength == 10)
    }

    @Test func theAudienceNeedsItsLevelToo() {
        var audience = CreatorProfile()
        audience.confirm(.audience)
        #expect(audience.voiceStrength == 0)
        audience.audienceLevel = .experienced
        #expect(audience.voiceStrength == 10)
    }

    @Test func personalityIsFortyPercent() {
        var profile = essentials
        profile.openings = ["Okay, real talk."]
        #expect(profile.voiceStrength == 46)
        profile.endings = ["Save this."]
        profile.phrases = ["Hey fam"]
        profile.formats = [.tutorial]
        #expect(profile.voiceStrength == 64)
        profile.avoid = ["Clickbait"]
        #expect(profile.voiceStrength == 69)
    }

    @Test func nothingToAvoidCountsAsAnswered() {
        var profile = CreatorProfile()
        profile.avoidNone = true
        #expect(profile.voiceStrength == 5)
    }

    @Test func styleAndReachCountOnlyWhenEveryQuestionIsAnswered() {
        var profile = CreatorProfile()
        profile.style = VoiceDelivery(energy: .calm, sentences: .short, words: .plain)
        #expect(profile.voiceStrength == 0)
        profile.swearing = .never
        #expect(profile.voiceStrength == 6)
        profile.reach = VoiceReach(platforms: [.tiktok], length: .thirtyToSixty)
        #expect(profile.voiceStrength == 6)
        profile.reach.humor = .little
        #expect(profile.voiceStrength == 11)
    }

    @Test func proofIsTwentyPercentAndStopsAtThreeExamples() {
        var profile = CreatorProfile()
        profile.examples = [VoiceExample(text: "One")]
        #expect(profile.voiceStrength == 8)
        profile.examples.append(VoiceExample(text: "Two"))
        #expect(profile.voiceStrength == 14)
        profile.examples = (1...5).map { VoiceExample(text: "Example \($0)") }
        #expect(profile.voiceStrength == 20)
    }

    @Test func everyTwoApprovalsCountAsOneExample() {
        var profile = CreatorProfile()
        profile.approvals = 1
        #expect(profile.voiceStrength == 0)
        profile.approvals = 2
        #expect(profile.voiceStrength == 8)
        profile.examples = [VoiceExample(text: "Mine")]
        #expect(profile.voiceStrength == 14)
    }

    @Test func aFullProfileIsOneHundred() {
        var profile = essentials
        profile.openings = ["a"]
        profile.endings = ["b"]
        profile.phrases = ["c"]
        profile.formats = [.list]
        profile.style = VoiceDelivery(energy: .high, sentences: .mixed, words: .someSlang, swearing: .mild)
        profile.avoid = ["Politics"]
        profile.reach = VoiceReach(platforms: [.reels], length: .longer, humor: .lot)
        profile.examples = (1...3).map { VoiceExample(text: "Example \($0)") }
        #expect(profile.voiceStrength == 100)
        #expect(profile.nextQuestion == nil)
    }

    @Test func theWeightsAddUpToOneHundred() {
        #expect(VoiceField.allCases.reduce(0) { $0 + $1.weight } == 100)
        #expect(VoiceField.fields(of: .essentials).reduce(0) { $0 + $1.weight } == 40)
        #expect(VoiceField.fields(of: .personality).reduce(0) { $0 + $1.weight } == 40)
        #expect(VoiceField.fields(of: .proof).reduce(0) { $0 + $1.weight } == 20)
    }

    @Test func swearingMigratesIntoTheStyle() throws {
        let never = try JSONDecoder().decode(CreatorProfile.self, from: Data(#"{"swearing":"never"}"#.utf8))
        #expect(never.style.swearing == .never)
        let mild = try JSONDecoder().decode(CreatorProfile.self, from: Data(#"{"swearing":"mild"}"#.utf8))
        #expect(mild.style.swearing == .mild)
        let flagOn = try JSONDecoder().decode(CreatorProfile.self, from: Data(#"{"swearing":true}"#.utf8))
        #expect(flagOn.style.swearing == .mild)
        let flagOff = try JSONDecoder().decode(CreatorProfile.self, from: Data(#"{"swearing":false}"#.utf8))
        #expect(flagOff.style.swearing == .never)
        let absent = try JSONDecoder().decode(CreatorProfile.self, from: Data(#"{"name":"A"}"#.utf8))
        #expect(absent.style.swearing == nil)
        #expect(absent.avoid.isEmpty && !absent.avoidNone && absent.reach.isEmpty && absent.audienceLevel == nil && absent.approvals == 0)
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
        #expect(profile.voiceStrength == 40)
    }

    @Test func theNewFieldsRoundTrip() throws {
        var profile = essentials
        profile.openings = ["Okay, real talk."]
        profile.endings = ["Save this."]
        profile.formats = [.mythFact, .pov]
        profile.swearing = .mild
        profile.avoid = ["Politics"]
        profile.reach = VoiceReach(platforms: [.shorts], length: .oneToThree, humor: .noHumor)
        profile.audienceLevel = .new
        profile.approvals = 3
        profile.examples = [VoiceExample(text: "My own words", source: "Pasted")]
        profile.customTags = ["Slow living"]
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(profile))
        #expect(decoded.openings == profile.openings)
        #expect(decoded.formats == [.mythFact, .pov])
        #expect(decoded.swearing == .mild)
        #expect(decoded.avoid == ["Politics"])
        #expect(decoded.reach == VoiceReach(platforms: [.shorts], length: .oneToThree, humor: .noHumor))
        #expect(decoded.audienceLevel == .new)
        #expect(decoded.approvals == 3)
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
