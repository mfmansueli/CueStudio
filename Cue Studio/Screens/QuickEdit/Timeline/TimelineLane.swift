//
//  TimelineLane.swift
//  Cue Studio
//

import Foundation

/// A row of the timeline: the video, and the tracks under it.
nonisolated enum TimelineLane: String, CaseIterable, Hashable, Sendable {
    /// The clips, with their frames and waveform.
    case main
    /// Photos and videos laid over the take (B-roll, windows, the split screen's supports), each with its frames; shown only
    /// when there is one.
    case media
    /// Texts and graphics.
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
        case .media: "photo.on.rectangle"
        case .text: "textformat"
        case .captions: "captions.bubble"
        case .music, .audio: "music.note"
        case .voiceOver: "mic"
        }
    }
}
