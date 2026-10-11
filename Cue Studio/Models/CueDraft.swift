//
//  CueDraft.swift
//  Cue Studio
//

import Foundation

/// The words Cue drafted for a script, as they arrived, kept on this iPhone until the script is recorded: then what the creator changed
/// in them tells whether the recorded version is theirs enough to learn from (`DraftLearningService`).
nonisolated struct CueDraft: Codable, Equatable, Sendable {
    var text: String
    var draftedAt: Date = .now
}
