//
//  SkinPreset.swift
//  Cue Studio
//

import Foundation

/// Skin's two starting points: every control set at once, and each still the creator's to move (then the look is Custom).
/// Natural evens the skin and keeps its texture, the way a good light does; Studio is a clearly retouched skin, soft and
/// matte, with the face lit. Neither is ever picked by itself: Skin opens at 0.
nonisolated enum SkinPreset: String, CaseIterable, Identifiable, Sendable {
    case natural, studio

    var id: String { rawValue }

    var label: String {
        switch self {
        case .natural: String(localized: "Natural", comment: "Video editor › Skin: a preset that evens the skin and keeps its texture")
        case .studio: String(localized: "Studio", comment: "Video editor › Skin: a preset with a clearly retouched, matte, lit skin")
        }
    }

    /// The values the preset sets (today's engine).
    var look: SkinLook {
        switch self {
        case .natural:
            SkinLook(smoothing: SkinSmoothing(amount: 40, texture: 60), faceLight: 15, antiShine: 30)
        case .studio:
            SkinLook(smoothing: SkinSmoothing(amount: 75, texture: 35), faceLight: 30, antiShine: 60)
        }
    }
}
