//
//  StyleCardMenu.swift
//  Cue Studio
//

import SwiftUI

/// A style card's menu (held, or VoiceOver's actions), the same for caption, text and cover styles: favor it, start new work
/// in it, keep a copy as one's own, and for the creator's own styles rename, update with what is on screen, or delete (with
/// Undo in the toast).
struct StyleCardMenu: View {
    let isFavorite: Bool
    let isDefault: Bool
    /// "Use for new videos", "Use for new covers"…
    let defaultLabel: String
    let onFavorite: () -> Void
    let onDefault: () -> Void
    let onDuplicate: () -> Void
    var onRename: (() -> Void)?
    var onUpdate: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        Button(isFavorite ? String(localized: "Remove from favorites") : String(localized: "Add to favorites"),
               systemImage: isFavorite ? "star.slash" : "star", action: onFavorite)
        Button(isDefault ? String(localized: "Stop using as default") : defaultLabel,
               systemImage: isDefault ? "checkmark.circle.badge.xmark" : "checkmark.circle", action: onDefault)
        Button(String(localized: "Save a copy as mine"), systemImage: "plus.square.on.square", action: onDuplicate)
        if let onRename {
            Button(String(localized: "Rename"), systemImage: "pencil", action: onRename)
        }
        if let onUpdate {
            Button(String(localized: "Update with this look"), systemImage: "arrow.triangle.2.circlepath", action: onUpdate)
        }
        if let onDelete {
            Button(String(localized: "Delete"), systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}
