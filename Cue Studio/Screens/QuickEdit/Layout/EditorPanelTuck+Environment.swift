//
//  EditorPanelTuck+Environment.swift
//  Cue Studio
//

import SwiftUI

/// Puts a styling panel shown as a sheet (iPhone SE) out of the way so the timeline can be reached in one tap, without ✓
/// (owner, canvas 2 R10 §7.3). Always equal to another: the action never changes what the header draws, so a new one doesn't
/// redraw it.
struct EditorPanelTuck: Equatable {
    let perform: @MainActor () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool { true }
}

extension EnvironmentValues {
    /// Nil where the panel sits in the editor with the timeline above it.
    @Entry var editorPanelTuck: EditorPanelTuck?
}
