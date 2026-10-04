//
//  EditorToolbarItem.swift
//  Cue Studio
//

import Foundation

/// One button of the toolbar: an icon, its label (shown under it, or only to VoiceOver and a long
/// press on the smallest screens) and what it does.
struct EditorToolbarItem: Identifiable, Hashable {
    enum Style: Hashable {
        case normal
        /// Can't do its job right now; still tappable, and a toast says why.
        case dimmed
        /// Deletes something.
        case destructive
        /// Smart (the AI's): violet.
        case smart
    }

    /// Stable, for UI tests: `edit.toolbar.<id>`.
    let id: String
    let label: String
    let systemImage: String
    var style: Style = .normal
    let action: EditorAction

    /// Delete stays at the end of the bar while the other tools scroll.
    var isPinned: Bool { style == .destructive }
}
