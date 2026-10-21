//
//  NotificationGroup.swift
//  Cue Studio
//

import Foundation

/// The switches of Settings › Notifications (owner's redesign, 22/10/2026: short and direct): two under From Cue and the creation routine
/// under its own. The reminders the creator sets aren't a switch: they always arrive. The categories stay what the planner reads
/// (`NotificationCategory`); a group is on when any of its categories is, and switching it sets all of them.
nonisolated enum NotificationGroup: String, CaseIterable, Identifiable, Sendable {
    /// A nudge when a project the creator started is waiting.
    case finish
    /// A tool or an idea that fits what they make, and what's new in Cue (their year in review too).
    case news
    /// The days and time the creator chose to create.
    case routine

    var id: String { rawValue }

    var categories: [NotificationCategory] {
        switch self {
        case .finish: [.projects]
        case .news: [.discovery, .whatsNew]
        case .routine: [.routine]
        }
    }

    var title: String {
        switch self {
        case .finish: String(localized: "Help me finish what I start")
        case .news: String(localized: "Tools and news")
        case .routine: String(localized: "Remind me to create")
        }
    }

    var detail: String? {
        switch self {
        case .finish: String(localized: "When a script or video is waiting.")
        case .news: String(localized: "Now and then, something new for you.")
        case .routine: nil
        }
    }
}
