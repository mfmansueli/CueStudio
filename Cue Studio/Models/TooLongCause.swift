//
//  TooLongCause.swift
//  Cue Studio
//

import Foundation

/// "What was too long?": asked when "Too long" is kept in the profile, so the change lands on what makes the next scripts long.
nonisolated enum TooLongCause: String, CaseIterable, Identifiable, Sendable {
    /// Short sentences (`style.sentences`), as "Too long" has always made them.
    case sentences
    /// The usual length (`reach.length`) one step shorter: what Auto aims at (`ScriptRequestFactory.targetRange`).
    case video
    /// One idea per video (`style.oneIdea`).
    case ideas

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sentences: String(localized: "Long sentences")
        case .video: String(localized: "Long video")
        case .ideas: String(localized: "Too many ideas")
        }
    }
}
