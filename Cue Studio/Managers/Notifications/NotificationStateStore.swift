//
//  NotificationStateStore.swift
//  Cue Studio
//

import Foundation

/// Where the notifications' state lives: one JSON in UserDefaults (`DefaultsKey.notificationState`). Nothing in it is content: kinds, IDs,
/// dates, choices, and the titles of reminders for the list in Settings.
struct NotificationStateStore {
    enum Loaded: Equatable {
        /// Nothing saved yet: a first run of the notifications (a new install, or an update that brings them).
        case fresh
        case restored
        /// What was saved couldn't be read at all: it starts over (no history is invented, nothing is sent at once).
        case damaged
    }

    let defaults: UserDefaults

    func load(now: Date) -> (state: NotificationState, loaded: Loaded) {
        guard let data = defaults.data(forKey: DefaultsKey.notificationState) else { return (NotificationState(startedAt: now), .fresh) }
        guard let state = try? JSONDecoder().decode(NotificationState.self, from: data) else {
            return (NotificationState(startedAt: now), .damaged)
        }
        return (state, .restored)
    }

    func save(_ state: NotificationState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: DefaultsKey.notificationState)
    }
}
