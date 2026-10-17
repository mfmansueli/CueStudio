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
    /// A short word on the icon saying it reaches past the picked item ("All": the whole video), so a tool shown with a clip
    /// never looks like the clip's own.
    var scopeBadge: String?
    /// A thin line before it: the start of a group of tools of another reach.
    var startsGroup = false

    /// Delete stays at the end of the bar while the other tools scroll.
    var isPinned: Bool { style == .destructive }
}
