//
//  TextLookField.swift
//  Cue Studio
//

import Foundation

/// A part of a text's look the creator changed by hand. A preset applied to every text can keep
/// these, so a color picked for one title isn't lost when the rest change.
nonisolated enum TextLookField: String, Codable, CaseIterable, Sendable {
    case font, weight, size, tracking, letterCase, alignment, color, background, shadow, outline, position, glow
}
