//
//  CreatorRoleTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "What kind of creator are you?": optional, remembered, and told to the AI.
@Suite("Creator role")
struct CreatorRoleTests {
    @Test func thereAreEightRolesEachWithTwoCommonSounds() {
        #expect(CreatorRole.allCases.count == 8)
        for role in CreatorRole.allCases {
            #expect(role.commonSounds.count == 2 && !role.label.isEmpty && !role.examples.isEmpty)
        }
    }

    @Test func theRoleIsOptionalForTheVoiceToBeUsable() {
        var profile = CreatorProfile(niches: [.tech], confirmedVoiceSteps: [.audience, .tone])
        #expect(profile.role == nil && profile.hasMinimumVoice && profile.missingVoiceSteps.isEmpty)
        profile.role = .expert
        #expect(profile.hasMinimumVoice && profile.hasAnswered(.role))
    }

    @Test func theRoleSurvivesSavingAndAnOlderProfileOpensWithoutOne() throws {
        let profile = CreatorProfile(role: .business, voiceApproved: true)
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: data)
        #expect(decoded.role == .business && decoded.voiceApproved)
        let older = try JSONDecoder().decode(CreatorProfile.self, from: Data(#"{"name":"Ana"}"#.utf8))
        #expect(older.role == nil && !older.voiceApproved)
    }

    @Test func theAIIsToldWhoIsTalkingAndTeamsSayWe() {
        let team = CreatorVoice(sounds: [.casual], phrases: [], vocabulary: nil, styles: [], niches: [], role: .business)
        let lines = ScriptPromptBuilder.voiceLines(team).joined(separator: "\n")
        #expect(lines.contains("the owner of a business") && lines.contains("say “we” and “our”, never “I”"))
        let solo = CreatorVoice(sounds: [.casual], phrases: [], vocabulary: nil, styles: [], niches: [], role: .personal)
        #expect(!ScriptPromptBuilder.voiceLines(solo).joined(separator: "\n").contains("say “we”"))
        #expect(!ScriptPromptBuilder.voiceLines(CreatorVoice(sounds: [], phrases: [], vocabulary: nil, styles: [], niches: [])).joined().contains("kind"))
    }

    @MainActor
    @Test func theSetupAsksTheRoleFirstOnlyFromScratch() {
        let service = CreatorProfileService(defaults: UserDefaults(suiteName: "CreatorRoleTests-\(UUID())")!)
        let plan = VoiceSetupPlan(profile: service.profile)
        #expect(plan.steps.first == .role)
        service.answer(.role, with: VoiceOption(id: CreatorRole.educator.rawValue, label: "Educator"))
        service.toggleTopic(.niche(.tech))
        service.setAudienceGroup(.insiders)
        service.answer(.tone, with: VoiceOption(id: VoiceSound.educational.rawValue, label: "Educational"))
        #expect(plan.canFinish(in: service.profile))
        service.setWritesInMyVoice(true)
        #expect(service.profile.role == .educator && service.writesInMyVoice)
        // Asked again, the role isn't asked a second time.
        #expect(VoiceSetupPlan(profile: service.profile).steps.isEmpty)
    }
}
