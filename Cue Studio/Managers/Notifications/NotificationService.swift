//
//  NotificationService.swift
//  Cue Studio
//

import Foundation

/// Cue's notifications (`NOTIFICATIONS.md`): the creator's consent per category, their reminders and routine, the project nudges, the
/// tools and ideas, and what a tap opens. Local notifications only, planned while Cue runs and delivered by iOS later; nothing polls, no
/// video is analysed and no model is asked for them. The rules are pure types (`ProjectCampaigns`, `DiscoveryRules`,
/// `NotificationPlanner`); this service gathers the facts, keeps the state, and talks to the system through `NotificationCenterClient`.
///
/// The OS permission and the categories are separate: iOS allowing Cue is never a yes to tools or news (both start off), and Cue asks iOS
/// only when the creator sets a reminder or turns something on, or says yes to its invitation (`+Invite`). Its parts: `+Reconcile` (what
/// is scheduled), `+Reminders`, `+Discovery`, `+Opening` (taps and the foreground), `+Invite`, `+Metrics`.
@MainActor
@Observable
final class NotificationService {
    /// What is kept; changed only through `mutate`, which saves.
    private(set) var state: NotificationState
    /// What iOS allows, read when Cue becomes active.
    private(set) var authorization: NotificationAuthorization = .notDetermined
    /// Cue's requests waiting in the system (Debug diagnostics and tests).
    var pendingIdentifiers: [String] = []
    /// How the stored state was found at launch (a damaged one started over).
    let loaded: NotificationStateStore.Loaded

    @ObservationIgnored let center: NotificationCenterClient
    @ObservationIgnored let factsSource: NotificationFactsSource
    @ObservationIgnored let policy: NotificationPolicy
    @ObservationIgnored let now: () -> Date
    @ObservationIgnored let calendar: () -> Calendar
    @ObservationIgnored private let store: NotificationStateStore

    /// The interface language the texts are written in ("pt-BR"); a new one writes every scheduled text again.
    @ObservationIgnored var interfaceLanguage: () -> String = { "" }
    /// "Help improve Cue" is on: outcomes go to the existing telemetry, not only the local counters.
    @ObservationIgnored var sendsUsage: () -> Bool = { false }
    @ObservationIgnored var telemetry: (NotificationTelemetryEvent) -> Void = { TelemetryManager.record($0) }
    /// Days a My Cue Voice tip was shown (no tool or idea on those days).
    @ObservationIgnored var tipDays: () -> [Date] = { [] }
    /// The creator is recording, at the teleprompter, editing, exporting or using the remote: nothing rings or covers the screen.
    @ObservationIgnored var isForegroundBusy: () -> Bool = { false }
    /// Whether a destination still exists (a script, a take, a queue's network…), asked before a notification shows in the foreground.
    @ObservationIgnored var isAlive: (NotificationDestination) -> Bool = { _ in true }
    /// Cue is on screen (scene active): a finished export is only notified when it isn't.
    @ObservationIgnored var isAppActive = true
    /// The in-app introductions shown in this session (one at most).
    @ObservationIgnored var introsThisSession = 0
    /// Cue may invite the creator to allow notifications (off in UI tests unless `-uiTestNotificationInvite`).
    @ObservationIgnored var invitesEnabled = true
    @ObservationIgnored var reconcileTask: Task<Void, Never>?

    init(
        center: NotificationCenterClient, store: NotificationStateStore, facts: NotificationFactsSource,
        policy: NotificationPolicy = .standard, now: @escaping () -> Date = { .now }, calendar: @escaping () -> Calendar = { .current }
    ) {
        self.center = center
        self.store = store
        self.factsSource = facts
        self.policy = policy
        self.now = now
        self.calendar = calendar
        let (state, loaded) = store.load(now: now())
        self.state = state
        self.loaded = loaded
        if loaded != .restored { store.save(state) }
    }

