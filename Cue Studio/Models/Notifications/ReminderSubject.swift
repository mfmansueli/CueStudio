//
//  ReminderSubject.swift
//  Cue Studio
//

import Foundation

/// What a reminder is about: a script, a take, or one network of a "Share to universe" queue (Post later).
nonisolated enum ReminderSubject: Codable, Hashable, Sendable {
    case script(UUID)
    case take(UUID)
    case share(takeID: UUID, network: ShareDestination)

    /// Where the reminder opens: the script's page, the take's review, the queue's step for that network. Never a camera, an export or a post.
    var destination: NotificationDestination {
        switch self {
        case .script(let id): .script(id)
        case .take(let id): .takeReview(id)
        case .share(let takeID, let network): .shareQueue(takeID: takeID, network: network)
        }
    }

    var projectKey: String {
        switch self {
        case .script(let id): ProjectKey.script(id)
        case .take(let id), .share(let id, _): ProjectKey.take(id)
        }
    }
}
