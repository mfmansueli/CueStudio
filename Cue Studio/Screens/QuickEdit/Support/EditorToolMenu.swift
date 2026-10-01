//
//  EditorToolMenu.swift
//  Cue Studio
//

import Foundation

/// A toolbar of its own opened from the main one, with nothing selected: Text (add a title,
/// subtitle, hook or callout, or style them all) and Audio (Voice, Music, Voice-over).
enum EditorToolMenu: Hashable {
    case text
    case audio

    var contextLabel: String {
        switch self {
        case .text: String(localized: "Text")
        case .audio: String(localized: "Audio")
        }
    }
}
