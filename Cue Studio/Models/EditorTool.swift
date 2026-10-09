//
//  EditorTool.swift
//  Cue Studio
//

import Foundation

/// A tool of Quick edit that the editor can open on as it appears (a notification's "Try it"). Opening a tool never runs it: Clean Up
/// listens only once its panel is open, captions are made only from "Generate", nothing is recorded, translated or applied.
nonisolated enum EditorTool: String, Codable, CaseIterable, Hashable, Sendable {
    /// Pauses, filler words and retakes (Pauses panel).
    case cleanUp
    /// Auto captions, to make the lines.
    case autoCaptions
    /// The captions, with the translation's language list.
    case captionTranslation
    /// Studio Voice: voice enhancement and noise reduction.
    case studioVoice
    /// Adjust, on the Skin Smoothing dial.
    case skinSmoothing
    /// The take's background.
    case background
    /// The cover.
    case cover
    /// A photo or video over the take (B-roll).
    case media
    /// A narration recorded over the edit.
    case voiceOver
}
