//
//  NotificationCampaign.swift
//  Cue Studio
//

import Foundation

/// Why a notification exists. Each has one category, one priority and one kind of destination (`NOTIFICATIONS.md` §2). The raw
/// values are stable: they are in the payload of notifications already scheduled and in the history kept on this iPhone.
nonisolated enum NotificationCampaign: String, Codable, CaseIterable, Sendable {
    /// A reminder the creator set.
    case reminder
    /// The creator's routine (the days and time they chose).
    case routine
    /// An export finished while Cue was not on screen.
    case exportReady
    /// A "Share to universe" queue with networks still waiting.
    case incompleteSharing
    /// The first script finished, and nothing recorded yet.
    case firstRecording
    /// A draft with words in it, untouched for a while.
    case unfinishedScript
    /// A finished script with no take.
    case readyToRecord
    /// A take with work left and nothing exported.
    case recordingToFinish
    /// A Logbook note still waiting after a week.
    case savedIdea
    /// Seven and 21 days after the last time the creator worked in Cue: two attempts, then nothing until they come back.
    case returnAfterInactivity
    /// One of the tools in `FeatureCatalog`.
    case feature
    /// An idea the model already wrote for the creator's topics, kept on this iPhone.
    case availableIdea
    /// A feature that arrived with the installed version.
    case whatsNew
    /// The year in review is ready.
    case yearInReview

    var category: NotificationCategory {
        switch self {
        case .reminder: .reminders
        case .routine: .routine
        case .exportReady, .incompleteSharing, .firstRecording, .unfinishedScript, .readyToRecord, .recordingToFinish, .savedIdea,
             .returnAfterInactivity:
            .projects
        case .feature, .availableIdea: .discovery
        case .whatsNew, .yearInReview: .whatsNew
        }
    }

    /// 1 goes first: explicit reminders, then a finished operation, sharing, a project, the routine, discovery, news.
    var priority: Int {
        switch self {
        case .reminder: 1
        case .exportReady: 2
        case .incompleteSharing: 3
        case .firstRecording, .unfinishedScript, .readyToRecord, .recordingToFinish, .savedIdea, .returnAfterInactivity: 4
        case .routine: 5
        case .feature, .availableIdea: 6
        case .whatsNew, .yearInReview: 7
        }
    }

    /// Planned by Cue under the caps (a reminder, the routine and a finished export go when they are due).
    var isAutomatic: Bool {
        switch self {
        case .reminder, .routine, .exportReady: false
        default: true
        }
    }

    /// Counts against the one-a-week limit for tools and ideas.
    var isDiscovery: Bool { category == .discovery }
}
