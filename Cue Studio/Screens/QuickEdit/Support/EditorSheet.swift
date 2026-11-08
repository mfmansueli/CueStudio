//
//  EditorSheet.swift
//  Cue Studio
//

import Foundation

/// A sheet over the editor.
enum EditorSheet: String, Identifiable {
    /// A sound file from Files, under the voice.
    case music
    /// Cue's sound effects alone (the Audio bar's Sound effects).
    case soundEffects
    /// Text to speech: a voice-over said by a voice on this iPhone.
    case textToSpeech
    /// A photo or video from Photos, on top of the video or as a clip.
    case media
    /// Done's question: "Is it ready to post?".
    case done
    /// Reorder: the clips in play order, to drag.
    case clipOrder
    /// Find and replace in the caption lines.
    case findInCaptions
    /// Captions › My words: the creator's names and terms, for speech recognition.
    case myWords
    /// Auto edit: the steps to pick, then what each did (`QuickEditViewModel+AutoEdit`).
    case autoEdit

    var id: String { rawValue }
}
