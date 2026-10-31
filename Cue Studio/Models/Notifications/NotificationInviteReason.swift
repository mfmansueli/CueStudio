//
//  NotificationInviteReason.swift
//  Cue Studio
//

import Foundation

/// Why Cue invites the creator to allow notifications, before the system's question (which iOS asks only once): back from the camera with a
/// video still to finish, in a session after the one of their first recording, and — only after a "Not now", 14 days later — when they
/// leave a finished script's page without recording it (its button then sets the reminder for that script).
nonisolated enum NotificationInviteReason: String, Codable, Hashable, Identifiable, Sendable {
    case firstRecording
    case readyScript

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstRecording: String(localized: "Want Cue to remind you to finish this video?")
        case .readyScript: String(localized: "Want a reminder to record this script?")
        }
    }
}
