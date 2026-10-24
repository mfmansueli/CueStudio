//
//  StyleKey.swift
//  Cue Studio
//

import Foundation

/// A style a creator can favorite or start new work in: one of Cue's (a caption style, a text preset, a cover template, by its
/// saved name) or one of their own saved styles (`SavedStyle`).
nonisolated enum StyleKey: Codable, Hashable, Sendable {
    case builtIn(String)
    case saved(UUID)

    var savedID: UUID? {
        if case .saved(let id) = self { return id }
        return nil
    }

    var builtInName: String? {
        if case .builtIn(let name) = self { return name }
        return nil
    }

    /// Names the card it is drawn on (accessibility identifiers).
    var identifier: String {
        switch self {
        case .builtIn(let name): name
        case .saved(let id): "saved.\(id.uuidString)"
        }
    }
}
