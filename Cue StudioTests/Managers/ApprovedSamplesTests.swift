//
//  ApprovedSamplesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "Sounds like me" teaches Cue (plan stage 5): the opening of an approved script is kept on this iPhone, three at most, and sent as examples of how the
/// creator writes.
@MainActor
@Suite("Approved scripts")
struct ApprovedSamplesTests {
    private func service() -> (CreatorProfileService, TestDefaults) {
        let defaults = TestDefaults()
        return (CreatorProfileService(defaults: defaults.defaults), defaults)
    }

    private func script(_ topic: String) -> String {
        "[smile] Okay, real talk. \(topic) is hard for everybody. [pause]\n\nHere is what changed it for me, in plain words. "
            + String(repeating: "More words about \(topic) go here. ", count: 12)
    }

    @Test func anApprovalCountsAndKeepsTheOpeningOfTheScriptWithoutItsCues() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        #expect(service.recordApproval(of: script("Mornings")))
        #expect(service.profile.approvals == 1)
        let sample = service.profile.approvedSamples.first
        #expect(sample?.source == "Sounds like me")
        #expect(sample?.text.hasPrefix("Okay, real talk. Mornings is hard for everybody.") == true)
        #expect(sample?.text.contains("[") == false && sample?.text.contains("\n") == false)
        #expect((sample?.text.count ?? 0) <= VoiceExample.sentCharacters)
    }

    @Test func threeAreKeptAndTheOldestGoesWhenAFourthComes() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        for topic in ["One", "Two", "Three", "Four"] { service.recordApproval(of: script(topic)) }
        #expect(service.profile.approvedSamples.count == VoiceLimits.approvedSamples)
        #expect(service.profile.approvedSamples.map { $0.text.contains("Four") }.last == true)
        #expect(!service.profile.approvedSamples.contains { $0.text.hasPrefix("Okay, real talk. One ") })
        #expect(service.profile.approvals == 4, "every approval counts, kept or not")
    }

    @Test func theSameScriptIsNotKeptTwice() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        service.recordApproval(of: script("Mornings"))
        service.recordApproval(of: script("Mornings"))
        #expect(service.profile.approvedSamples.count == 1 && service.profile.approvals == 2)
    }

    @Test func aScriptWithWordsTheModelWontLearnFromOrTooLittleOnlyCountsAsAnApproval() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        #expect(!service.recordApproval(of: "Short."))
        #expect(!service.recordApproval(of: "What the fuck is going on with mornings, really, I mean it, tell me."))
        #expect(service.profile.approvedSamples.isEmpty && service.profile.approvals == 2)
    }

    @Test func anApprovedScriptCanBeRemovedAndIsSentAsAnExample() throws {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        service.recordApproval(of: script("Mornings"))
        service.profile.niches = [.lifestyle]
        let voice = service.profile.voice
        #expect(voice.approvedSamples.count == 1)
        #expect(VoiceBriefBuilder.brief(for: voice).text.contains("Here is how they write"))
        let id = try #require(service.profile.approvedSamples.first?.id)
        service.removeApprovedSample(id)
        #expect(service.profile.approvedSamples.isEmpty)
        #expect(!VoiceBriefBuilder.brief(for: service.profile.voice).text.contains("Here is how they write"))
    }

    @Test func deletingMyCueDataClearsWhatCueLearned() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        service.recordApproval(of: script("Mornings"))
        service.profile = CreatorProfile()
        #expect(service.profile.approvedSamples.isEmpty && service.profile.approvals == 0)
        let reloaded = CreatorProfileService(defaults: defaults.defaults)
        #expect(reloaded.profile.approvedSamples.isEmpty)
    }
}
