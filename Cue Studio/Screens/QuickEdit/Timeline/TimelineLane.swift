//
//  TimelineLane.swift
//  Cue Studio
//

import Foundation

/// A row of the timeline: the video, and the tracks under it.
nonisolated enum TimelineLane: String, CaseIterable, Hashable, Sendable {
    /// The clips, with their frames and waveform.
    case main
    /// Texts and photos or videos laid over the take.
    case text
    case captions
    case music
    case voiceOver
    /// "+ Add audio" while there is neither music nor a voice-over.
    case audio
}
