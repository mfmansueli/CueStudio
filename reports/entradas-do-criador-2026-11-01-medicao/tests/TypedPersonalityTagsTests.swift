//
//  TypedPersonalityTagsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Audit check (`reports/entradas-do-criador-2026-11-01-completo.md`, finding P1-4): an opening, ending or catchphrase the creator typed and then
/// removed must leave the brief the AI reads, and must be said once while it is there.
@MainActor
struct TypedPersonalityTagsTests {
    private func service() -> (CreatorProfileService, TestDefaults) {
        let defaults = TestDefaults()
        let service = CreatorProfileService(defaults: defaults.defaults)
        service.profile = CreatorProfile(role: .personal, sounds: [.casual], confirmedVoiceSteps: [.tone])
        return (service, defaults)
    }

    private func brief(_ profile: CreatorProfile) -> String {
        VoiceBriefBuilder.brief(for: profile.voice).text
    }

    @Test func aTypedCatchphraseIsSaidOnce() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        _ = service.addCustom("Hey fam", for: .phrases, keepingTyped: true)
        let text = brief(service.profile)
        let count = text.components(separatedBy: "Hey fam").count - 1
        #expect(count == 1, "the catchphrase is in the brief \(count) times · customTags \(service.profile.customTags) · brief: \(text)")
    }

    @Test func aRemovedTypedOpeningLeavesTheBrief() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        _ = service.addCustom("Okay, real talk", for: .openings, keepingTyped: true)
        #expect(brief(service.profile).contains("Okay, real talk"))
        _ = service.toggle("Okay, real talk", for: .openings)
        let text = brief(service.profile)
        #expect(
            !text.contains("Okay, real talk"),
            "a removed opening is still sent · openings \(service.profile.openings) · customTags \(service.profile.customTags) · brief: \(text)"
        )
    }
}
