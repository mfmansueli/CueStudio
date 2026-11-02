//
//  TypedPersonalityTagsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// An opening, ending or catchphrase the creator typed lives in its own field only: it is told to the model once, leaves the brief when it is removed,
/// and a profile an older build saved (which also copied it into `customTags`) loses the copies but keeps the notes that match nothing
/// (`reports/entradas-do-criador-2026-11-01-completo.md` §11, A1).
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

    private func occurrences(of value: String, in text: String) -> Int {
        text.components(separatedBy: value).count - 1
    }

    @Test func aTypedCatchphraseIsSaidOnce() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        _ = service.addCustom("Hey fam", for: .phrases, keepingTyped: true)
        let text = brief(service.profile)
        #expect(service.profile.customTags.isEmpty)
        #expect(occurrences(of: "Hey fam", in: text) == 1, "the catchphrase is in the brief \(occurrences(of: "Hey fam", in: text)) times · brief: \(text)")
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

    @Test func everyKeptCatchphraseIsToldOnceInItsOwnLine() {
        var profile = CreatorProfile(role: .personal, sounds: [.casual], confirmedVoiceSteps: [.tone])
        profile.phrases = ["Hey fam", "Let's go", "Real talk", "Stay curious", "See ya"]
        let text = brief(profile)
        #expect(text.contains("They often say: “Hey fam”, “Let's go”, “Real talk”, “Stay curious”, “See ya”."), "the line no budget cuts: \(text)")
        #expect(!text.contains("Also true of them"), "and not again among the tags")
        for phrase in profile.phrases {
            #expect(occurrences(of: phrase, in: text) == 1, "“\(phrase)” is told \(occurrences(of: phrase, in: text)) times")
        }
    }

    @Test func anOlderProfileLosesTheCopiesAndKeepsItsNotes() throws {
        var saved = CreatorProfile(role: .personal, sounds: [.casual], confirmedVoiceSteps: [.tone])
        saved.openings = ["Okay, real talk"]
        saved.endings = ["See you Sunday"]
        saved.phrases = ["Hey fam"]
        // What an older build saved: each typed value copied, a copy left behind by an opening the creator removed (it can't be told from a note),
        // a note typed under "Something else" and a format kept as a tag.
        saved.customTags = ["Okay, real talk", "see you sunday", "Hey fam", "Whisper a secret", "Night owl", "Talking head"]
        let loaded = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(saved))
        #expect(loaded.customTags == ["Whisper a secret", "Night owl", "Talking head"])
        #expect(loaded.openings == ["Okay, real talk"] && loaded.endings == ["See you Sunday"], "nothing of the fields is lost")
        #expect(loaded.phrases == ["Hey fam"])
        let text = brief(loaded)
        #expect(occurrences(of: "Hey fam", in: text) == 1)
        #expect(text.contains("Night owl") && text.contains("Whisper a secret"), "a tag that matches nothing stays: it may be the creator's own note")
    }
}
