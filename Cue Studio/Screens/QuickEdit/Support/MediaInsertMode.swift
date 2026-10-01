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
}
