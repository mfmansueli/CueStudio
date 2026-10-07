//
//  VoiceTopicEntry.swift
//  Cue Studio
//

import Foundation

/// A topic the creator talks about with the subtopics they kept under it, as the AI is told (`CreatorVoice.topics`).
nonisolated struct VoiceTopicEntry: Hashable, Sendable {
    var topic: VoiceTopicRef
    var subtopics: [String] = []
}
