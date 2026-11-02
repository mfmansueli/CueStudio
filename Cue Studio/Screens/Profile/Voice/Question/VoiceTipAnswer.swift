//
//  VoiceTipAnswer.swift
//  Cue Studio
//

import Foundation

/// One tap on an answer of the My Cue Voice tip (the owner's item 13, 02/11/2026): the same path as a tap in the question sheet
/// (`VoiceQuestionSheetModel.choose`), so the service writes the profile, the scheduler counts the answer and "Cue Voice complete" comes at
/// 100%; otherwise the toast says "Saved · voice nn%", what the sheet says after an answer.
@MainActor
enum VoiceTipAnswer {
    static func choose(
        _ option: VoiceOption, for question: VoiceQuestion, profile: CreatorProfileService, scheduler: VoiceQuestionScheduler, toast: ToastService
    ) {
        let completeWasShown = scheduler.state.completeToastShown
        VoiceQuestionSheetModel(question: question, profile: profile, scheduler: scheduler, toast: toast).choose(option)
        guard completeWasShown || !scheduler.state.completeToastShown else { return }
        toast.show(String(localized: "Saved · voice \(profile.profile.voiceStrength)%"))
    }
}
