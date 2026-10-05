//
//  VoiceQuestionSheetModel.swift
//  Cue Studio
//

import Foundation

/// The state of the My Cue Voice question sheet (04 §F9, 08 §4): the tip's sheet asks one question at a time (a tap is the answer; a
/// list that takes several has Save), says "Saved · voice nn%" and offers one more (at most three answers in a row), and the full
/// page opens the same sheet on one field. "+ Something else" is checked as it is typed; "None of these" skips the question for good.
@MainActor
@Observable
final class VoiceQuestionSheetModel {
    /// Where the sheet was opened from: the tip (a queue of questions, which counts toward the dismissals) or a row of the full page.
    enum Mode: Equatable {
        case tip
        case edit
    }

    enum Feedback: Equatable {
        case message(String)
        case typo(suggestion: String, original: String)
    }

    let mode: Mode
    private(set) var question: VoiceQuestion
    /// The second part of "Who's watching?".
    private(set) var asksAudienceLevel = false
    /// "Saved · voice 65%": an answer was just given and the sheet offers one more.
    private(set) var savedStrength: Int?
    private(set) var answersInARow = 0
    var typed = ""
    var feedback: Feedback?
    var showsSomethingElse = false

    private let profile: CreatorProfileService
    private let scheduler: VoiceQuestionScheduler
    private let toast: ToastService
    /// The questions of the row being edited, in order; empty for the tip.
    private var pending: [VoiceQuestion]
    private var answeredCurrent = false

    init(question: VoiceQuestion, mode: Mode, fieldQuestions: [VoiceQuestion] = [], profile: CreatorProfileService,
         scheduler: VoiceQuestionScheduler, toast: ToastService) {
        self.question = question
        self.mode = mode
        self.profile = profile
        self.scheduler = scheduler
        self.toast = toast
        pending = fieldQuestions.filter { $0 != question }
        // The tip asks only what is missing: an audience chosen in the setup lacks its level. A row of the full page starts from the audience.
        asksAudienceLevel = mode == .tip && question == .audience && profile.profile.isChosen(.audience) && profile.profile.audienceLevel == nil
    }

    // MARK: - Reading

    var strength: Int { profile.profile.voiceStrength }

    /// Whether `option` is what the profile holds for the question on screen (the level of the audience has its own check).
    func isSelected(_ option: VoiceOption) -> Bool {
        if asksAudienceLevel { return profile.profile.audienceLevel?.rawValue == option.id }
        return profile.isSelected(option, for: question)
    }

    /// What is on screen: the question, or the level of the audience.
    var title: String {
        asksAudienceLevel ? String(localized: "How much do they already know?") : question.title
    }

    var options: [VoiceOption] {
        asksAudienceLevel ? AudienceLevel.allCases.map { VoiceOption(id: $0.rawValue, label: $0.label) } : question.options
    }

    var kind: VoiceQuestion.Kind { asksAudienceLevel ? .single : question.kind }

    var allowsSomethingElse: Bool { !asksAudienceLevel && question.allowsSomethingElse }
    var allowsNone: Bool { !asksAudienceLevel && question.allowsNone }

    /// Another question can follow the one just answered (the tip allows three in a row).
    var canAskMore: Bool {
        if mode == .edit { return !pending.isEmpty }
        return answersInARow < VoiceQuestionScheduler.answersInARow && nextInQueue != nil
    }

    private var nextInQueue: VoiceQuestion? {
        scheduler.remaining.first { $0 != question && (scheduler.state.snoozedUntil[$0.rawValue] ?? .distantPast) <= .now }
    }

    // MARK: - Answering

    /// A tap on an answer.
    func choose(_ option: VoiceOption) {
        feedback = nil
        if asksAudienceLevel {
            if let level = AudienceLevel(rawValue: option.id) { profile.answerAudienceLevel(level) }
            finishQuestion()
            return
        }
        switch profile.answer(question, with: option) {
        case .limit(let message):
            toast.show(message)
        case .added, .removed, .alreadyThere:
            // Picking something is answering, even before "Save": closing the sheet then is not a dismissal.
            answeredCurrent = true
            if case .single = question.kind { advanceAfterSingleAnswer() }
        case .rejected, .suggest:
            break
        }
    }

