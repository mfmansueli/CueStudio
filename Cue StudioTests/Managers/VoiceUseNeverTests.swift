//
//  VoiceUseNeverTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "I use" and "I never use" in the openings and endings (the owner's item 5, 02/11/2026), and the main ending.
@MainActor
struct VoiceUseNeverTests {
    private func service() -> (CreatorProfileService, TestDefaults) {
        let defaults = TestDefaults()
        return (CreatorProfileService(defaults: defaults.defaults), defaults)
    }

    private func option(_ id: String) -> VoiceOption { VoiceOption(id: id, label: id) }

    @Test func aTapGoesFromOffToIUseToINeverUseAndBack() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        let question = option("Question")
        #expect(service.cycle(question, for: .openings) == .added)
        #expect(service.choiceState(question, for: .openings) == .uses)
        #expect(service.cycle(question, for: .openings) == .added)
        #expect(service.choiceState(question, for: .openings) == .never)
        #expect(service.profile.openings.isEmpty && service.profile.neverOpenings == ["Question"])
        #expect(service.cycle(question, for: .openings) == .removed)
        #expect(service.choiceState(question, for: .openings) == .off)
    }

    @Test func noCallToActionIsNeverANever() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        let none = option("No call to action")
        service.cycle(none, for: .endings)
        service.cycle(none, for: .endings)
        #expect(service.choiceState(none, for: .endings) == .off, "the second tap takes it out: never asking is Avoid's")
        #expect(service.markNever(none, for: .endings) == .alreadyThere)
    }

    @Test func theNeversHaveALimit() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        for id in ["Bold claim", "Question", "POV"] { service.markNever(option(id), for: .openings) }
        if case .limit = service.markNever(option("Story opener"), for: .openings) {} else { Issue.record("a fourth never went in") }
        #expect(service.profile.neverOpenings.count == VoiceLimits.never)
    }

    @Test func theMainEndingIsTheFirst() throws {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        service.cycle(option("Save this"), for: .endings)
        service.cycle(option("Try it and tell me"), for: .endings)
        service.makeMainEnding("Try it and tell me")
        #expect(service.profile.endings == ["Try it and tell me", "Save this"])
        service.markNever(option("Link in bio"), for: .endings)
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(service.profile))
        #expect(decoded.neverEndings == ["Link in bio"] && decoded.endings.first == "Try it and tell me")
    }

    @Test func theModelReadsWhatTheyNeverUse() {
        var profile = CreatorProfile()
        profile.role = .educator
        profile.neverOpenings = ["Bold claim", "POV"]
        profile.neverEndings = ["Link in bio"]
        let brief = VoiceBriefBuilder.brief(for: profile.voice).text
        #expect(brief.contains("Never open with a bold claim or a POV line (“POV: …”)."))
        #expect(brief.contains("Never end by pointing to the link in bio."))
        #expect(VoiceBriefBuilder.ultraProjection(for: profile.voice, register: .casual).delivery.contains("Never open with a bold claim"))
        // One they use wins over a never an older answer left.
        profile.openings = ["POV"]
        #expect(profile.voice.neverOpenings == ["Bold claim"])
    }
}
