//
//  VoiceQuestionScheduler.swift
//  Cue Studio
//

import Foundation

/// When My Cue Voice asks a question, and which (08 §3–§4): one at a time on Scripts and Takes, only the questions that bring the voice to
/// 100%. It decides the order of the queue, how often a tip may show (one a day, three in a rolling week), what a dismissal does
/// (three days off; two dismissals send the question to the end; three in a row pause everything for two weeks) and when it stops.
/// The tip's look and the sheet are the views'; the clock is injected.
@MainActor
@Observable
final class VoiceQuestionScheduler {
    static let snoozeInterval: TimeInterval = 3 * 24 * 3600
    static let pauseInterval: TimeInterval = 14 * 24 * 3600
    static let weeklyCap = 3
    static let dismissalsBeforePause = 3
    static let dismissalsBeforeLast = 2
    /// Answers in a row before the sheet closes with "Saved".
    static let answersInARow = 3
    /// The creator has to have opened the app on this many different days.
    static let daysBeforeFirstTip = 2
    /// Scripts written in their voice before the example question.
    static let voiceScriptsBeforeExample = 2

    private let profile: CreatorProfileService
    private let defaults: UserDefaults
    private let now: () -> Date
    private let calendar: Calendar
    /// Debug: every gate but the queue is open (`-uiTestVoiceTip`).
    private let skipsGates: Bool
    private(set) var state: VoiceQuestionState
    /// A tool was introduced today (a discovery notification or the app's introduction): the tip waits for another day, so the creator never
    /// gets both on one day (`NotificationService.introducedToday`).
    @ObservationIgnored var otherIntroductionToday: () -> Bool = { false }
    /// A tip went on screen: the notifications move a tool planned for today to another day.
    @ObservationIgnored var onTipShown: () -> Void = {}

