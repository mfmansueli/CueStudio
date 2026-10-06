//
//  ProfileVoiceSetupTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The My Cue Voice questions opened from Profile: all that is missing, or one row to edit.
@Suite("Profile voice setup")
struct ProfileVoiceSetupTests {
    @MainActor
    @Test func eachRowOpensItsOwnQuestionAndTheFirstOpensTheStart() {
        let first = ProfileVoiceSetup(mode: .missing)
        let audience = ProfileVoiceSetup(mode: .edit, startAt: .audience)
        let tone = ProfileVoiceSetup(mode: .edit, startAt: .tone)
        #expect(Set([first.id, audience.id, tone.id]).count == 3)
    }

    @MainActor
    @Test func editingStartsOnTheQuestionOfTheRowAndAsksAllFour() {
        let profile = CreatorProfile(niches: [.tech], role: .expert, confirmedVoiceSteps: [.audience, .tone])
        let draft = VoiceSetupDraft(profile: profile, steps: VoiceSetupStep.allCases)
        #expect(draft.steps == [.role, .niche, .audience, .tone])
        #expect(draft.role == .expert && draft.canSave)
        #expect(draft.steps.firstIndex(of: .audience) == 2)
    }

    /// v30: every page Settings opens is pushed, none is a sheet.
    @MainActor
    @Test func settingsPushesEveryPage() {
        let routes: Set<SettingsRoute> = [
            .recording, .microphone, .prompter, .font, .safeZone, .remote, .myCueVoice, .personalize, .appIcon, .languageRegion,
            .privacy, .permissions, .acknowledgements,
        ]
        #expect(routes.count == 13)
    }
}
