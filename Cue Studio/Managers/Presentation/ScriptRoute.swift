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
}
