//
//  VoiceQuestionSheetModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The My Cue Voice question sheet (04 §F9, 08 §4): a tap answers, "Saved" offers one more (three in a row at most), the audience is followed
/// by its level, a row of the full page walks its field's questions, and closing with nothing answered is a dismissal.
@MainActor
@Suite("My Cue Voice question sheet")
struct VoiceQuestionSheetModelTests {
    @MainActor
    private struct Rig {
        let profile: CreatorProfileService
        let scheduler: VoiceQuestionScheduler
        let toast: ToastService
        let defaults: TestDefaults

        func model(_ question: VoiceQuestion) -> VoiceQuestionSheetModel {
            VoiceQuestionSheetModel(question: question, profile: profile, scheduler: scheduler, toast: toast)
        }
    }

    private func make() -> Rig {
        let defaults = TestDefaults()
        let profile = CreatorProfileService(defaults: defaults.defaults)
        return Rig(
            profile: profile, scheduler: VoiceQuestionScheduler(profile: profile, defaults: defaults.defaults, skipsGates: true),
            toast: ToastService(), defaults: defaults
        )
    }

    private func option(_ question: VoiceQuestion, _ id: String) -> VoiceOption {
        question.options.first { $0.id == id } ?? VoiceOption(id: id, label: id)
    }

    @Test func aTapOnASingleAnswerSavesItAndOffersOneMore() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        let model = rig.model(.role)
        #expect(model.savedStrength == nil)
        model.choose(option(.role, "personal"))
        #expect(rig.profile.profile.role == .personal)
        #expect(model.savedStrength == 10)
        #expect(model.canAskMore)
        model.askMore()
        #expect(model.question == .topics && model.savedStrength == nil)
    }

    @Test func threeAnswersInARowAreTheMostAndThenTheSheetCloses() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        let model = rig.model(.role)
        model.choose(option(.role, "personal"))
        model.askMore()
        model.choose(option(.topics, "food"))
        model.save()
        model.askMore()
        // The third answer (the audience, then its level).
        model.choose(option(.audience, "simple"))
        #expect(model.asksAudienceLevel)
        model.choose(VoiceOption(id: AudienceLevel.some.rawValue, label: "Some basics"))
        #expect(model.savedStrength != nil)
        #expect(!model.canAskMore, "three in a row")
        #expect(model.shouldClose)
    }

    @Test func aListThatTakesSeveralAnswersWaitsForSave() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        let model = rig.model(.topics)
        model.choose(option(.topics, "food"))
        model.choose(option(.topics, "tech"))
        #expect(model.savedStrength == nil)
        #expect(rig.profile.profile.niches == [.food, .tech])
        model.save()
        #expect(model.savedStrength == 10)
    }

    @Test func theAudienceIsFollowedByItsLevelAndTheTipAsksOnlyTheLevelWhenTheAudienceIsKnown() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        let model = rig.model(.audience)
        #expect(!model.asksAudienceLevel)
        model.choose(option(.audience, "genZ"))
        #expect(model.asksAudienceLevel && model.savedStrength == nil)
        model.choose(VoiceOption(id: AudienceLevel.experienced.rawValue, label: "Experienced"))
        #expect(rig.profile.profile.audienceLevel == .experienced)
        #expect(rig.profile.profile.voiceStrength == 10)

        // An audience chosen in the setup, without its level: the tip goes straight to the level.
        let setup = make()
        defer { setup.defaults.tearDown() }
        setup.profile.saveVoiceSetup(vocabulary: .simple)
        #expect(setup.model(.audience).asksAudienceLevel)
    }

    @Test func closingWithNothingAnsweredIsADismissalButAnAnswerOrNoneOfTheseIsNot() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        rig.model(.role).dismissedWithoutAnswer()
        #expect(rig.scheduler.state.dismissCount["role"] == 1 && rig.scheduler.state.snoozedUntil["role"] != nil)

        let answered = rig.model(.endings)
        answered.choose(option(.endings, "Save this"))
        answered.dismissedWithoutAnswer()
        #expect(rig.scheduler.state.dismissCount["endings"] == nil)

        let skipped = rig.model(.openings)
        skipped.none()
        skipped.dismissedWithoutAnswer()
        #expect(rig.scheduler.state.dismissCount["openings"] == nil)
        #expect(rig.scheduler.state.skipped.contains("openings"))
    }

    @Test func somethingElseIsCheckedAndAnAnswerOnceAdded() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        let model = rig.model(.endings)
        model.typed = "x"
        model.addSomethingElse()
        #expect(model.feedback == .message("Add 2–4 sentences") || model.feedback != nil)
        model.typed = "Save thsi"
        model.addSomethingElse()
        if case .typo(let suggestion, _)? = model.feedback { #expect(suggestion == "Save this") } else { Issue.record("no typo suggestion") }
        model.keepTyped("Save thsi")
        #expect(rig.profile.profile.endings == ["Save thsi"])
        #expect(model.savedStrength != nil)
    }

    @Test func atOneHundredTheCompleteToastShowsOnce() {
        let rig = make()
        defer { rig.defaults.tearDown() }
        var profile = VoiceQuestionSchedulerTests.fullProfile()
        profile.avoid = []
        rig.profile.profile = profile
        let model = rig.model(.avoid)
        model.choose(VoiceOption(id: VoiceQuestion.nothingToAvoidID, label: "Nothing to avoid"))
        #expect(rig.profile.profile.voiceStrength == 100)
        model.save()
        #expect(rig.toast.message == "✓ Cue Voice complete")
        #expect(!rig.scheduler.completionToastIsDue())
    }
}
