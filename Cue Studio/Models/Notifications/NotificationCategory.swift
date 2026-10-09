//
//  NotificationCategory.swift
//  Cue Studio
//

import Foundation

/// The five kinds of notification the creator turns on and off on their own (Settings › Notifications). The system's permission
/// is a separate thing: allowing Cue in iOS is never consent to receive a category, and promotions (tools, news) start off.
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

    var title: String {
        switch self {
        case .reminders: String(localized: "My reminders")
        case .projects: String(localized: "Continue my projects")
        case .routine: String(localized: "My creation routine")
        case .discovery: String(localized: "Discover tools and ideas")
        case .whatsNew: String(localized: "What’s new in Cue")
        }
    }

    var detail: String {
        switch self {
        case .reminders: String(localized: "Only the ones you set")
        case .projects: String(localized: "When a script or video you started is waiting")
        case .routine: String(localized: "On the days and at the time you choose")
        case .discovery: String(localized: "Now and then, a tool that fits what you’re making")
        case .whatsNew: String(localized: "New features, and your year in review")
        }
    }

    /// The system's thread: notifications of a category stack together in Notification Center.
    var threadIdentifier: String { "cue.\(rawValue)" }
}
