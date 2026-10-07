//
//  Palette+Page.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// The script page's colors: the AI bar over a selection, text the AI rewrote, the state strip and the state chips.
    enum Page {
        /// The AI bar over a text selection: a night violet at 97% with a 0.5 pt violet rim.
        static let selectionBar = Color(hex: 0x161434, opacity: 0.97)
        static let selectionBarRim = Color(hex: 0xB4A7FF, opacity: 0.45)
        static let selectionBarShadow = Color.black.opacity(0.5)

        /// Text the AI rewrote and the creator hasn't kept yet: `aiReplacedInk` on `aiReplacedFill`.
        static let aiReplacedInk = Color(hex: 0xE4DEFF)
        static let aiReplacedFill = Color(hex: 0x9D8CFF, opacity: 0.16)

        /// "✦ Writing in your voice" (4.1): a violet pill at 20% with a rim and a glow that breathe (their opacity moves); the words are
        /// `aiTextStrong`.
        static let writingPillFill = Color(hex: 0x9D8CFF, opacity: 0.2)
        static let writingPillRim = Color(hex: 0xB4A7FF)
        static let writingPillGlow = Color(hex: 0x9D8CFF)

        /// The state strip of the script page: night at 92% over a blur, with a 0.5 pt violet rim.
        static let stripFill = Color(hex: 0x0E101C, opacity: 0.92)
        static let stripRim = Color(hex: 0xB4A7FF, opacity: 0.3)

        // The state chip (READY · DRAFT · RECORDED): ink on a fill, 4.5:1 over every surface.
        static let stateReadyInk = Color(hex: 0x34C759)
        static let stateReadyFill = Color(hex: 0x34C759, opacity: 0.14)
        static let stateDraftInk = Color(hex: 0xE1E4F5, opacity: 0.8)
        static let stateDraftFill = Palette.fill
        static let stateRecordedInk = Color(hex: 0xE1E4F5, opacity: 0.85)
        static let stateRecordedFill = Palette.fill
    }
}
