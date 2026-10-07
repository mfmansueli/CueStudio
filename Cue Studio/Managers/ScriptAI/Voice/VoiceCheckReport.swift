//
//  VoiceCheckReport.swift
//  Cue Studio
//

import Foundation

/// What the check after a script did, for the count of how often it is needed (never the words): which kinds of rule the first draft broke, which the
/// second still broke, and how much of the voice was sent.
nonisolated struct VoiceCheckReport: Sendable, Equatable {
    /// What the first draft broke.
    let first: [VoiceViolation.Kind]
    /// What the new attempt still broke.
    let remaining: [VoiceViolation.Kind]
    let use: VoiceUse

    var line: String {
        "voice.check first=\(first.map(\.rawValue).joined(separator: ",")) remaining=\(remaining.map(\.rawValue).joined(separator: ",")) use=\(use.rawValue)"
    }
}
