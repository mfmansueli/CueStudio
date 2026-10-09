//
//  NotificationContent.swift
//  Cue Studio
//

import Foundation

/// The words of one notification: a title and one line, written in the interface language when it is scheduled.
nonisolated struct NotificationContent: Hashable, Sendable {
    var title: String
    var body: String
}
