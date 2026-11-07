//
//  EditorToolMenu.swift
//  Cue Studio
//

import Foundation

/// A toolbar of its own opened from the main one, or by tapping a track, with nothing selected: Text (add a title, subtitle,
/// hook or callout, or style them all), Audio (music, sound effects, voice-over, then the sound already there) and Media (the
/// ways to add a photo or video, each opening the gallery on it, and Your library) (owner, 28/10/2026). The captions and Blur
/// area tracks open their panel instead, the one their button on the main bar opens (owner, 07/11/2026: one door, one screen).
enum EditorToolMenu: Hashable {
    case text
    case audio
    case media

    var contextLabel: String {
        switch self {
        case .text: String(localized: "Text")
        case .audio: String(localized: "Audio")
        case .media: String(localized: "Media")
        }
    }

    /// The tracks that light up while the menu is open: the audio menu belongs to music,
    /// voice-over and the "add audio" shortcut alike.
    var lanes: Set<TimelineLane> {
        switch self {
        case .text: [.text]
        case .audio: [.music, .voiceOver, .audio]
        case .media: [.media]
        }
    }

    /// The bar tapping a track opens (none for the video track, nor for captions and Blur area, which open their panel).
    init?(lane: TimelineLane) {
        switch lane {
        case .main, .captions, .blur: return nil
        case .media: self = .media
        case .text: self = .text
        case .music, .voiceOver, .audio: self = .audio
        }
    }
}
