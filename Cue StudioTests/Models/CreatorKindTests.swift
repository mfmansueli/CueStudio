//
//  CreatorKindTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "What kind of creator are you?": the long list (the owner, 03/11/2026: from a food reviewer to a lawyer who wins clients), kept on the profile
/// and said to the AI.
@Suite("Creator kind")
struct CreatorKindTests {
    @Test func theListIsLongAndEveryKindIsItsOwn() {
        let kinds = CreatorKind.all
        #expect(kinds.count >= 120)
        #expect(Set(kinds.map(\.id)).count == kinds.count)
        #expect(Set(kinds.map(\.title)).count == kinds.count, "no two kinds share a name")
        #expect(Set(kinds.map(\.promptName)).count == kinds.count)
        #expect(kinds.allSatisfy { !$0.themes.isEmpty && !$0.promptName.isEmpty && $0.promptName == $0.promptName.trimmingCharacters(in: .whitespaces) })
    }

    @Test func theKindsTheOwnerNamedAreThere() {
        for id in ["lawyer", "foodReviewer", "nutritionist", "ugcCreator", "beginner"] {
            #expect(CreatorKind.find(id) != nil, "\(id)")
        }
        #expect(CreatorKind.find("lawyer")?.themes.contains(.law) == true)
        #expect(CreatorKind.find("foodReviewer")?.themes.contains(.food) == true)
    }

    @Test func aKindSaysIOrWeWhereItsBroadKindWouldNot() throws {
        let ugc = try #require(CreatorKind.find("ugcCreator"))
        #expect(ugc.role == .brands && ugc.role.suggestedSpeaksAs == .we && ugc.suggestedSpeaksAs == .i)
        #expect(CreatorKind.find("church")?.suggestedSpeaksAs == .we)
        #expect(CreatorKind.find("lawyer")?.suggestedSpeaksAs == .i)
    }

    @Test func everyKindIsInAnAreaAndEveryAreaHasKinds() {
        for kind in CreatorKind.all {
            #expect(CreatorKindArea.allCases.contains { $0.kinds.contains { $0.id == kind.id } }, "\(kind.id)")
        }
        #expect(CreatorKindArea.allCases.allSatisfy { $0.kinds.count >= 3 })
        #expect(Set(CreatorKindArea.allCases.map(\.title)).count == CreatorKindArea.allCases.count)
        #expect(CreatorKind.find("lawyer").flatMap(CreatorKindArea.of) == .lawMoney)
        #expect(CreatorKindArea.beautyFashion.kinds.contains { $0.id == "beautyCreator" }, "a kind can be in two areas")
    }

    @Test func anUnknownOrMissingKindIsNone() {
        #expect(CreatorKind.find(nil) == nil && CreatorKind.find("astronaut-ceo") == nil)
    }

    @Test func theProfileKeepsItsKindAndForgetsOneANewerBuildAdded() throws {
        let profile = CreatorProfile(role: .expert, creatorKind: "lawyer")
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(profile))
        #expect(decoded.creatorKind == "lawyer" && decoded.kind?.id == "lawyer" && decoded.role == .expert)
        let newer = try CreatorProfileFixtures.decode(#"{"role":"expert","creatorKind":"spaceLawyer"}"#)
        #expect(newer.creatorKind == nil && newer.role == .expert, "the broad kind stays")
    }

    @Test func whoTheyAreIsWhatTheyTypedTheirKindOrTheirBroadKind() {
        var profile = CreatorProfile(role: .expert, creatorKind: "lawyer")
        #expect(profile.creatorTitle == "Lawyer")
        #expect(profile.voice.whoTheyAre == "a lawyer who explains people's rights in plain words")
        #expect(VoiceBriefBuilder.brief(for: profile.voice).text.contains("Who they are: a lawyer who explains people's rights in plain words."))
        profile.customRole = "Labor lawyer"
        #expect(profile.creatorTitle == "Labor lawyer" && profile.voice.whoTheyAre == "Labor lawyer")
        #expect(CreatorProfile(role: .expert).voice.whoTheyAre == CreatorRole.expert.promptName)
    }

    @Test func aKindSetsWhoIsTalkingUnlessTheCreatorChose() {
        var profile = CreatorProfile(role: .brands, creatorKind: "ugcCreator")
        #expect(profile.resolvedSpeaksAs == .i && profile.voice.resolvedSpeaksAs == .i)
        profile.speaksAs = .we
        #expect(profile.resolvedSpeaksAs == .we)
    }
}
