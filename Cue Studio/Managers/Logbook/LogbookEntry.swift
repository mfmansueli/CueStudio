//
//  LogbookEntry.swift
//  Cue Studio
//

import Foundation

/// An idea caught in the Logbook, spoken or typed, waiting to be shaped into a script.
nonisolated struct LogbookEntry: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var text: String
    /// Seconds spoken, nil for an idea typed.
    var spokenSeconds: Int?
    var createdAt: Date
    /// The creator's topic it belongs to (`OnboardingTopic.id`), picked on this iPhone; nil when none.
    var topic: String?
    /// The script it became. A shaped idea no longer waits.
    var shapedScriptID: UUID?

    var isSpoken: Bool { spokenSeconds != nil }
    var isWaiting: Bool { shapedScriptID == nil }
}
