//
//  NotificationService+Plan.swift
//  Cue Studio
//

import Foundation

/// The automatic notifications: every candidate the creator's categories allow (projects and the two attempts after a break, a tool or an
/// idea, news), given times by `NotificationPlanner` under the caps. Measured as eligible or suppressed (with the reason), once a day.
extension NotificationService {
    struct AutomaticPlan {
        var planned: [PlannedNotification] = []
        var requests: [LocalNotificationRequest] = []
    }

    func automaticPlan(facts: NotificationFacts, projects: [CampaignCandidate], at moment: Date) -> AutomaticPlan {
        guard authorization.canSchedule else { return AutomaticPlan() }
        let calendar = calendar()
        let lastActivity = max(state.lastActivity ?? state.startedAt, state.startedAt)
        var candidates: [CampaignCandidate] = []
        if isOn(.projects) {
            candidates += projects
            candidates += ProjectCampaigns.returnAttempts(after: lastActivity, projects: projects, policy: policy)
        }
        if isOn(.discovery) { candidates += discoveryCandidates(facts: facts, after: lastActivity) }
        if isOn(.whatsNew) { candidates += newsCandidates(facts: facts, at: moment) }
        let context = PlanningContext(
            now: moment, calendar: calendar, policy: policy, quietHours: state.quietHours,
            pausedUntil: state.isPaused(at: moment) ? state.pausedUntil : nil,
            sent: state.automatic.filter { $0.status == .sent }, exposures: state.exposures,
            userTimes: userTimes(at: moment, calendar: calendar), tipDays: tipDays(),
            returnStart: isOn(.projects) ? policy.returnAttempts.first.map { lastActivity + $0 } : nil
        )
        let result = NotificationPlanner.plan(candidates, context: context)
        for planned in result.scheduled {
            let candidate = planned.candidate
            measureOnceADay(.eligible, requestID: candidate.requestID, campaign: candidate.payload.campaignName, category: candidate.campaign.category)
        }
        for held in result.suppressed {
            let candidate = held.candidate
            measureOnceADay(
                .suppressed, requestID: candidate.requestID, campaign: candidate.payload.campaignName, category: candidate.campaign.category,
                reason: held.reason
            )
        }
        let requests = result.scheduled.map { planned in
            LocalNotificationRequest(
                identifier: planned.candidate.requestID,
                content: NotificationCopy.content(for: planned.candidate.subject, showsTitles: state.showsTitles),
                payload: planned.candidate.payload,
                trigger: .at(LocalDateTime(planned.fireDate, calendar: calendar))
            )
        }
        return AutomaticPlan(planned: result.scheduled, requests: requests)
    }

    /// The tools that fit (the first few, the planner takes the first it can place) and an idea Cue already has for the creator's topics.
    private func discoveryCandidates(facts: NotificationFacts, after lastActivity: Date) -> [CampaignCandidate] {
        let (offers, declined) = DiscoveryRules.offers(facts: facts, state: state, channel: .notification)
        for held in declined where held.reason != .unavailable {
            let name = "discover.\(held.feature.rawValue)"
            measureOnceADay(.suppressed, requestID: name, campaign: name, category: .discovery, reason: held.reason)
        }
        let earliest = lastActivity + policy.discoveryDelay
        var found = offers.prefix(3).enumerated().map { index, offer in
            CampaignCandidate(
                campaign: .feature, feature: offer.intro.feature, projectKey: "discover.\(offer.projectKey)", earliest: earliest,
                destination: offer.destination, subject: .feature(offer.intro.feature), rank: index
            )
        }
        if let idea = facts.ideas.first {
            found.append(CampaignCandidate(
                campaign: .availableIdea, feature: nil, projectKey: "idea", earliest: earliest,
                destination: .suggestedIdea(key: idea.key), subject: .idea(topic: idea.topicLabel)
            ))
        }
        return found
    }

    /// The year in review once it is ready, and what an update brings (never on a fresh install).
    private func newsCandidates(facts: NotificationFacts, at moment: Date) -> [CampaignCandidate] {
        var found: [CampaignCandidate] = []
        if let year = facts.yearReviewReady, !state.announcedYearReviews.contains(year) {
            found.append(CampaignCandidate(
                campaign: .yearInReview, feature: nil, projectKey: "year.\(year)", earliest: moment,
                destination: .yearInReview, subject: .yearReview(year)
            ))
        }
        let entries = WhatsNewCatalog.announcements(
            current: facts.appVersion, previous: state.updatedFromVersion, announced: state.announcedWhatsNew
        )
        for entry in entries {
            found.append(CampaignCandidate(
                campaign: .whatsNew, feature: nil, projectKey: "whatsNew.\(entry.id)", earliest: moment + policy.discoveryDelay,
                destination: entry.destination, subject: .whatsNew(entry.id)
            ))
        }
        return found
    }

    /// The reminders and routine times the creator set, from 12 hours ago to the end of the horizon: automatic ones keep away from them.
    func userTimes(at moment: Date, calendar: Calendar) -> [Date] {
        let from = moment - policy.userTimeExclusion
        let until = moment + policy.horizon
        var times: [Date] = []
        if isOn(.reminders) {
            times += state.reminders.compactMap { $0.time.date(in: calendar) }.filter { $0 >= from && $0 <= until }
        }
        if isOn(.routine), let routine = state.routine {
            times += routine.occurrences(after: from, until: until, calendar: calendar)
        }
        return times
    }
}
