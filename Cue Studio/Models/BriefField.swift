//
//  BriefField.swift
//  Cue Studio
//

import Foundation

/// One bullet the creator fills in before generating a script.
nonisolated struct BriefField: Hashable, Identifiable, Sendable {
    let key: String
    let label: String
    /// Shown as placeholder, and used when the field is left empty.
    let example: String

    var id: String { key }
}
