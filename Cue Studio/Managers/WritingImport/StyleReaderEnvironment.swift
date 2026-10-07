//
//  StyleReaderEnvironment.swift
//  Cue Studio
//

import SwiftUI

extension EnvironmentValues {
    /// What reads an import for how it sounds; nil where none was provided (a preview), which reads nothing.
    @Entry var styleReader: (any WritingStyleReading)?
}
