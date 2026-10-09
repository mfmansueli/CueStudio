//
//  NotificationService+DebugPreview.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Debug builds only (Settings › Notifications › DEBUG): one notification of each kind, a few seconds apart, with the real words and pointing at
/// the real scripts, takes and tools on this iPhone, so every one can be seen and tapped without waiting days for the plan. The caps, quiet hours
/// and consent are skipped here on purpose; nothing about it is counted or kept, and planning never cancels these (`debugPrefix`).
extension NotificationService {
    /// Schedules the preview; returns how many were handed to the system (0 when iOS doesn't allow notifications).
    @discardableResult
    func previewEveryNotification(spacing: TimeInterval = 6) async -> Int {
        guard await requestAuthorizationIfNeeded().canSchedule else { return 0 }
        let facts = await factsSource.facts(now: now(), events: [], capabilities: true)
        var previews = projectPreviews(facts) + discoveryPreviews(facts)
        previews.append((NotificationCopy.routine, NotificationPayload(campaign: .routine, destination: .nextAction, projectKey: "routine")))
        previews.append((
            NotificationCopy.content(for: .yearReview(Calendar.current.component(.year, from: now())), showsTitles: state.showsTitles),
            NotificationPayload(campaign: .yearInReview, destination: .yearInReview)
        ))
        previews.append((
            NotificationCopy.content(for: .whatsNew("preview"), showsTitles: false), NotificationPayload(campaign: .whatsNew, destination: .scripts)
        ))
        let ordered = previews.enumerated().sorted { ($0.element.1.campaign.priority, $0.offset) < ($1.element.1.campaign.priority, $1.offset) }
        var scheduled = 0
        for (index, preview) in ordered.map(\.element).enumerated() {
            let request = LocalNotificationRequest(
                identifier: NotificationIdentifier.debugPrefix + String(index), content: preview.0, payload: preview.1,
                trigger: .after(5 + spacing * Double(index))
            )
            if (try? await center.add(request)) != nil { scheduled += 1 }
        }
        pendingIdentifiers = await center.pendingIdentifiers()
        return scheduled
    }

    /// A reminder, a finished export, each project step that exists here, and the return after a break.
    private func projectPreviews(_ facts: NotificationFacts) -> [(NotificationContent, NotificationPayload)] {
        var previews: [(NotificationContent, NotificationPayload)] = []
        if let script = facts.scripts.first {
            previews.append((
                NotificationCopy.reminder(.script(script.id), title: script.title, showsTitles: state.showsTitles),
                NotificationPayload(campaign: .reminder, destination: .script(script.id), projectKey: ProjectKey.script(script.id))
            ))
        }
        if let queue = facts.queues.first, let network = queue.waiting.first {
            let subject = ReminderSubject.share(takeID: queue.takeID, network: network)
            previews.append((
                NotificationCopy.reminder(subject, title: queue.title, showsTitles: state.showsTitles),
                NotificationPayload(campaign: .reminder, destination: subject.destination, projectKey: subject.projectKey)
            ))
        }
        if let take = facts.takes.max(by: { $0.recordedAt < $1.recordedAt }) {
            previews.append((
                NotificationCopy.exportReady(savedToPhotos: true),
                NotificationPayload(campaign: .exportReady, destination: .takeReview(take.id), projectKey: ProjectKey.take(take.id))
            ))
        }
        let projects = ProjectCampaigns.candidates(facts: facts, startedAt: .distantPast, policy: policy)
        var shown: Set<NotificationCampaign> = []
        for candidate in projects where shown.insert(candidate.campaign).inserted {
            previews.append((NotificationCopy.content(for: candidate.subject, showsTitles: state.showsTitles), candidate.payload))
        }
        previews.append((
            NotificationCopy.content(for: .entryPoint, showsTitles: false),
            NotificationPayload(campaign: .returnAfterInactivity, destination: .newScript, projectKey: "return.1")
        ))
        return previews
    }

    /// Every tool that has something to be tried on here (even one already used or declined), and an idea Cue keeps, if there is one.
    private func discoveryPreviews(_ facts: NotificationFacts) -> [(NotificationContent, NotificationPayload)] {
        var open = facts
        open.adopted = []
        let offers = DiscoveryRules.offers(facts: open, state: NotificationState(startedAt: now()), channel: .notification).offers
        var previews = offers.map { offer in
            (
                NotificationCopy.content(for: .feature(offer.intro.feature), showsTitles: false),
                NotificationPayload(campaign: .feature, feature: offer.intro.feature, destination: offer.destination, projectKey: offer.projectKey)
            )
        }
        if let idea = facts.ideas.first {
            previews.append((
                NotificationCopy.content(for: .idea(topic: idea.topicLabel), showsTitles: state.showsTitles),
                NotificationPayload(campaign: .availableIdea, destination: .suggestedIdea(key: idea.key))
            ))
        }
        return previews
    }
}
#endif
