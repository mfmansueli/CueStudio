//
//  MicrophoneOption.swift
//  Cue Studio
//

import Foundation

/// An audio input the creator can record with.
nonisolated struct MicrophoneOption: Hashable, Identifiable, Sendable {
    /// The port UID.
    let id: String
    let name: String
    let detail: String
}
