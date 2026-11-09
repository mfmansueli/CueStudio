//
//  SetupChange.swift
//  Cue Studio
//

import Foundation

/// One line of a platform recommendation: what "Use Recommended" would change against what is on screen now ("Frame 4:5 → 9:16",
/// "Safe zone Custom → Shorts"). `isManual` marks a value the creator chose themselves for this take, so they see they would give it up.
nonisolated struct SetupChange: Hashable, Identifiable, Sendable {
    /// What changes: a field of the setup, or the safe zone drawn over the camera (a prompter setting, not a field).
    enum Item: Hashable, Sendable {
        case field(SetupField)
        case safeZone
    }

    let item: Item
    /// On screen now: "4:5".
    let current: String
    /// What the recommendation sets: "9:16".
    let recommended: String
    /// The creator picked the current value for this take (or, for the safe zone, drew their own Custom one).
    let isManual: Bool

    var id: Item { item }

    /// "Frame", "Frame rate", "Safe zone".
    var title: String {
        switch item {
        case .field(let field): field.label
        case .safeZone: SetupField.safeZones.label
        }
    }

    /// "4:5 → 9:16"
    var values: String {
        String(localized: "\(current) → \(recommended)")
    }
}
