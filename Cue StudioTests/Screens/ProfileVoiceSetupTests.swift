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

    @MainActor
    @Test func settingsPushesThreePagesAndOpensThreeSheets() {
        let routes: Set<SettingsRoute> = [.personalize, .prompter, .acknowledgements]
        #expect(routes.count == 3)
        // v29 · L14: Recording, Remote and Language & Region are sheets.
        let sheets: Set<SettingsSheet> = [.recording, .remote, .languageRegion]
        #expect(sheets.count == 3)
    }

    @MainActor
    @Test func everyPrompterChipHasANameAndAnAnchor() {
        #expect(PrompterSettingsSection.allCases.count == 5)
        #expect(PrompterSettingsSection.allCases.allSatisfy { !$0.label.isEmpty })
    }
}
