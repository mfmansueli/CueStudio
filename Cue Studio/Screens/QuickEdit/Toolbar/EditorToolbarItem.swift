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
        /// Deletes the picked item: pinned at the end of the bar.
        case destructive
    }

    /// The badge on a tool that reaches past the picked item, so a tool shown with a clip never looks like the clip's own.
    enum ScopeBadge: Hashable {
        /// The whole video.
        case wholeVideo

        /// "All" ("Todos" in Portuguese), drawn in capitals on the icon's corner; VoiceOver says "whole video".
        var label: String { String(localized: "All") }
    }

    /// Stable, for UI tests and for what the toolbar remembers (`edit.toolbar.<id>`); never a localized name.
    let id: String
    let label: String
    let systemImage: String
    var style: Style = .normal
    let action: EditorAction
    /// Whether it reaches past the picked item (`ScopeBadge`).
    var scopeBadge: ScopeBadge?
    /// A thin line before it: the start of a group of tools of another reach.
    var startsGroup = false
    /// A switch (a track bar's Show, Compare): lit while on, and VoiceOver hears it as a switch, on or off. Nil: a button.
    var isOn: Bool?

    /// Delete (of the picked item) stays at the end of the bar while the other tools scroll.
    var isPinned: Bool { style == .destructive }

    /// The same tool starting a group (a thin line before it).
    func startingGroup() -> EditorToolbarItem {
        var item = self
        item.startsGroup = true
        return item
    }

    /// The same tool with the whole video's badge.
    func reachingWholeVideo() -> EditorToolbarItem {
        var item = self
        item.scopeBadge = .wholeVideo
        return item
    }
}
