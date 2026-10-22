//
//  VoiceUse.swift
//  Cue Studio
//

import Foundation

/// How much of the creator's voice a script was written with.
nonisolated enum VoiceUse: String, Hashable, Sendable {
    /// No voice: it was off, the format is serious, or nothing was answered.
    case none
    case full
    /// Only what Cue offers: the model refused a request carrying words the creator typed, so it was asked again without them.
    case catalogOnly
}
