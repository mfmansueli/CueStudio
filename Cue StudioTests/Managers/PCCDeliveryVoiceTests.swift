import Testing
@testable import Cue_Studio

@Suite("Cloud delivery-only voice experiment")
struct PCCDeliveryVoiceTests {
    private static func request() -> ScriptRequest {
        var voice = VoicePersonas.saasFounder.profile.voice
        voice.customRole = "TEST_ROLE"
        voice.credential = "TEST_CREDENTIAL"
        voice.audienceNote = "TEST_AUDIENCE"
        voice.customTags = ["Keep a dry tone."]
        var request = ScriptRequest(
            source: .prompt("Explain camera choices and include exactly: Keep the useful parts."),
            platform: .reels, tone: nil, voice: voice, targetRange: 60...90, language: .english
        )
        request.durationPolicy = .informative
        request.formatChoice = .talkingHead
        request.brief = IdeaBrief(subject: "Camera choices", angle: "Choose for the actual problem", openingLine: "Start with the problem.")
        return request
    }

    @Test func removesBiographicalAndTopicContextButRetainsDeliveryAndRestrictions() throws {
        let original = Self.request()
        let before = try #require(original.voice)
        let projected = PCCDeliveryVoice.prepare(original, on: .privateCloud)
        let after = try #require(projected.voice)
        #expect(after.role == nil && after.customRole == nil && after.credential == nil)
        #expect(after.niches.isEmpty && after.topics.isEmpty)
        #expect(after.audienceGroup == nil && after.audienceNote == nil)
        #expect(after.openings.isEmpty && after.endings.isEmpty && after.formats.isEmpty)
        #expect(after.watchReasons.isEmpty && after.contentGoals.isEmpty)
        #expect(after.reach.platforms.isEmpty && after.reach.length == nil)
        #expect(after.resolvedSpeaksAs == before.resolvedSpeaksAs)
        #expect(after.style == before.style && after.sounds == before.sounds && after.styles == before.styles)
        #expect(after.avoid == before.avoid && after.swearing == before.swearing)
        #expect(after.phrases == before.phrases && after.customTags == before.customTags)
        #expect(after.vocabulary == before.vocabulary && after.audienceLevel == before.audienceLevel)
        #expect(after.reach.humor == before.reach.humor && after.fingerprint == before.fingerprint)
        var withoutVoiceChange = projected
        withoutVoiceChange.voice = original.voice
        #expect(withoutVoiceChange == original, "The experiment must not change the request, selected format, angle or literals")
        #expect(original.voice == before, "The saved profile/request is not mutated")
    }

    @Test func doesNotChangeLocalOrTargetedRequests() {
        let original = Self.request()
        #expect(PCCDeliveryVoice.prepare(original, on: .onDevice) == original)
        var explicit = original
        explicit.durationPolicy = .targeted
        #expect(PCCDeliveryVoice.prepare(explicit, on: .privateCloud) == explicit)
        var noVoice = original
        noVoice.voice = nil
        #expect(PCCDeliveryVoice.prepare(noVoice, on: .privateCloud) == noVoice)
    }
}
