//
//  MediaInsertMode.swift
//  Cue Studio
//

import Foundation

/// Where a photo or video picked in "Add photo or video" goes.
enum MediaInsertMode: String, CaseIterable, Identifiable {
    /// Over the take, on the text track, for 3 s (a video for its length).
    case overlay
    /// A clip of its own in the video track, after the clip at the playhead.
    case clip

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overlay: String(localized: "On top of video")
        case .clip: String(localized: "Insert as clip")
        }
    }

    /// What happens with the pick, under the choice.
    var explanation: String {
        switch self {
        case .overlay: String(localized: "Plays over your video (B-roll) while your voice keeps going. Move and resize it on the preview.")
        case .clip: String(localized: "Becomes a clip of its own in the sequence, after the clip at the playhead. Videos only.")
        }
    }
}
