//
//  FakeNotificationFacts.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Made-up facts for `NotificationService`: whatever the test sets, at the moment asked, with the recorded uses added to what is adopted.
@MainActor
final class FakeNotificationFacts: NotificationFactsSource {
    var facts: NotificationFacts

    init(_ facts: NotificationFacts = NotificationFacts(now: TestData.now)) {
        self.facts = facts
    }

    func facts(now: Date, events: Set<FeatureID>, capabilities: Bool) async -> NotificationFacts {
        var current = facts
        current.now = now
        current.adopted.formUnion(events)
        return current
    }
}