    /// The "Save" of a list that takes several answers.
    func save() {
        finishQuestion()
    }

    /// "None of these": nothing is filled in, and the question is not asked again.
    func none() {
        answeredCurrent = true
        scheduler.skipped(question)
        feedback = nil
        moveOn(saved: false)
    }

    /// "Add" under "+ Something else": the typed words, checked first.
    func addSomethingElse(keepingTyped: Bool = false) {
        switch profile.addSomethingElse(typed, for: question, keepingTyped: keepingTyped) {
        case .added:
            typed = ""
            feedback = nil
            showsSomethingElse = false
            if case .single = question.kind { advanceAfterSingleAnswer() } else { finishIfSingleAnswerList() }
        case .alreadyThere:
            typed = ""
            feedback = .message(String(localized: "Already added."))
        case .limit(let message):
            feedback = nil
            toast.show(message)
        case .rejected(let check):
            feedback = check.message.map(Feedback.message)
        case .suggest(let suggestion, let original):
            feedback = .typo(suggestion: suggestion, original: original)
        case .removed:
            break
        }
    }

    /// "Use “…”" of a typo suggestion.
    func useSuggestion(_ suggestion: String) {
        typed = suggestion
        addSomethingElse()
    }

    /// "Keep mine" of a typo suggestion.
    func keepTyped(_ original: String) {
        typed = original
        addSomethingElse(keepingTyped: true)
    }

    /// "One more question": the next in the queue (or in the row's field).
    func askMore() {
        guard let next = pending.isEmpty ? nextInQueue : pending.removeFirst() else { return }
        question = next
        asksAudienceLevel = mode == .tip && next == .audience && profile.profile.isChosen(.audience) && profile.profile.audienceLevel == nil
        savedStrength = nil
        answeredCurrent = false
        typed = ""
        feedback = nil
        showsSomethingElse = false
    }

    // MARK: - Dismissing

    /// The sheet closes with no answer (close, a swipe down or a tap on the backdrop): the tip's question waits three days. A sheet
    /// that already gave an answer is not a dismissal.
    func dismissedWithoutAnswer() {
        guard mode == .tip, answersInARow == 0, !answeredCurrent else { return }
        scheduler.dismissed(question)
    }

    // MARK: - Moving on

    private func advanceAfterSingleAnswer() {
        // The audience is followed by its level (a row of the full page always asks it, to keep or change).
        if question == .audience, mode == .edit || profile.profile.audienceLevel == nil {
            scheduler.answered(question)
            asksAudienceLevel = true
            return
        }
        finishQuestion()
    }

    /// A list that takes one answer is done with the first one typed; one that takes several waits for Save.
    private func finishIfSingleAnswerList() {
        if case .multiple = question.kind { return }
        finishQuestion()
    }

    private func finishQuestion() {
        answeredCurrent = true
        scheduler.answered(question)
        moveOn(saved: true)
    }

    /// After an answer (or "None of these"): the sheet says "Saved" and offers one more, goes to the next question of the row, or closes.
    private func moveOn(saved: Bool) {
        if saved { answersInARow += 1 }
        if scheduler.completionToastIsDue() {
            scheduler.completionToastShown()
            toast.show(String(localized: "✓ Cue Voice complete"))
        }
        if mode == .edit, !pending.isEmpty {
            askMore()
        } else {
            savedStrength = strength
        }
    }

    /// The sheet should close now: edit mode with nothing more to ask, or the third answer in a row.
    var shouldClose: Bool {
        guard savedStrength != nil else { return false }
        if mode == .edit { return pending.isEmpty }
        return !canAskMore
    }
}
