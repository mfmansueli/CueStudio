//
//  VoiceOption.swift
//  Cue Studio
//

import Foundation

/// One answer on a question: what it is called and what it is for (a line that sounds like it, the creator types it).
nonisolated struct VoiceOption: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    var detail: String?
}
