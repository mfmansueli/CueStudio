//
//  TextToSpeechDraft.swift
//  Cue Studio
//

import Foundation

/// What Text to speech held when its sheet closed by a swipe (owner, canvas 2 R11, 07/11/2026): it comes back the next time the
/// sheet opens for the same thing (a new narration, or the same spoken voice-over's Edit text). Add and Cancel end it.
struct TextToSpeechDraft: Equatable {
    var text: String
    var language: String
    var voiceID: String?
    var speed: Double
    /// The spoken voice-over it was replacing; nil for a new narration.
    var replacingID: UUID?
}
