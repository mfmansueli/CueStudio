//
//  Palette+Page.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// The script page's colors: the AI bar over a selection, text the AI rewrote or is writing, the "Ready to record" switch and the state chips.
    enum Page {
        /// The AI bar over a text selection: a night violet at 97% with a 0.5 pt violet rim.
        static let selectionBar = Color(hex: 0x161434, opacity: 0.97)
        static let selectionBarRim = Color(hex: 0xB4A7FF, opacity: 0.45)
        static let selectionBarShadow = Color.black.opacity(0.5)

        /// Text the AI rewrote and the creator hasn't kept yet: `aiReplacedInk` on `aiReplacedFill`.
        static let aiReplacedInk = Color(hex: 0xE4DEFF)
        static let aiReplacedFill = Color(hex: 0x9D8CFF, opacity: 0.16)

        /// The AI's words arriving on the page (`ArrivingText`): the light each word carries for a moment, and the blinking caret after the
        /// last one. Decorative.
        static let arrivalGlow = Color(hex: 0xC4B8FF)
        static let arrivalCaret = Color(hex: 0xB4A7FF)

        /// "✦ Drafting in your voice" (4.1): a violet pill at 20% with a rim and a glow that breathe (their opacity moves); the words are
        /// `aiTextStrong`.
        static let writingPillFill = Color(hex: 0x9D8CFF, opacity: 0.2)
        static let writingPillRim = Color(hex: 0xB4A7FF)
        static let writingPillGlow = Color(hex: 0x9D8CFF)

        /// "Ready to record" switched on: `successText` on green at 18% (6.7:1 over the page's night), a 0.5 pt green rim.
        static let readyFill = Color(hex: 0x34C759, opacity: 0.18)
        static let readyRim = Color(hex: 0x34C759, opacity: 0.55)
        /// "Ready to record" off, on a page with words: the rim that breathes now and then (`ReadyToggle`), so a draft's creator knows
        /// where to say it's ready, and, under Reduce Motion, a still rim instead. Decorative: the words say what it does.
        static let readyHintLight = Color(hex: 0x7BE495)
        static let readyHintRim = Color(hex: 0x34C759, opacity: 0.4)

        /// "Draft" lit (the script is one): `Scripts.draftText`, the purple of the list's DRAFTS title, on that purple at 15% with a
        /// 0.5 pt rim, the same make as "Ready to record" on (at 18% its label fell to 4.4:1 over a card).
        static let draftFill = Color(hex: 0xC084FC, opacity: 0.15)
        static let draftRim = Color(hex: 0xC084FC, opacity: 0.55)

        // The state chip (READY · DRAFT · RECORDED): ink on a fill, 4.5:1 over every surface.
        static let stateReadyInk = Color(hex: 0x34C759)
        static let stateReadyFill = Color(hex: 0x34C759, opacity: 0.14)
        static let stateDraftInk = Color(hex: 0xE1E4F5, opacity: 0.8)
        static let stateDraftFill = Palette.fill
        static let stateRecordedInk = Color(hex: 0xE1E4F5, opacity: 0.85)
        static let stateRecordedFill = Palette.fill
    }
}
