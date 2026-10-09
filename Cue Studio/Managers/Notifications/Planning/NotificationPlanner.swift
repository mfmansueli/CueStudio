//
//  NotificationPlanner.swift
//  Cue Studio
//

import Foundation

/// Gives automatic notifications their times, or none (`NOTIFICATIONS.md` §6). Pure: the same candidates and context always give the
/// same plan. Candidates go in priority order (then earliest first); each takes the first moment, from its earliest, that keeps every
/// rule — the pause, quiet hours, 12 hours away from what the creator set, one a day and two a week counting what was already sent and
/// what this plan holds, one tool or idea a week and never on a day of a My Cue Voice tip, a tool's own 90-day limits — and one per
/// project. A candidate that can't fit in the horizon waits for the next plan. Nothing here says a notification was delivered or seen.
nonisolated enum NotificationPlanner {
    struct Suppressed: Hashable, Sendable {
        var candidate: CampaignCandidate
        var reason: SuppressionReason
    }

    struct Result: Sendable {
        var scheduled: [PlannedNotification] = []
        var suppressed: [Suppressed] = []
    }

    /// How many times one candidate's moment may be pushed before it is left for the next plan.
    private static let maxSteps = 60

    static func plan(_ candidates: [CampaignCandidate], context: PlanningContext) -> Result {
        var result = Result()
        var placed: [PlannedNotification] = []
        var projects: Set<String> = []
        let ordered = candidates.sorted { lhs, rhs in
            (lhs.campaign.priority, lhs.earliest, lhs.requestID) < (rhs.campaign.priority, rhs.earliest, rhs.requestID)
        }
        for candidate in ordered {
            if projects.contains(candidate.projectKey) {
                result.suppressed.append(Suppressed(candidate: candidate, reason: .sameProject))
                continue
            }
            guard placed.count < context.policy.automaticCapacity else {
                result.suppressed.append(Suppressed(candidate: candidate, reason: .capacity))
                continue
            }
            switch slot(for: candidate, placed: placed, context: context) {
            case .placed(let date):
                placed.append(PlannedNotification(candidate: candidate, fireDate: date))
                projects.insert(candidate.projectKey)
            case .refused(let reason):
                result.suppressed.append(Suppressed(candidate: candidate, reason: reason))
            }
        }
        result.scheduled = placed.sorted { $0.fireDate < $1.fireDate }
        return result
    }

    // MARK: - One candidate

    private enum Slot {
        case placed(Date)
        case refused(SuppressionReason)
    }

    private static func slot(for candidate: CampaignCandidate, placed: [PlannedNotification], context: PlanningContext) -> Slot {
        let policy = context.policy
        let end = context.now + policy.horizon
        var moment = max(candidate.earliest, context.now + policy.minimumLead)
        var lastReason = SuppressionReason.beyondHorizon
        for _ in 0..<maxSteps {
            guard moment <= end else { return .refused(lastReason) }
            if candidate.campaign != .returnAfterInactivity, let start = context.returnStart, moment >= start {
                return .refused(.replacedByReturn)
            }
            guard let (later, reason) = push(moment, for: candidate, placed: placed, context: context) else {
                return .placed(moment)
            }
            moment = max(later, moment + 60)
            lastReason = reason
        }
        return .refused(lastReason)
    }

    /// The first rule `moment` breaks, and the moment that rule allows; nil when it breaks none.
    private static func push(
        _ moment: Date, for candidate: CampaignCandidate, placed: [PlannedNotification], context: PlanningContext
    ) -> (Date, SuppressionReason)? {
        let policy = context.policy
        if let paused = context.pausedUntil, paused > moment { return (paused, .paused) }
        let allowed = context.quietHours.nextAllowed(after: moment, calendar: context.calendar)
        if allowed > moment { return (allowed, .quietHours) }
        let near = context.userTimes.filter { abs($0.timeIntervalSince(moment)) < policy.userTimeExclusion }
        if let last = near.max() { return (last + policy.userTimeExclusion, .nearUserReminder) }
        let others = context.sent.map(\.fireDate) + placed.map(\.fireDate)
        let daily = others.filter { abs($0.timeIntervalSince(moment)) < policy.dailyWindow }
        if daily.count >= policy.dailyCap, let last = daily.max() { return (last + policy.dailyWindow, .dailyCap) }
        if let escape = weeklyEscape(moment, others: others, cap: policy.weeklyCap, window: policy.weeklyWindow) {
            return (escape, .weeklyCap)
        }
        if candidate.campaign.isDiscovery, let pushed = discoveryPush(moment, for: candidate, placed: placed, context: context) {
            return pushed
        }
        return nil
    }

    /// Two a week across every automatic category: `moment` must not make any 7-day window that holds it hold more than `cap`.
    private static func weeklyEscape(_ moment: Date, others: [Date], cap: Int, window: TimeInterval) -> Date? {
        let close = others.filter { abs($0.timeIntervalSince(moment)) < window }.sorted()
        guard close.count >= cap else { return nil }
        // Every window that holds `moment` starts in (moment − window, moment]: at that edge, or at an event inside it.
        let starts = [moment - window + 1] + close.filter { $0 <= moment && $0 > moment - window }
        let breaks = starts.contains { start in
            close.filter { $0 >= start && $0 < start + window }.count + 1 > cap
        }
        guard breaks, let first = close.first else { return nil }
        return first + window
    }

    /// One tool or idea a week, never on a My Cue Voice tip's day, and a tool's own limits (two in 90 days, 30 days apart).
    private static func discoveryPush(
        _ moment: Date, for candidate: CampaignCandidate, placed: [PlannedNotification], context: PlanningContext
    ) -> (Date, SuppressionReason)? {
        let policy = context.policy
        let calendar = context.calendar
        let discovery = context.sent.filter(\.isDiscovery).map(\.fireDate)
            + placed.filter { $0.candidate.campaign.isDiscovery }.map(\.fireDate)
        let close = discovery.filter { abs($0.timeIntervalSince(moment)) < policy.weeklyWindow }
        if close.count >= policy.discoveryWeeklyCap, let last = close.max() { return (last + policy.weeklyWindow, .discoveryWeeklyCap) }
        if context.tipDays.contains(where: { calendar.isDate($0, inSameDayAs: moment) }),
           let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: moment)) {
            return (tomorrow, .voiceTipSameDay)
        }
        guard let feature = candidate.feature else { return nil }
        let shown = context.exposures.filter { $0.feature == feature && $0.date <= moment }.map(\.date).sorted()
        if let last = shown.last, moment.timeIntervalSince(last) < policy.featureCooldown {
            return (last + policy.featureCooldown, .featureCooldown)
        }
        let inWindow = shown.filter { moment.timeIntervalSince($0) < policy.featureWindow }
        if inWindow.count >= policy.featureCap, let oldest = inWindow.first { return (oldest + policy.featureWindow, .featureCap) }
        return nil
    }
}
