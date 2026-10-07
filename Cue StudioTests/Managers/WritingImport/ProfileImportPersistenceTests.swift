//
//  ProfileImportPersistenceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What an import leaves in the profile survives a restart, and an older profile opens as before.
@Suite("Import my writing · profile")
struct ProfileImportPersistenceTests {
    @Test func excerptsAndMeasuresRoundTrip() throws {
        let analysis = WritingAnalyzer.analyze(WritingSamples.maya.map { WritingPiece(text: $0) })
        var profile = CreatorProfile()
        profile.excerpts = analysis.excerpts
        profile.fingerprint = analysis.fingerprint
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(profile))
        #expect(decoded.excerpts == analysis.excerpts)
        #expect(decoded.fingerprint == analysis.fingerprint)
    }

    @Test func aProfileSavedBeforeImportsOpensWithNothingImported() throws {
        let data = try JSONEncoder().encode(CreatorProfile())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "excerpts")
        object.removeValue(forKey: "fingerprint")
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.excerpts.isEmpty && decoded.fingerprint == nil)
    }

    @Test func aDamagedExcerptListDoesNotKeepTheProfileFromOpening() throws {
        let data = try JSONEncoder().encode(CreatorProfile())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["excerpts"] = "garbage"
        object["fingerprint"] = ["nope": 1]
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.excerpts.isEmpty && decoded.fingerprint == nil)
    }

    @Test func atMostTwentyFourAreKept() throws {
        let many = (0..<40).map { VoiceExcerpt(text: "Excerpt number \($0) has enough words in it to count as something the creator wrote.") }
        let profile = CreatorProfile(excerpts: many)
        #expect(profile.excerpts.count == VoiceExcerpt.limit)
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(profile))
        #expect(decoded.excerpts.count == VoiceExcerpt.limit)
    }

    @Test func theVoiceCarriesWhatWasImported() {
        let analysis = WritingAnalyzer.analyze(WritingSamples.maya.map { WritingPiece(text: $0) })
        let profile = CreatorProfile(excerpts: analysis.excerpts, fingerprint: analysis.fingerprint)
        #expect(profile.voice.fingerprint == analysis.fingerprint)
        #expect(!profile.voice.excerpts.isEmpty && profile.voice.excerpts.count <= VoiceExample.limit)
        #expect(profile.voice.catalogOnly.excerpts.isEmpty, "what the creator wrote is not sent when the model refused it once")
    }

    @Test func theExamplesRowOfThePageCountsWhatWasImported() {
        var profile = CreatorProfile()
        #expect(profile.examplesPageValue.isEmpty)
        profile.excerpts = (1...3).map { VoiceExcerpt(text: "Excerpt \($0) has enough words in it to count as something the creator wrote on their own.") }
        #expect(profile.examplesPageValue == "Imported: 3")
        profile.examples = [VoiceExample(text: "One I pasted myself, long enough to be sent to the model as it is.")]
        #expect(profile.examplesPageValue == "1 of 6 · Imported: 3")
        profile.excerpts = []
        #expect(profile.examplesPageValue == "1 of 6")
    }
}
