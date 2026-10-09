//
//  NotificationService+Discovery.swift
//  Cue Studio
//

import Foundation

/// Introducing tools in the app: after a discovery notification is opened, for a notification that arrived while the creator was busy, or
/// (with "Discover tools and ideas" on) once after a session at the teleprompter. One a session at most, never on a My Cue Voice tip's day,
/// one a week across notifications and the app, a tool at most twice in 90 days and 30 days apart, never again once used or declined.
/// "Try it" opens the tool; nothing runs until the creator uses it there.
extension NotificationService {
    /// A tool was put in front of the creator today (a discovery notification whose time passed, or an introduction in the app): the My Cue
    /// Voice tip waits for another day.
    var introducedToday: Bool {
        let calendar = calendar()
        let moment = now()
        return state.exposures.contains { calendar.isDate($0.date, inSameDayAs: moment) }
    }

    /// The uses only an event can tell, as recorded.
    var usedFeatures: Set<FeatureID> { Set(state.used.keys.compactMap(FeatureID.init(rawValue:))) }

    /// A tool was used for real where only the moment can tell (Voice Following played, a remote connected, the universe visited, an idea
    /// used). Its introductions stop; with its notification opened in the last 24 hours, it counts as that campaign's `feature_completed`.
    func recordUse(_ feature: FeatureID) {
        guard state.used[feature.rawValue] == nil else { return }
        mutate { $0.used[feature.rawValue] = now() }
        setNeedsReconcile()
    }

    /// The introduction for a quiet moment, or nil. `afterSession`: the creator just left the teleprompter (the moment a tool for the next
    /// video fits, and the only one Remote Control is introduced at).
    func inAppIntro(afterSession: Bool) async -> FeatureIntroRequest? {
        guard isOn(.discovery), introsThisSession == 0, !isForegroundBusy() else { return nil }
        let moment = now()
        let calendar = calendar()
        guard !tipDays().contains(where: { calendar.isDate($0, inSameDayAs: moment) }) else { return nil }
        let deferred = state.deferredIntro
        guard deferred != nil || afterSession else { return nil }
        let facts = await factsSource.facts(now: moment, events: usedFeatures, capabilities: true)
        let offers = DiscoveryRules.offers(facts: facts, state: state, channel: .inApp).offers
        if let deferred {
            mutate { $0.deferredIntro = nil }
            guard let offer = offers.first(where: { $0.intro.feature == deferred }) else { return nil }
            return FeatureIntroRequest(
                feature: deferred, destination: offer.destination, projectKey: offer.projectKey,
                source: .notification(campaign: "discover.\(deferred.rawValue)")
            )
        }
        let lastWeek = state.exposures.filter { moment.timeIntervalSince($0.date) < policy.weeklyWindow }
        guard lastWeek.count < policy.discoveryWeeklyCap, let offer = offers.first(where: { mayShow($0.intro.feature, at: moment) }) else {
            return nil
        }
        return FeatureIntroRequest(feature: offer.intro.feature, destination: offer.destination, projectKey: offer.projectKey, source: .inApp)
    }

    /// A tool's own limits: twice in 90 days at most, 30 days apart.
    func mayShow(_ feature: FeatureID, at moment: Date) -> Bool {
        let shown = state.exposures.filter { $0.feature == feature }.map(\.date)
        if let last = shown.max(), moment.timeIntervalSince(last) < policy.featureCooldown { return false }
        return shown.filter { moment.timeIntervalSince($0) < policy.featureWindow }.count < policy.featureCap
    }

    // MARK: - The introduction's answers

    /// It is on screen. An in-app one counts as the tool's exposure (a notification's counted when its time passed).
    func introShown(_ request: FeatureIntroRequest) {
        introsThisSession += 1
        guard request.source == .inApp else { return }
        mutate { $0.exposures.append(FeatureExposure(feature: request.feature, date: now(), kind: .inApp)) }
        measure(.eligible, campaign: request.campaignName, category: .discovery)
    }

    /// "Try it": the tool opens. Started is measured here; completed only when it is used for real (`FeatureAdoption`).
    func introAccepted(_ request: FeatureIntroRequest) {
        measure(.featureStarted, campaign: request.campaignName, category: .discovery)
        mutate { state in
            state.attribution = AttributionContext(
                campaignName: request.campaignName, category: .discovery, feature: request.feature, projectKey: nil, projectStep: nil,
                openedAt: now()
            )
        }
    }

    /// "Not now": not before 30 days.
    func introSnoozed(_ request: FeatureIntroRequest) {
        mutate { $0.snoozedFeatures[request.feature.rawValue] = now() + policy.featureCooldown }
        measure(.snoozed, campaign: request.campaignName, category: .discovery)
        setNeedsReconcile()
    }

    /// "Don't suggest this": never again.
    func introDeclined(_ request: FeatureIntroRequest) {
        mutate { state in
            if !state.notInterested.contains(request.feature.rawValue) { state.notInterested.append(request.feature.rawValue) }
        }
        measure(.optedOut, campaign: request.campaignName, category: .discovery)
        setNeedsReconcile()
    }
}
