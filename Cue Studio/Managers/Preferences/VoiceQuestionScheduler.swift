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
    /// The invitation on the first idea sent may show (UI tests: only with `-uiTestVoiceInvite`).
    private let invitesOnSend: Bool
    /// The script language ("pt-BR"): Settings › Language & Region's Script Language, else the app's. It says which grammar is asked.
    private let scriptLanguage: () -> String?
    private(set) var state: VoiceQuestionState
    /// Goes up with each "Delete my Cue data", and is part of every tip's id: TipKit's own store outlives the erase, and a tip it had
    /// invalidated would come back invisible yet still use up the day (D1).
    private(set) var tipGeneration: Int
    /// A tool was introduced today (a discovery notification or the app's introduction): the tip waits for another day, so the creator never
    /// gets both on one day (`NotificationService.introducedToday`).
    @ObservationIgnored var otherIntroductionToday: () -> Bool = { false }
    /// A tip went on screen: the notifications move a tool planned for today to another day.
    @ObservationIgnored var onTipShown: () -> Void = {}

    init(
        profile: CreatorProfileService, defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now },
        calendar: Calendar = .current, skipsGates: Bool = false, invitesOnSend: Bool = true, scriptLanguage: @escaping () -> String? = { nil }
    ) {
        self.invitesOnSend = invitesOnSend
        self.profile = profile
        self.scriptLanguage = scriptLanguage
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
        tipGeneration = defaults.integer(forKey: DefaultsKey.voiceTipGeneration)
    }

    // MARK: - The queue

    /// Every question still worth asking, in order: the moments that pulled one forward, then `VoiceQuestion.askingOrder` (the grammar the
    /// script language needs, the audience, the other Essentials, the Personality details, the example). Answered and skipped questions are
    /// out, and so is grammar the script language doesn't mark; a question dismissed twice goes to the end; the example waits for two scripts
    /// written in the creator's voice. Snoozes are not counted here (the full page lists all of them).
    var remaining: [VoiceQuestion] {
        let held = profile.profile
        var open = VoiceQuestion.askingOrder.filter { question in
            !held.isAnswered(question) && !state.skipped.contains(question.rawValue) && applies(question, to: held)
                && (question != .example || state.voiceScriptIDs.count >= Self.voiceScriptsBeforeExample || pulled(question))
        }
        let pulledFirst = state.pulledForward.compactMap(VoiceTrigger.init(rawValue:)).map(\.question)
        open.sort { lhs, rhs in
            rank(lhs, pulledFirst: pulledFirst) < rank(rhs, pulledFirst: pulledFirst)
        }
        return open
    }

    /// Where a question stands: pulled forward first, then in order, with the twice-dismissed ones last. Stable (`askingOrder` breaks ties).
    private func rank(_ question: VoiceQuestion, pulledFirst: [VoiceQuestion]) -> Int {
        let position = VoiceQuestion.askingOrder.firstIndex(of: question) ?? 0
        if let index = pulledFirst.firstIndex(of: question) { return index - 1_000 }
        if state.dismissCount[question.rawValue, default: 0] >= Self.dismissalsBeforeLast { return 1_000 + position }
        return position
    }

    /// The grammar is asked only where the script language marks it, as "Scripts say I / We" shows it (`VoiceAgreementField`): "Write me
    /// as" for one creator and "Write us as" for a team where words about them agree, "Speak to viewers" where there are two "you"s.
    private func applies(_ question: VoiceQuestion, to held: CreatorProfile) -> Bool {
        let isTeam = held.resolvedSpeaksAs == .we
        switch question {
        case .speakerGender: return !isTeam && AgreementGuide.genderExample(in: scriptLanguage(), team: false) != nil
        case .groupGender: return isTeam && AgreementGuide.genderExample(in: scriptLanguage(), team: true) != nil
        case .address: return AgreementGuide.addressExample(in: scriptLanguage()) != nil
        default: return true
        }
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

    /// The id of `question`'s next tip: this erase's generation and the question's round, so a tip TipKit already spent is never reused.
    func tipID(for question: VoiceQuestion) -> String {
        "vq.tip.\(tipGeneration).\(question.rawValue).\(state.tipRounds[question.rawValue, default: 0])"
    }

    /// TipKit spent `question`'s tip (it was opened or closed): its next one is a new tip.
    func tipSpent(_ question: VoiceQuestion) {
        state.tipRounds[question.rawValue, default: 0] += 1
        save()
    }

    /// A tip is visible (TipKit says `.available`): only then does it count toward the day and the week.
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

    /// At 100% there is one ✓ toast, "Cue Voice complete", and never again.
    func completionToastIsDue() -> Bool {
        profile.profile.voiceStrength >= 100 && !state.completeToastShown
    }

    func completionToastShown() {
        state.completeToastShown = true
        save()
    }

    /// "Delete my Cue data": the tips start over as on a fresh install (snoozes, pauses, skips, counts and the days opened).
    func reset() {
        state = VoiceQuestionState()
        defaults.removeObject(forKey: DefaultsKey.voiceQuestionState)
        // TipKit's store keeps the tips it invalidated: the next ones get new ids.
        tipGeneration += 1
        defaults.set(tipGeneration, forKey: DefaultsKey.voiceTipGeneration)
    }

    // MARK: - The invitation on the first send

    /// The first idea sent from the AI card while some of the five guided questions are still open invites to finish them first, once
    /// (the owner, 03/11/2026: "evite repetir o convite a cada envio").
    var invitesBeforeSending: Bool {
        invitesOnSend && !state.sendInviteShown && !profile.profile.answeredEverySetupStep
    }

    /// The invitation was shown, whatever the creator chose: it never comes again.
    func sendInviteWasShown() {
        state.sendInviteShown = true
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
