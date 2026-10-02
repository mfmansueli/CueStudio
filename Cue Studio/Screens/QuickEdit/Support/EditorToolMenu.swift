//
//  EditorToolMenu.swift
//  Cue Studio
//

import Foundation

/// A toolbar of its own opened from the main one, or by tapping a track, with nothing selected:
/// Text (add a title, subtitle, hook or callout, or style them all), Captions (add a line, the
/// list, the style; or make them) and Audio (Voice, Music, Voice-over).
enum EditorToolMenu: Hashable {
    case text
    case captions
    case audio

    var contextLabel: String {
        switch self {
        case .text: String(localized: "Text")
        case .captions: String(localized: "Captions")
        case .audio: String(localized: "Audio")
        }
    }

    /// The tracks that light up while the menu is open: the audio menu belongs to music,
    /// voice-over and the "add audio" shortcut alike.
    var lanes: Set<TimelineLane> {
        switch self {
        case .text: [.text]
        case .captions: [.captions]
        case .audio: [.music, .voiceOver, .audio]
        }
    }

    /// What tapping a track on the timeline opens (nothing for the video track).
    init?(lane: TimelineLane) {
        switch lane {
        case .main: return nil
        case .text: self = .text
        case .captions: self = .captions
        case .music, .voiceOver, .audio: self = .audio
        }
    }
}
