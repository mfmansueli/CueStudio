//
//  ProfileDraftTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Edit Profile (9.1): Done waits for a name of 1–40 characters and a username of 2–24 of a–z 0–9 . _
@Suite("Edit Profile draft")
struct ProfileDraftTests {
    private func draft(name: String = "Maya Costa", handle: String = "mayacooks") -> ProfileDraft {
        ProfileDraft(CreatorProfile(name: name, handle: handle))
    }

    @Test func aFilledProfileIsValid() {
        #expect(draft().isValid)
        #expect(draft().handleError == nil)
    }

    @Test func theNameNeedsOneToFortyCharacters() {
        #expect(!draft(name: "").isValid)
        #expect(!draft(name: "   ").isValid, "spaces alone are not a name")
        #expect(draft(name: String(repeating: "a", count: 40)).isValid)
        #expect(!draft(name: String(repeating: "a", count: 41)).isValid)
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
        #expect(draft(handle: "").handleError == nil, "an empty field is not scolded, Done is just off")
        #expect(!draft(handle: "").isValid)
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
}
