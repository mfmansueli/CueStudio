//
//  ScriptPageMode.swift
//  Cue Studio
//

import Foundation

/// The two faces of the script page: **Draft** is free writing, **Shaped** is the same words as
/// sections with cues and timing. Switching never changes the words.
nonisolated enum ScriptPageMode: String, CaseIterable, Identifiable, Sendable {
    case draft, shaped

    var id: String { rawValue }

    var label: String {
        switch self {
        case .draft: String(localized: "Draft")
        case .shaped: String(localized: "Shaped")
        }
    }
}
