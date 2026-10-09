//
//  NotificationDestination.swift
//  Cue Studio
//

import Foundation

/// Where a notification takes the creator: always a place inside Cue, named by its kind and the IDs of real objects, never a URL.
/// Every destination is checked again when it is opened (the object may be gone, the tool unavailable); `NotificationRouteResolver`
/// decides what opens then. Part of the payload (`NotificationPayload.version`), so cases are only ever added.
nonisolated enum NotificationDestination: Codable, Hashable, Sendable {
    /// The script's page, with Record at its foot (recording preparation: nothing starts the camera).
    case script(UUID)
    /// The script's page, editing.
    case scriptEditor(UUID)
    /// The take's review.
    case takeReview(UUID)
    /// The take's review, then Quick edit, on a tool when one is named.
    case takeEditor(UUID, tool: EditorTool?)
    /// The next network of a "Share to universe" queue, or the one named.
    case shareQueue(takeID: UUID, network: ShareDestination?)
    /// The Logbook, with the note when one is named.
    case logbook(entryID: UUID?)
    /// The idea the model wrote, by its key (`IdeaKey`): it goes in the card's field, nothing is written.
    case suggestedIdea(key: String)
    /// "Need an idea?".
    case ideas
    /// My Cue Voice's four questions.
    case voiceSetup
    /// Import my writing.
    case importWriting
    /// The script's page, to try Voice Following from Record.
    case voiceFollowing(scriptID: UUID)
    /// Settings › Remote.
    case remote
    /// Settings › Prompter › Social safe zone.
    case safeZone
    /// Your universe.
    case universe
    /// Your universe, with the year in review.
    case yearInReview
    /// "+": the ways to start a script.
    case newScript
    /// The Scripts tab.
    case scripts
    /// The best next step, decided when the notification is opened (the routine, a return after a break).
    case nextAction
    /// Settings › Notifications.
    case notificationSettings
}
