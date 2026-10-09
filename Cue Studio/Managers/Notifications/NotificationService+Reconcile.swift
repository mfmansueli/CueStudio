//
//  NotificationService+Reconcile.swift
//  Cue Studio
//

import Foundation

/// Making what the system holds match what should be (`NOTIFICATIONS.md` §8): run when Cue comes to the screen or leaves it, and when
/// something the plan reads changes. Every request has a deterministic identifier, so scheduling again replaces it and an unchanged one is
/// left alone; whatever of Cue's is pending and no longer wanted is cancelled (a deleted script, a step done, a category turned off…).
extension NotificationService {
    /// How long a reminder stays in the list after its time, as "due".
    static let dueReminderLifetime: TimeInterval = 7 * 24 * 3600

    func reconcile() async {
        let moment = now()
        await refreshAuthorization()
        let facts = await factsSource.facts(now: moment, events: usedFeatures, capabilities: true)
        tidy(at: moment, version: facts.appVersion)
        let projects = ProjectCampaigns.candidates(facts: facts, startedAt: state.startedAt, policy: policy)
        noteProgress(facts: facts, projects: projects, at: moment)
        dropRemindersWithoutSubject(facts)
        if state.contentLanguage != interfaceLanguage() {
            mutate {
                $0.contentLanguage = interfaceLanguage()
                $0.scheduledSignatures = [:]
            }
        }
        let reminders = reminderRequests(at: moment)
        let routine = routineRequests()
        let plan = automaticPlan(facts: facts, projects: projects, at: moment)
        let accepted = await apply(reminders + routine + plan.requests)
        mutate { state in
            for index in state.reminders.indices { state.reminders[index].isScheduled = accepted.contains(state.reminders[index].requestID) }
            for planned in plan.planned where accepted.contains(planned.candidate.requestID) {
                state.automatic.append(AutomaticRecord(
                    requestID: planned.candidate.requestID, campaign: planned.candidate.campaign, feature: planned.candidate.feature,
                    projectKey: planned.candidate.projectKey, fireDate: planned.fireDate, status: .reserved
                ))
            }
        }
    }

    // MARK: - Housekeeping

    /// Reservations whose time passed count as sent (and as the tool's exposure); the rest are planned again. Old history goes.
    private func tidy(at moment: Date, version: String) {
        mutate { state in
            for index in state.automatic.indices where state.automatic[index].status == .reserved && state.automatic[index].fireDate <= moment {
                state.automatic[index].status = .sent
                let record = state.automatic[index]
                if let feature = record.feature {
                    state.exposures.append(FeatureExposure(feature: feature, date: record.fireDate, kind: .notification))
                }
                if record.campaign == .yearInReview, let year = Int(record.projectKey.replacingOccurrences(of: "year.", with: "")) {
                    state.announcedYearReviews.append(year)
                }
                if record.campaign == .whatsNew { state.announcedWhatsNew.append(record.projectKey.replacingOccurrences(of: "whatsNew.", with: "")) }
            }
            state.automatic.removeAll { $0.status == .reserved }
            let oldest = moment.addingTimeInterval(-TimeInterval(NotificationState.historyDays) * 86_400)
            state.automatic.removeAll { $0.fireDate < oldest }
            state.exposures.removeAll { $0.date < oldest }
            state.recentMeasures = state.recentMeasures.filter { moment.timeIntervalSince($0.value) < Self.measureInterval }
            state.snoozedFeatures = state.snoozedFeatures.filter { $0.value > moment }
            if let attribution = state.attribution, !attribution.isActive(at: moment) { state.attribution = nil }
            state.reminders.removeAll { reminder in
                guard let date = reminder.time.date(in: calendar()) else { return true }
                return moment.timeIntervalSince(date) > Self.dueReminderLifetime
            }
            if state.lastSeenVersion != version {
                // An update (never a fresh install, which has no version before it) is what "What's new" talks about.
                state.updatedFromVersion = state.lastSeenVersion
                state.lastSeenVersion = version
            }
        }
    }

    /// Tools seen used for the first time stop being introduced; with an opened notification still counting (24 h), a tool used or a step
    /// done is credited to it.
    private func noteProgress(facts: NotificationFacts, projects: [CampaignCandidate], at moment: Date) {
        let newlyAdopted = facts.adopted.filter { state.adopted[$0.rawValue] == nil }
        if !newlyAdopted.isEmpty { mutate { state in for feature in newlyAdopted { state.adopted[feature.rawValue] = moment } } }
        guard let attribution = state.attribution, attribution.isActive(at: moment) else { return }
        if let feature = attribution.feature, facts.adopted.contains(feature) {
            measure(.featureCompleted, campaign: attribution.campaignName, category: attribution.category)
            mutate { $0.attribution?.feature = nil }
        }
        if let key = attribution.projectKey, let step = attribution.projectStep {
            let current = projects.first { $0.projectKey == key }?.campaign.rawValue
            if current != step {
                measure(.nextActionCompleted, campaign: attribution.campaignName, category: attribution.category)
                mutate { $0.attribution?.projectStep = nil }
            }
        }
    }

