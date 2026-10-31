//
//  PanelNote.swift
//  Cue Studio
//

import SwiftUI

/// A short note in a panel (only the ones the design has: no fixed help text under controls). A note that teaches (a gesture, where something
/// lives: `teaches`) shows the first `PanelNoteMemory.lessons` times its panel opens and then stays away; a note about a consequence or a state
/// always shows. Set in the interface type (`cueFont`), so it follows the screen's proportion like the rest of the editor's words.
struct PanelNote: View {
    let text: String
    var tint: Color = Palette.ink2
    /// It teaches how to do something, rather than saying what a choice does: it goes once it has been read a few times.
    var teaches = false

    @Environment(PanelNoteMemory.self) private var memory: PanelNoteMemory?
    /// Decided once, when the note comes: it never vanishes while the creator reads it.
    @State private var isShown: Bool?

    var body: some View {
        if isShown ?? shows {
            Text(text)
                .cueFont(.footnote)
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
                .onAppear {
                    guard isShown == nil else { return }
                    isShown = true
                    if teaches { memory?.read(text) }
                }
        }
    }

    private var shows: Bool { !teaches || memory?.teaches(text) ?? true }
}
