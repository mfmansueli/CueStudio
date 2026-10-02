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
    /// "Tap to add music or voice-over" while there is neither music nor a voice-over.
    case audio

    /// The icon in the gutter beside the track's strip (none for the video track).
    var gutterSymbol: String? {
        switch self {
        case .main: nil
        case .text: "textformat"
        case .captions: "captions.bubble"
        case .music, .audio: "music.note"
        case .voiceOver: "mic"
        }
    }
}