    /// A reminder whose script or take is gone, or whose network was posted (or whose queue ended), is cancelled.
    private func dropRemindersWithoutSubject(_ facts: NotificationFacts) {
        let gone = state.reminders.filter { reminder in
            switch reminder.subject {
            case .script(let id): facts.script(id) == nil
            case .take(let id): facts.take(id) == nil
            case .share(let takeID, let network): !(facts.queues.first { $0.takeID == takeID }?.waiting.contains(network) ?? false)
            }
        }
        guard !gone.isEmpty else { return }
        let ids = gone.map(\.requestID)
        center.removePending(ids)
        center.removeDelivered(ids)
        for _ in gone { measure(.cancelled, campaign: "reminders.reminder", category: .reminders) }
        mutate { state in state.reminders.removeAll { reminder in gone.contains { $0.id == reminder.id } } }
    }

    // MARK: - What should be scheduled

    /// The nearest future reminders, as many as there are places for.
    private func reminderRequests(at moment: Date) -> [LocalNotificationRequest] {
        guard isOn(.reminders), authorization.canSchedule else { return [] }
        let calendar = calendar()
        let upcoming = state.reminders.filter { !$0.isDue(at: moment, calendar: calendar) }.sorted { $0.time < $1.time }
        return upcoming.prefix(policy.reminderCapacity).map { request(for: $0, calendar: calendar) }
    }

    func request(for reminder: Reminder, calendar: Calendar) -> LocalNotificationRequest {
        LocalNotificationRequest(
            identifier: reminder.requestID,
            content: NotificationCopy.reminder(reminder.subject, title: reminder.title, showsTitles: state.showsTitles),
            payload: NotificationPayload(
                campaign: .reminder, destination: reminder.subject.destination, projectKey: reminder.subject.projectKey, reminderID: reminder.id
            ),
            // The clock reading it actually lands on (a time skipped by daylight saving rings just after the gap).
            trigger: .at(reminder.time.resolved(in: calendar) ?? reminder.time)
        )
    }

    private func routineRequests() -> [LocalNotificationRequest] {
        guard isOn(.routine), authorization.canSchedule, let routine = state.routine else { return [] }
        return routine.weekdays.sorted().prefix(policy.routineCapacity).map { weekday in
            LocalNotificationRequest(
                identifier: NotificationIdentifier.routine(weekday: weekday), content: NotificationCopy.routine,
                payload: NotificationPayload(campaign: .routine, destination: .nextAction, projectKey: "routine"),
                trigger: .weekly(weekday: weekday, hour: routine.hour, minute: routine.minute)
            )
        }
    }

    // MARK: - Applying

    /// Cancels Cue's pending requests that aren't wanted any more (a finished export's one-shot stays) and hands the system what changed.
    /// Returns the requests the system holds now.
    private func apply(_ desired: [LocalNotificationRequest]) async -> Set<String> {
        let pending = Set(await center.pendingIdentifiers())
        let wanted = Set(desired.map(\.identifier))
        let stale = pending.filter { !wanted.contains($0) && !$0.hasPrefix(NotificationIdentifier.operationPrefix) }
        center.removePending(Array(stale))
        for identifier in stale where NotificationIdentifier.isAutomatic(identifier) {
            let record = state.automatic.last { $0.requestID == identifier }
            measure(.cancelled, campaign: record.map { campaignName($0) } ?? "automatic", category: record?.campaign.category ?? .projects)
        }
        var accepted: Set<String> = []
        var signatures: [String: String] = [:]
        for request in desired {
            let signature = Self.signature(of: request)
            if pending.contains(request.identifier), state.scheduledSignatures[request.identifier] == signature {
                accepted.insert(request.identifier)
                signatures[request.identifier] = signature
                continue
            }
            do {
                try await center.add(request)
                accepted.insert(request.identifier)
                signatures[request.identifier] = signature
                measure(.scheduled, campaign: request.payload.campaignName, category: request.payload.category)
            } catch {
                measure(.schedulingFailed, campaign: request.payload.campaignName, category: request.payload.category)
            }
        }
        mutate { $0.scheduledSignatures = signatures }
        pendingIdentifiers = await center.pendingIdentifiers()
        return accepted
    }

    private func campaignName(_ record: AutomaticRecord) -> String {
        NotificationPayload(campaign: record.campaign, feature: record.feature, destination: .scripts).campaignName
    }

    static func signature(of request: LocalNotificationRequest) -> String {
        [String(describing: request.trigger), request.content.title, request.content.body, request.payload.encoded()].joined(separator: "|")
    }
}
