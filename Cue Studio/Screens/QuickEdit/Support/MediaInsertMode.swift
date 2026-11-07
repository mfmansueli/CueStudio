//
//  MediaInsertMode.swift
//  Cue Studio
//

import Foundation

/// Where "Add photo or video" puts what is picked: at the same time as the video (an overlay: beside it in a split screen, in
/// a window, or over all of it), or in the sequence, adding time.
enum MediaInsertMode: String, CaseIterable, Identifiable {
    /// Its own area of a split screen, beside the main video, which keeps playing.
    case split
    /// A window over the video.
    case window
    /// Over the whole frame (B-roll), the voice going on under it.
    case fullScreen
    /// A clip of its own in the sequence, at the playhead: the video gets longer.
    case sequence

    var id: String { rawValue }

    /// The overlays, in the order the sheet offers them.
    static let overlays: [MediaInsertMode] = [.split, .window, .fullScreen]

    /// The layout an overlay is added with; nil in the sequence.
    var layout: MediaLayout? {
        switch self {
        case .split: .split
        case .window: .window
        case .fullScreen: .fullFrame
        case .sequence: nil
        }
    }

    var isOverlay: Bool { self != .sequence }

    var label: String {
        switch self {
        case .split: String(localized: "Split screen")
        case .window: String(localized: "Window")
        case .fullScreen: String(localized: "Full screen")
        case .sequence: String(localized: "In sequence")
        }
    }

    var systemImage: String {
        switch self {
        case .split: "rectangle.split.1x2"
        case .window: "pip"
        case .fullScreen: "rectangle.fill"
        case .sequence: "film.stack"
        }
    }

    /// What happens with the pick, under the choice.
    var explanation: String {
        switch self {
        // One short line each (owner, canvas 2 F14): more of the gallery in sight.
        case .split: String(localized: "Each in its own area, at the same time as you.")
        case .window: String(localized: "In a window over your video, to move and resize.")
        case .fullScreen: String(localized: "Over your video while your voice goes on.")
        case .sequence: String(localized: "A clip of its own at the playhead · videos only.")
        }
    }

    /// The button that puts the pick in.
    var action: String {
        switch self {
        case .split: String(localized: "Add to split screen")
        case .window, .fullScreen: String(localized: "Add over the video")
        case .sequence: String(localized: "Insert in sequence")
        }
    }

    /// Several can be picked at once, to go one after the other.
    var allowsSeveral: Bool { isOverlay }
}
