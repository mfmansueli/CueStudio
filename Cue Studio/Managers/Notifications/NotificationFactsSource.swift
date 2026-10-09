//
//  NotificationFactsSource.swift
//  Cue Studio
//

import Foundation

/// Where the rules' facts come from (`AppNotificationFacts` in the app; tests give made-up ones).
protocol NotificationFactsSource: AnyObject {
    /// The projects, tools used and what this iPhone can do, now. `events` are the uses only an event can tell (`NotificationState.used`).
    /// Without `capabilities` the languages aren't asked about (opening a notification only needs the projects).
    func facts(now: Date, events: Set<FeatureID>, capabilities: Bool) async -> NotificationFacts
}
