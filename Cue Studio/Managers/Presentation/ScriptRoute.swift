//
//  ScriptRoute.swift
//  Cue Studio
//

import Foundation

/// A script pushed on the Scripts stack.
struct ScriptRoute: Hashable {
    let scriptID: UUID
    /// New scripts open straight into the editor.
    var startsEditing = false
    /// A script the AI is about to write into the page: it opens empty and the words arrive.
    var writing: ScriptRequest?
}
