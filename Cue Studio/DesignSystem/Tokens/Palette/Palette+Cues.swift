//
//  Palette+Cues.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// The stage cues on the script page (`[pause]`, `[look at camera]`), drawn as chips: `chipInk` words and symbol on a soft yellow
    /// fill with a 0.5 pt yellow rim. The ink is `accText`, 4.5:1 and more on the fill over every surface the page sits on
    /// (`PaletteContrastTests`).
    enum Cues {
        static let chipFill = Color(hex: 0xFFD60A, opacity: 0.14)
        static let chipRim = Color(hex: 0xFFD60A, opacity: 0.35)
        static let chipInk = Palette.accText
    }
}
