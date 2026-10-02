//
//  DictationState.swift
//  Cue Studio
//

import Foundation

/// Where a dictation is. The words themselves go to whoever started it, as they are heard.
enum DictationState: Equatable {
    case idle
    /// Asking for the microphone, or waiting on the language's speech model (loading, or
    /// downloading it the first time). Nothing is being heard yet.
    case preparing(SpeechPreparation?)
    /// Listening: words arrive as they are said.
    case listening
    /// Stopped by the creator; the recognizer is finalizing the last words. The text is still
    /// changing, so it can't be sent yet.
    case finishing

    var isActive: Bool { self != .idle }
}
