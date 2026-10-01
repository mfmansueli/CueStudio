//
//  EditorHeightClass+Environment.swift
//  Cue Studio
//

import SwiftUI

extension EnvironmentValues {
    /// The editor's height class, for the panels that lay out differently on short screens.
    @Entry var editorHeightClass: EditorHeightClass = .regular
}
