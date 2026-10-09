//
//  NotificationServiceHarness.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// A `NotificationService` on a fake center, made-up facts, a clock the test moves and a UTC calendar; its own UserDefaults suite.
@MainActor
final class NotificationServiceHarness {
    let center: FakeNotificationCenter
    let facts: FakeNotificationFacts
    let defaults = TestDefaults()
    let service: NotificationService
    private let clock: Clock

    /// The moment the service reads.
    var now: Date {
        get { clock.now }
        set { clock.now = newValue }
    }

    private final class Clock {
        var now = NotificationFixtures.monday
    }

    init(status: NotificationAuthorization = .authorized, facts: NotificationFacts? = nil, policy: NotificationPolicy = .standard) {
        let clock = Clock()
        self.clock = clock
        center = FakeNotificationCenter(status: status)
        self.facts = FakeNotificationFacts(facts ?? NotificationFacts(now: NotificationFixtures.monday))
        service = NotificationService(
            center: center, store: NotificationStateStore(defaults: defaults.defaults), facts: self.facts, policy: policy,
            now: { clock.now }, calendar: { NotificationFixtures.utc }
        )
    }

    deinit {
        defaults.tearDown()
    }

    /// A ready script with no take, in the facts.
    @discardableResult
    func addReadyScript(updatedAt: Date? = nil) -> UUID {
        let script = NotificationFixtures.script(.ready, updatedAt: updatedAt ?? now)
        facts.facts.scripts.append(script)
        return script.id
    }

    func automatic() -> [LocalNotificationRequest] {
        center.requests.values.filter { NotificationIdentifier.isAutomatic($0.identifier) }
    }

    func tap(_ payload: NotificationPayload, request: String = "cue.auto.test") -> NotificationInteraction {
        NotificationInteraction(requestID: request, payloadText: payload.encoded(), deliveredAt: now)
    }

    func tomorrowAtTen() -> LocalDateTime {
        LocalDateTime(year: 2026, month: 10, day: 13, hour: 10, minute: 0)
    }
}
