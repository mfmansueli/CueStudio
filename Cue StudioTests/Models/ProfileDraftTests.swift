//
//  ProfileDraftTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Edit Profile (9.1): the name and the username are optional; typed, a name fits in 40 characters and a username is 2–24 of a–z 0–9 . _
@Suite("Edit Profile draft")
struct ProfileDraftTests {
    private func draft(name: String = "Maya Costa", handle: String = "mayacooks") -> ProfileDraft {
        ProfileDraft(CreatorProfile(name: name, handle: handle))
    }

    @Test func aFilledProfileIsValid() {
        #expect(draft().isValid)
        #expect(draft().handleError == nil)
    }

    @Test func theNameIsOptionalAndFitsInFortyCharacters() {
        #expect(draft(name: "").isValid)
        #expect(draft(name: "   ").isValid, "spaces alone are kept as no name")
        #expect(draft(name: String(repeating: "a", count: 40)).isValid)
        #expect(!draft(name: String(repeating: "a", count: 41)).isValid)
        #expect(draft(name: String(repeating: "a", count: 41)).nameError == "Up to 40 characters")
    }

    /// The owner's case (21/10/2026): a profile without a name or a username still saves a platform or a creator type.
    @Test func anEmptyProfileStillSavesWhatElseIsChosen() {
        var empty = ProfileDraft(CreatorProfile(name: "", handle: ""))
        empty.defaultPlatform = .reels
        empty.role = .educator
        #expect(empty.isValid)
        #expect(empty.applied(to: CreatorProfile(name: "", handle: "")).defaultPlatform == .reels)
    }

    @Test func theUsernameNeedsTwoToTwentyFourCharacters() {
        #expect(!draft(handle: "a").isValid)
        #expect(draft(handle: "ab").isValid)
        #expect(draft(handle: String(repeating: "a", count: 24)).isValid)
        #expect(!draft(handle: String(repeating: "a", count: 25)).isValid)
    }

    @Test func typingTurnsTheUsernameIntoLowercaseWithoutSpacesOrSymbols() {
        #expect(ProfileDraft.sanitized("Maya Cooks!") == "mayacooks")
        #expect(ProfileDraft.sanitized("maya_cooks.2026") == "maya_cooks.2026")
        #expect(ProfileDraft.sanitized("@maya-é") == "maya")
    }

    @Test func aWrongUsernameShowsTheError() {
        #expect(draft(handle: "a").handleError == "Use 2–24 letters, numbers, . or _")
        #expect(draft(handle: "").handleError == nil, "an empty username is fine")
        #expect(draft(handle: "").isValid)
    }

    @Test func applyingTheDraftChangesOnlyItsFieldsAndTrimsTheName() {
        var original = CreatorProfile(name: "Old", handle: "old", defaultPlatform: .reels)
        original.phrases = ["Hey fam"]
        var edited = ProfileDraft(original)
        edited.name = "  Maya Costa  "
        edited.handle = "mayacooks"
        edited.role = .educator
        edited.photoData = Data([1, 2, 3])
        let result = edited.applied(to: original)
        #expect(result.name == "Maya Costa")
        #expect(result.handle == "mayacooks")
        #expect(result.role == .educator)
        #expect(result.photoData == Data([1, 2, 3]))
        #expect(result.phrases == ["Hey fam"])
        #expect(result.defaultPlatform == .reels)
    }

    @Test func thePhotoSurvivesSavingAndLoading() throws {
        var profile = CreatorProfile(name: "Maya")
        profile.photoData = Data([9, 8, 7])
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(profile))
        #expect(decoded.photoData == Data([9, 8, 7]))
        #expect(try JSONDecoder().decode(CreatorProfile.self, from: Data(#"{"name":"Maya"}"#.utf8)).photoData == nil)
    }

    /// A creator type of their own wins over the list's, is trimmed, and an empty one is none (owner's ask, 21/10/2026).
    @Test func aCreatorTypeOfTheirOwnIsKeptTrimmed() {
        var edited = draft()
        edited.role = .educator
        edited.customRole = "  Podcaster "
        #expect(edited.creatorType == "  Podcaster ")
        let saved = edited.applied(to: CreatorProfile(name: "Maya", handle: "maya"))
        #expect(saved.customRole == "Podcaster")
        edited.customRole = "   "
        #expect(edited.applied(to: CreatorProfile()).customRole == nil)
        edited.customRole = nil
        #expect(edited.creatorType == CreatorRole.educator.creatorLabel)
    }
}
