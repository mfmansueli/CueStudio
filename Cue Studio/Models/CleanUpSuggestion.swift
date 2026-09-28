//
//  CleanUpSuggestion.swift
//  Cue Studio
//

import Foundation

/// Something Clean Up found that could be cut. Only a suggestion: nothing leaves the edit until
/// the creator removes it, which takes its span out of the timeline like any other cut (and undo
/// brings it back). A pause can be dramatic and "like" can mean something, so the creator decides.
nonisolated struct CleanUpSuggestion: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var kind: CleanUpKind
    /// Seconds of the original recording.
    var span: TimeSpan
    /// What was said ("um", "let me start again"); nil for pauses.
    var text: String?
    /// 0 to 1: how sure the detector is.
    var confidence: Double
    /// The creator chose to keep it, so "Remove all" leaves it alone.
    var isKept = false
}
