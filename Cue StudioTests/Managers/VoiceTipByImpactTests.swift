//
//  VoiceTipByImpactTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The owner's item 13 (02/11/2026): the My Cue Voice tip asks by impact, the grammar first where the script language needs it, then the
/// audience, the details last; a single answer from a closed list is given with one tap on the tip, through the sheet's own path.
@MainActor
@Suite("My Cue Voice tip by impact")
struct VoiceTipByImpactTests {
    @MainActor
    private struct Rig {
        let profile: CreatorProfileService
        let scheduler: VoiceQuestionScheduler
        let toast: ToastService
        let defaults: TestDefaults
    }

    private func make(language: String?) -> Rig {
        let defaults = TestDefaults()
        let profile = CreatorProfileService(defaults: defaults.defaults)
        let scheduler = VoiceQuestionScheduler(profile: profile, defaults: defaults.defaults, skipsGates: true, scriptLanguage: { language })
        return Rig(profile: profile, scheduler: scheduler, toast: ToastService(), defaults: defaults)
    }

    private func option(_ question: VoiceQuestion, _ id: String) -> VoiceOption {
        question.options.first { $0.id == id } ?? VoiceOption(id: id, label: id)
    }

    // MARK: - The order

    @Test(arguments: ["pt-BR", "pt-PT", "es", "fr", "it"])
    func theGrammarComesFirstThenTheAudience(language: String) {
        let rig = make(language: language)
        defer { rig.defaults.tearDown() }
        // What kind of creator first (the owner, 03/11/2026), then the grammar.
        #expect(Array(rig.scheduler.remaining.prefix(4)) == [.role, .speakerGender, .address, .audience])
        #expect(rig.scheduler.tipQuestion(isAIAvailable: true, scriptCount: 0) == .role)
    }

    @Test func germanAsksOnlyHowToSpeakToViewers() {
        let rig = make(language: "de-DE")
        defer { rig.defaults.tearDown() }
        #expect(!rig.scheduler.remaining.contains(.speakerGender))
        #expect(Array(rig.scheduler.remaining.prefix(3)) == [.role, .address, .audience])
    }

    @Test(arguments: ["en-US", "en-GB"])
    func englishAsksNoGrammar(language: String) {
        let rig = make(language: language)
        defer { rig.defaults.tearDown() }
        let grammar: Set<VoiceQuestion> = [.speakerGender, .groupGender, .address]
        #expect(rig.scheduler.remaining.allSatisfy { !grammar.contains($0) })
        #expect(Array(rig.scheduler.remaining.prefix(2)) == [.role, .audience])
    }

    @Test func aTeamIsAskedHowTheGroupAgrees() {
        let rig = make(language: "es")
        defer { rig.defaults.tearDown() }
        rig.profile.setSpeaksAs(.we)
        #expect(Array(rig.scheduler.remaining.prefix(2)) == [.role, .groupGender])
        #expect(!rig.scheduler.remaining.contains(.speakerGender))
        #expect(VoiceQuestion.groupGender.title == "How should scripts write your team?")
    }

    @Test func theDetailsComeLast() {
        let rig = make(language: "pt-BR")
        defer { rig.defaults.tearDown() }
        let order = rig.scheduler.remaining
        let audience = order.firstIndex(of: .audience) ?? 0
        for detail in [VoiceQuestion.endings, .openings, .formats, .length, .humor, .platforms, .energy, .sentences, .words, .swearing] {
            #expect((order.firstIndex(of: detail) ?? 0) > audience, "\(detail)")
        }
    }

    // MARK: - Asked once

    @Test func theGrammarChosenInTheEditorIsNotAskedAgain() {
        let rig = make(language: "pt-BR")
        defer { rig.defaults.tearDown() }
        rig.profile.setSpeakerGender(.feminine)
        // Informal is a choice too (the editor's "Speak to viewers").
        rig.profile.setAddressForm(.informal)
        #expect(!rig.scheduler.remaining.contains(.speakerGender))
        #expect(!rig.scheduler.remaining.contains(.address))
        #expect(Array(rig.scheduler.remaining.prefix(2)) == [.role, .audience])
    }

    @Test func theGrammarAnsweredInTheSheetIsNotAskedAgain() {
        let rig = make(language: "fr")
        defer { rig.defaults.tearDown() }
        let model = VoiceQuestionSheetModel(question: .address, profile: rig.profile, scheduler: rig.scheduler, toast: rig.toast)
        model.choose(option(.address, AddressForm.formal.rawValue))
        #expect(rig.profile.profile.agreement.address == .formal)
        #expect(model.savedStrength != nil)
        #expect(!rig.scheduler.remaining.contains(.address))
    }

    // MARK: - One tap in the tip

    @Test func closedSingleAnswersAreGivenOnTheTipAndTheOthersOpenTheSheet() {
        for question in [VoiceQuestion.speakerGender, .groupGender, .address, .length, .humor, .platforms, .energy, .sentences, .words, .swearing] {
            #expect(question.answersInTip, "\(question)")
        }
        for question in [VoiceQuestion.role, .audience, .endings, .openings, .topics, .tone, .formats, .avoid, .phrases, .example] {
            #expect(!question.answersInTip, "\(question)")
        }
        #expect(VoiceQuestion.speakerGender.options.map(\.label) == ["Feminine", "Masculine", "No gender"])
        #expect(VoiceQuestion.address.options.map(\.label) == ["Informal", "Formal"])
    }

    @Test func aTapOnTheTipSavesThroughTheServiceAndCountsAsAnAnswer() {
        let rig = make(language: "pt-BR")
        defer { rig.defaults.tearDown() }
        rig.scheduler.dismissed(.speakerGender)
        #expect(rig.scheduler.state.consecutiveDismissals == 1)
        VoiceTipAnswer.choose(option(.speakerGender, WordGender.feminine.rawValue), for: .speakerGender, profile: rig.profile,
                              scheduler: rig.scheduler, toast: rig.toast)
        #expect(rig.profile.profile.agreement.speaker == .feminine)
        #expect(rig.scheduler.state.consecutiveDismissals == 0, "an answer breaks the streak, as in the sheet")
        #expect(rig.scheduler.state.snoozedUntil[VoiceQuestion.speakerGender.rawValue] == nil)
        #expect(rig.toast.message == "Saved · voice \(rig.profile.profile.voiceStrength)%")
        #expect(!rig.scheduler.remaining.contains(.speakerGender), "never asked again")
        #expect(Array(rig.scheduler.remaining.prefix(2)) == [.role, .address])
    }

    @Test func aTapThatCompletesTheVoiceSaysSoInstead() {
        let rig = make(language: "en-US")
        defer { rig.defaults.tearDown() }
        var full = VoiceQuestionSchedulerTests.fullProfile()
        full.style.swearing = nil
        rig.profile.profile = full
        #expect(rig.profile.profile.voiceStrength < 100)
        VoiceTipAnswer.choose(option(.swearing, Swearing.never.rawValue), for: .swearing, profile: rig.profile, scheduler: rig.scheduler,
                              toast: rig.toast)
        #expect(rig.profile.profile.style.swearing == .never)
        #expect(rig.profile.profile.voiceStrength == 100)
        #expect(rig.toast.message == "Cue Voice complete")
    }
}
