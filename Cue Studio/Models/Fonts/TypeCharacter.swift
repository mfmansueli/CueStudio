//
//  TypeCharacter.swift
//  Cue Studio
//

import Foundation

/// What kind of face a typeface is, for finding its likeness in another script (`ScriptTypeMap`): Montserrat is geometric,
/// Anton condensed, Bangers comic, Caveat handwritten. A caption style or a text keeps its character in Japanese, Arabic or
/// Thai through the face of that script with the same character, at the same weight.
nonisolated enum TypeCharacter: String, CaseIterable, Codable, Hashable, Sendable {
    /// A plain grotesque sans: Inter, DM Sans, TikTok Sans, Space Grotesk, SF Pro.
    case sans
    /// A sans built on circles: Montserrat, Poppins.
    case geometric
    /// Soft, rounded ends: Rubik, SF Pro Rounded.
    case rounded
    /// Tall, tight and heavy, for impact: Anton.
    case condensed
    /// Wide, loud display: Unbounded, Syne.
    case wide
    /// Comic book and playful: Bangers.
    case comic
    /// A serif, from text to display: DM Serif Display, Instrument Serif, New York.
    case serif
    /// Written by hand: Caveat.
    case handwritten
    /// Every letter as wide: Space Mono, SF Mono.
    case mono
}
