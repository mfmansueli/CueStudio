//
//  ScriptRequest.swift
//  Cue Studio
//

import Foundation

/// Everything the AI needs to draft a script.
nonisolated struct ScriptRequest: Hashable, Sendable {
    var type: ScriptType
    /// Brief answers keyed by `BriefField.key`.
    var brief: [String: String]
    var platform: Platform
    var tone: Tone
    /// Catchphrases to weave in; empty when "Use my phrases" is off or the format is serious.
    var phrases: [String]
    var niches: [Niche]
    /// Target length in seconds (the platform's ideal range).
    var idealRange: ClosedRange<TimeInterval>
}
