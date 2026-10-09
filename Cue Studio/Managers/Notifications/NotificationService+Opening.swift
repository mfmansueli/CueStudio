//
//  NotificationService+Opening.swift
//  Cue Studio
//

import Foundation

/// A notification opened, and one arriving while Cue is on screen. A tap is taken once per delivered notification, its payload is checked
/// (Cue's, readable by this build), measured as **opened** and remembered for 24 hours (`AttributionContext`). Where it goes is checked again
/// by `NotificationNavigator`, which has the objects. A discovery notification opens the tool's introduction, never the tool itself.
extension NotificationService {
    struct Opening: Equatable {
        var destination: NotificationDestination
        /// A tool's introduction shown before anything opens ("Try it" then goes to `destination`).
        var intro: FeatureIntroRequest?
    }

    /// What a tap opens; nil for a tap already handled, or a notification that isn't Cue's or can't be read (Cue just opens as it was).
    func open(_ interaction: NotificationInteraction) async -> Opening? {
        guard !state.handledInteractions.contains(interaction.id) else { return nil }
        mutate { state in
            state.handledInteractions.append(interaction.id)
            state.handledInteractions = Array(state.handledInteractions.suffix(NotificationState.handledMemory))
        }
        guard interaction.requestID.hasPrefix(NotificationIdentifier.prefix), let payload = interaction.payload else { return nil }
        let moment = now()
        measure(.opened, campaign: payload.campaignName, category: payload.category)
        let step = await currentStep(of: payload.projectKey, at: moment)
        mutate { state in
            state.lastActivity = moment
            state.attribution = AttributionContext(
                campaignName: payload.campaignName, category: payload.category, feature: payload.feature, projectKey: payload.projectKey,
                projectStep: step, openedAt: moment
            )
            // A reminder that was opened has done its job.
            if let id = payload.reminderID { state.reminders.removeAll { $0.id == id } }
        }
        if payload.campaign == .feature, let feature = payload.feature {
            let request = FeatureIntroRequest(
                feature: feature, destination: payload.destination, projectKey: payload.projectKey ?? "feature.\(feature.rawValue)",
                source: .notification(campaign: payload.campaignName)
            )
            return Opening(destination: payload.destination, intro: request)
        }
        if payload.campaign == .yearInReview { recordUse(.yourUniverse) }
        return Opening(destination: payload.destination, intro: nil)
    }

    /// The best next step right now, for the routine and a return after a break: the most advanced real project, else the ways to start one.
    func nextActionDestination() async -> NotificationDestination {
        let facts = await factsSource.facts(now: now(), events: usedFeatures, capabilities: false)
        let projects = ProjectCampaigns.candidates(facts: facts, startedAt: .distantPast, policy: policy).filter { $0.campaign != .savedIdea }
        let best = projects.min { ($0.campaign.priority, $0.earliest) < ($1.campaign.priority, $1.earliest) }
        return best?.destination ?? .newScript
    }

    private func currentStep(of projectKey: String?, at moment: Date) async -> String? {
        guard let projectKey else { return nil }
        let facts = await factsSource.facts(now: moment, events: usedFeatures, capabilities: false)
        let projects = ProjectCampaigns.candidates(facts: facts, startedAt: state.startedAt, policy: policy)
        return projects.first { $0.projectKey == projectKey }?.campaign.rawValue
    }

    // MARK: - While Cue is on screen

    /// Recording, the teleprompter, editing, exporting or the remote: nothing rings or covers the screen (a tool is introduced later, at a
    /// quiet moment). A notification whose object is gone isn't shown. Tools and news only go to the list; the rest show as usual.
    func foregroundPresentation(for payload: NotificationPayload?) -> ForegroundPresentation {
        guard let payload else { return .banner }
        guard isAlive(payload.destination) else { return .hidden }
        if isForegroundBusy() {
            if payload.campaign == .feature, let feature = payload.feature {
                mutate { $0.deferredIntro = feature }
                return .hidden
            }
            return .listOnly
        }
        return payload.category == .discovery || payload.category == .whatsNew ? .listOnly : .banner
    }

    // MARK: - A finished operation

    /// An export that finished while Cue wasn't on screen: one notification, now, to the take's review. Nothing when Cue is on screen (the
    /// creator sees it), when "Continue my projects" is off, or when iOS doesn't allow it. Exports can stop in the background; Cue never
    /// promises they go on.
    func exportFinished(takeID: UUID, savedToPhotos: Bool) async {
        guard !isAppActive, isOn(.projects) else { return }
        await refreshAuthorization()
        guard authorization.canSchedule else { return }
        let request = LocalNotificationRequest(
            identifier: NotificationIdentifier.exportReady(takeID: takeID), content: NotificationCopy.exportReady(savedToPhotos: savedToPhotos),
            payload: NotificationPayload(campaign: .exportReady, destination: .takeReview(takeID), projectKey: ProjectKey.take(takeID)),
            trigger: .soon
        )
        do {
            try await center.add(request)
            measure(.scheduled, campaign: request.payload.campaignName, category: .projects)
        } catch {
            measure(.schedulingFailed, campaign: request.payload.campaignName, category: .projects)
        }
    }
}
