//
//  LayerBar.swift
//  Cue Studio
//

import Foundation

/// A text, photo or video, voice-over or music clip drawn on its track: where it plays in the edit.
struct LayerBar: Identifiable, Equatable {
    let id: UUID
    let kind: LayerKind
    /// Edited seconds.
    let span: TimeSpan
    let title: String
    let isSelected: Bool
    /// Where its keyframes are, in seconds from its start.
    var keyframes: [TimeInterval] = []
    /// Voice-overs keep their length: they only move.
    var canResize: Bool { kind != .voiceOver }
}
