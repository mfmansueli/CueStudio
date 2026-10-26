//
//  EditorToolbarContext.swift
//  Cue Studio
//

import Foundation

/// Which tools the toolbar shows, named in code (never by a localized word): the main ones, a menu, or the picked item's kind.
/// Picking another item of the same kind keeps the tools where they were scrolled; another kind starts at its first tool; the
/// main tools come back where they were left (`EditorToolbarScrollMemory`).
enum EditorToolbarContext: Hashable {
    case main
    case menu(EditorToolMenu)
    case clip
    case text
    case caption
    case music
    case voiceOver
    /// A photo or video on top, or a split screen's support.
    case media
    /// The main video's area of a split screen: its own tools, never the support's.
    case mainArea
    case blur
    /// A cut, picked only with its Transition panel open (no tools of its own).
    case transition

    /// A picked item's tools (with "‹ name" and, where something can be deleted, Delete pinned at the end).
    var isItem: Bool {
        switch self {
        case .main, .menu: false
        default: true
        }
    }
}
