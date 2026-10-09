//
//  ProjectKey.swift
//  Cue Studio
//

import Foundation

/// The name of one project in the notification history: a script and the takes read from it are one project, a freestyle take is its own.
/// Used to give each project one next step, never one nudge per stage.
nonisolated enum ProjectKey {
    static func script(_ id: UUID) -> String { "script.\(id.uuidString)" }

    static func take(_ id: UUID) -> String { "take.\(id.uuidString)" }

    /// A take belongs to its script's project; a freestyle take is a project of its own.
    static func of(take: Take) -> String {
        take.scriptID.map(script) ?? Self.take(take.id)
    }
}
