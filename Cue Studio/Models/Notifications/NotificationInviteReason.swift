//
//  NotificationInviteReason.swift
//  Cue Studio
//

import Foundation

/// Why Cue invites the creator to allow notifications, before the system's question (which iOS asks only once): right after they have a
/// recording to finish, and — only after a "Not now", 14 days later — when they leave a finished script without recording it.
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
