//
//  VoiceNotesAndExamplesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The owner's items 7 and 1 (02/11/2026): what the creator types lands where they can see it ("Also true about me", or the field it belongs
/// to), and each choice shows a live example line.
@MainActor
struct VoiceNotesAndExamplesTests {
    private func service() -> (CreatorProfileService, TestDefaults) {
        let defaults = TestDefaults()
        return (CreatorProfileService(defaults: defaults.defaults), defaults)
    }

    // MARK: - Item 7

    @Test func aNoteIsAddedChangedAndRemoved() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        #expect(service.addNote("I film in my car") == .added)
        #expect(service.addNote("i film in my car") == .alreadyThere)
        #expect(service.profile.notes == ["I film in my car"])
        #expect(service.replaceNote("I film in my car", with: "I film at the gym") == .added)
        #expect(service.profile.notes == ["I film at the gym"])
        #expect(service.replaceNote("I film at the gym", with: "  ") == .removed)
        #expect(service.profile.notes.isEmpty)
        #expect(service.addNote("a") == .rejected(.tooShort))
    }

    @Test func theFormatTagsStayWithTheFormats() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        let formatTag = VoiceQuestion.formatTags.values.first ?? "Talking head"
        service.profile.customTags = [formatTag, "Mom of two"]
        #expect(service.profile.notes == ["Mom of two"])
    }

    @Test func aTypedKindOfCreatorOrAudienceGoesToItsOwnField() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        #expect(service.addSomethingElse("Wedding photographer", for: .role) == .added)
        #expect(service.profile.customRole == "Wedding photographer")
        #expect(service.addSomethingElse("New dads", for: .audience) == .added)
        #expect(service.profile.audienceNote == "New dads")
        #expect(service.profile.notes.isEmpty, "nothing hidden as a note")
        #expect(service.addSomethingElse("Slow and warm", for: .tone) == .added)
        #expect(service.profile.notes == ["Slow and warm"], "no place of its own: shown in Also true about me")
    }

    // MARK: - Item 1

    @Test func eachChoiceHasItsOwnExampleLine() {
        let lines = VoiceChoiceCatalog.openings.map { VoiceSampleBuilder.openingExample($0.id) }
        #expect(Set(lines).count == lines.count, "seven openings, seven lines")
        #expect(VoiceSampleBuilder.openingExample("Fala, galera!") == "Fala, galera!", "their own words are the example")
        let endings = VoiceChoiceCatalog.endings.map { VoiceSampleBuilder.endingExample($0.id) }
        #expect(Set(endings).count == endings.count && endings.allSatisfy { !$0.isEmpty })
        let words = WordLevel.allCases.map(VoiceSampleBuilder.wordsExample)
        #expect(Set(words).count == WordLevel.allCases.count)
    }

    @Test func theSentencesExampleFollowsTheChoice() {
        var profile = CreatorProfile()
        let lines = SentenceLength.allCases.map { length in
            profile.style.sentences = length
            return VoiceSampleBuilder.bodyLine(for: profile)
        }
        #expect(Set(lines).count == SentenceLength.allCases.count)
    }
}