    init(
        profile: CreatorProfileService, defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now },
        calendar: Calendar = .current, skipsGates: Bool = false
    ) {
        self.profile = profile
        self.defaults = defaults
        self.now = now
        self.calendar = calendar
        self.skipsGates = skipsGates
        if let data = defaults.data(forKey: DefaultsKey.voiceQuestionState),
           let stored = try? JSONDecoder().decode(VoiceQuestionState.self, from: data) {
            state = stored
        } else {
            state = VoiceQuestionState()
        }
    }

    // MARK: - The queue

    /// Every question still worth asking, in order: the moments that pulled one forward, the missing Essentials, the Personality
    /// questions in table order, then the example. Skipped questions are out; a question dismissed twice goes to the end; the example
    /// waits for two scripts written in the creator's voice. Snoozes are not counted here (the full page lists all of them).
    var remaining: [VoiceQuestion] {
        let held = profile.profile
        var open = VoiceQuestion.allCases.filter { question in
            !held.isAnswered(question) && !state.skipped.contains(question.rawValue)
                && (question != .example || state.voiceScriptIDs.count >= Self.voiceScriptsBeforeExample || pulled(question))
        }
        let pulledFirst = state.pulledForward.compactMap(VoiceTrigger.init(rawValue:)).map(\.question)
        open.sort { lhs, rhs in
            rank(lhs, pulledFirst: pulledFirst) < rank(rhs, pulledFirst: pulledFirst)
        }
        return open
    }

    /// Where a question stands: pulled forward first, then in order, with the twice-dismissed ones last. Stable (`allCases` order breaks ties).
    private func rank(_ question: VoiceQuestion, pulledFirst: [VoiceQuestion]) -> Int {
        let position = VoiceQuestion.allCases.firstIndex(of: question) ?? 0
        if let index = pulledFirst.firstIndex(of: question) { return index - 1_000 }
        if state.dismissCount[question.rawValue, default: 0] >= Self.dismissalsBeforeLast { return 1_000 + position }
        return position
    }

    private func pulled(_ question: VoiceQuestion) -> Bool {
        state.pulledForward.compactMap(VoiceTrigger.init(rawValue:)).contains { $0.question == question }
    }

    /// The question to show as the tip right now, or nil: the gates of §4 (Apple Intelligence on, the voice on, a script, two days,
    /// not paused, under the daily and weekly caps) and the first question that isn't snoozed.
    func tipQuestion(isAIAvailable: Bool, scriptCount: Int) -> VoiceQuestion? {
        guard canShowTip(isAIAvailable: isAIAvailable, scriptCount: scriptCount) else { return nil }
        let moment = now()
        return remaining.first { (state.snoozedUntil[$0.rawValue] ?? .distantPast) <= moment }
    }

    func canShowTip(isAIAvailable: Bool, scriptCount: Int) -> Bool {
        guard isAIAvailable, profile.profile.usesVoiceInAI, profile.profile.voiceStrength < 100 else { return false }
        if skipsGates { return true }
        let moment = now()
        guard scriptCount >= 1, state.firstEligibleDays.count >= Self.daysBeforeFirstTip, !otherIntroductionToday() else { return false }
        if let paused = state.pausedUntil, paused > moment { return false }
        let week = state.shownDates.filter { moment.timeIntervalSince($0) < 7 * 24 * 3600 }
        return week.count < Self.weeklyCap && !week.contains { calendar.isDate($0, inSameDayAs: moment) }
    }

    // MARK: - Events

    /// The app was opened today: the tip waits until it has been opened on two different days.
    func registerAppOpen() {
        let today = Self.dayKey(now(), calendar: calendar)
        guard state.firstEligibleDays.count < Self.daysBeforeFirstTip, !state.firstEligibleDays.contains(today) else { return }
        state.firstEligibleDays.append(today)
        save()
    }

    /// A script was written in the creator's voice.
    func recordVoiceScript(_ scriptID: UUID) {
        guard !state.voiceScriptIDs.contains(scriptID.uuidString) else { return }
        state.voiceScriptIDs.append(scriptID.uuidString)
        save()
    }

    /// The creator changed the words of a script that was written in their voice; the second time asks how technical their words are.
    func noteEdit(ofScript scriptID: UUID) {
        guard state.voiceScriptIDs.contains(scriptID.uuidString) else { return }
        state.generatedEdits += 1
        if state.generatedEdits >= 2 { note(.secondGeneratedEdit) }
        save()
    }

    /// A moment that asks a question sooner (once each).
    func note(_ trigger: VoiceTrigger) {
        guard !state.pulledForward.contains(trigger.rawValue) else { return }
        state.pulledForward.append(trigger.rawValue)
        save()
    }

    /// A tip went on screen: it counts toward the day and the week.
    func tipShown() {
        let moment = now()
        state.shownDates = state.shownDates.filter { moment.timeIntervalSince($0) < 7 * 24 * 3600 } + [moment]
        save()
        onTipShown()
    }

    /// Not now, ✕, a swipe down or a tap on the backdrop: the question waits three days, and the next one comes first.
    func dismissed(_ question: VoiceQuestion) {
        state.snoozedUntil[question.rawValue] = now().addingTimeInterval(Self.snoozeInterval)
        state.dismissCount[question.rawValue, default: 0] += 1
        state.consecutiveDismissals += 1
        if state.consecutiveDismissals >= Self.dismissalsBeforePause {
            state.pausedUntil = now().addingTimeInterval(Self.pauseInterval)
            state.consecutiveDismissals = 0
        }
        save()
    }

    /// An answer: the streak of dismissals starts over.
    func answered(_ question: VoiceQuestion) {
        state.consecutiveDismissals = 0
        state.snoozedUntil[question.rawValue] = nil
        save()
    }

    /// "None of these": never asked again, nothing filled in.
    func skipped(_ question: VoiceQuestion) {
        state.skipped.insert(question.rawValue)
        state.consecutiveDismissals = 0
        save()
    }

    // MARK: - Done

    /// Every question is answered or skipped (or the voice is at 100%): nothing more to ask.
    var isFinished: Bool { profile.profile.voiceStrength >= 100 || remaining.isEmpty }

    /// At 100% there is one toast, "✓ Cue Voice complete", and never again.
    func completionToastIsDue() -> Bool {
        profile.profile.voiceStrength >= 100 && !state.completeToastShown
    }

    func completionToastShown() {
        state.completeToastShown = true
        save()
    }

    /// "Reset My Cue Voice" on the full page: the history of the tips starts over (snoozes, pauses, skips, counts).
    func reset() {
        let opened = state.firstEligibleDays
        state = VoiceQuestionState()
        state.firstEligibleDays = opened
        save()
    }

    // MARK: - Storage

    private func save() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: DefaultsKey.voiceQuestionState) }
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