    /// Changes the state and saves it.
    func mutate(_ change: (inout NotificationState) -> Void) {
        change(&state)
        store.save(state)
    }

    // MARK: - Consent

    func isOn(_ category: NotificationCategory) -> Bool { state.isOn(category) }

    /// Turns a category on or off. Turning one on asks iOS when it hasn't been asked yet; a no from iOS keeps the choice (the creator may allow
    /// Cue in Settings later) and nothing is scheduled. Off cancels what that category had waiting.
    @discardableResult
    func setCategory(_ category: NotificationCategory, isOn: Bool) async -> NotificationAuthorization {
        mutate { $0.consent[category.rawValue] = isOn }
        if !isOn { measure(.optedOut, campaign: "category.\(category.rawValue)", category: category) }
        let authorization = isOn ? await requestAuthorizationIfNeeded() : authorization
        await reconcile()
        return authorization
    }

    func setQuietHours(_ hours: QuietHours) {
        mutate { $0.quietHours = hours }
        setNeedsReconcile()
    }

    func setShowsTitles(_ shows: Bool) {
        mutate { $0.showsTitles = shows }
        setNeedsReconcile(rewritesTexts: true)
    }

    /// "Pause for 7 days / 30 days": automatic notifications only; reminders and the routine still ring.
    func pauseAutomatic(days: Int) {
        let until = calendar().date(byAdding: .day, value: days, to: now()) ?? now().addingTimeInterval(TimeInterval(days) * 86_400)
        mutate { $0.pausedUntil = until }
        setNeedsReconcile()
    }

    func resumeAutomatic() {
        mutate { $0.pausedUntil = nil }
        setNeedsReconcile()
    }

    var pausedUntil: Date? { state.isPaused(at: now()) ? state.pausedUntil : nil }

    // MARK: - Permission

    func refreshAuthorization() async {
        authorization = await center.authorization()
    }

    /// Asks iOS once, when it hasn't been asked; never again after a no (iOS wouldn't show the question; Settings is the way).
    func requestAuthorizationIfNeeded() async -> NotificationAuthorization {
        await refreshAuthorization()
        guard authorization == .notDetermined else { return authorization }
        _ = try? await center.requestAuthorization()
        await refreshAuthorization()
        return authorization
    }

    // MARK: - The app's moments

    /// Cue came to the screen: what iOS allows may have changed in Settings, the creator is working, and the plan is made again.
    func appBecameActive() {
        isAppActive = true
        mutate { $0.lastActivity = now() }
        setNeedsReconcile()
    }

    /// Cue left the screen: the plan is made with everything the session changed.
    func appLeftScreen() {
        isAppActive = false
        setNeedsReconcile()
    }

    /// Something the plan reads changed (a script, a take, a queue, a language, the time zone): plan again shortly, once.
    func setNeedsReconcile(rewritesTexts: Bool = false) {
        if rewritesTexts { mutate { $0.scheduledSignatures = [:] } }
        reconcileTask?.cancel()
        reconcileTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.reconcile()
        }
    }

    // MARK: - Erasing

    /// "Delete my Cue data": every pending and delivered notification of Cue's goes, with the reminders, the routine and the history. The
    /// creator's choices (categories, quiet hours, previews, tools declined) stay: they are settings, not data.
    func eraseAll() async {
        let pending = await center.pendingIdentifiers()
        center.removePending(pending)
        center.removeDelivered(pending + state.automatic.map(\.requestID) + state.reminders.map(\.requestID))
        mutate { state in
            var fresh = NotificationState(startedAt: now())
            fresh.consent = state.consent
            fresh.quietHours = state.quietHours
            fresh.showsTitles = state.showsTitles
            fresh.notInterested = state.notInterested
            fresh.lastSeenVersion = state.lastSeenVersion
            fresh.invitesShown = state.invitesShown
            state = fresh
        }
        pendingIdentifiers = []
    }
}
