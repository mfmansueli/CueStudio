//
//  NotificationService+Metrics.swift
//  Cue Studio
//

import Foundation

/// Measuring the campaigns (`NOTIFICATIONS.md` §9): a local counter for every outcome (read in Debug, kept on this iPhone), and the same
/// event to the existing telemetry when the creator turned on "Help improve Cue". "Eligible" and "suppressed" are counted once a day per
/// request, since a plan is made several times a day. Nothing about the content is measured, and nothing claims delivery.
extension NotificationService {
    static let measureInterval: TimeInterval = 24 * 3600

    func measure(_ outcome: NotificationOutcome, campaign: String, category: NotificationCategory, reason: SuppressionReason? = nil) {
        let event = NotificationTelemetryEvent(campaign: campaign, category: category, outcome: outcome, reason: reason)
        mutate { $0.counters[event.counterKey, default: 0] += 1 }
        if sendsUsage() { telemetry(event) }
    }

    /// Counts "eligible" or "suppressed" for a request at most once a day.
    func measureOnceADay(
        _ outcome: NotificationOutcome, requestID: String, campaign: String, category: NotificationCategory, reason: SuppressionReason? = nil
    ) {
        let key = [requestID, outcome.rawValue, reason?.rawValue].compactMap(\.self).joined(separator: "|")
        let moment = now()
        if let last = state.recentMeasures[key], moment.timeIntervalSince(last) < Self.measureInterval { return }
        mutate { $0.recentMeasures[key] = moment }
        measure(outcome, campaign: campaign, category: category, reason: reason)
    }

    /// The local count of one outcome ("discover.cleanUp.opened").
    func count(_ outcome: NotificationOutcome, campaign: String) -> Int {
        state.counters["\(campaign).\(outcome.rawValue)"] ?? 0
    }
}
