//
//  EditorPanelTuck+Environment.swift
//  Cue Studio
//

import SwiftUI

extension EnvironmentValues {
    /// Puts a styling panel shown as a sheet (iPhone SE) out of the way so the timeline can be reached in one tap, without ✓
    /// (owner, canvas 2 R10 §7.3); nil where the panel sits in the editor with the timeline above it.
    @Entry var editorPanelTuck: (() -> Void)?
}
