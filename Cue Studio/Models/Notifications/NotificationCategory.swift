//
//  NotificationCategory.swift
//  Cue Studio
//

import Foundation

/// The five kinds of notification Cue sends, as the planner reads them; Settings › Notifications shows them as three switches
/// (`NotificationGroup`). Tools and news start off; "Turn on" there, whose card names them, turns them on with iOS's yes.
nonisolated enum NotificationCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Only the reminders the creator sets (a script, a take, Post later).
    case reminders
    /// A nudge when a real project is waiting: a script to record, a recording to finish, a video to share.
    case projects
    /// The days and time the creator chose to create.
    case routine
    /// A tool that fits what they are making, or an idea Cue already has for their topics. Opt-in.
    case discovery
    /// A feature that is new in the installed version, or their year in review. Opt-in.
    case whatsNew

    var id: String { rawValue }

    /// Only what the creator asked for, and the projects they started, are on before they choose. Tools and news wait for a yes.
    var isOnByDefault: Bool {
        switch self {
        case .reminders, .projects, .routine: true
        case .discovery, .whatsNew: false
        }
    }

    /// Cue decides when these go (and the caps, quiet hours and pauses apply); reminders and the routine go when the creator said.
    var isAutomatic: Bool {
        switch self {
        case .projects, .discovery, .whatsNew: true
        case .reminders, .routine: false
        }
    }

    /// The system's thread: notifications of a category stack together in Notification Center.
    var threadIdentifier: String { "cue.\(rawValue)" }
}
