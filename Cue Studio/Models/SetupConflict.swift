//
//  SetupConflict.swift
//  Cue Studio
//

import Foundation

/// A field where a recommendation differs from the Creator Setup: "1080p instead of your usual 4K".
nonisolated struct SetupConflict: Hashable, Identifiable, Sendable {
    let field: SetupField
    /// "1080p"
    let recommended: String
    /// "4K"
    let usual: String

    var id: SetupField { field }

    /// "1080p instead of your usual 4K."
    var sentence: String {
        String(localized: "\(recommended) instead of your usual \(usual).")
    }
}
