//
//  Palette+Settings.swift
//  Cue Studio
//

import SwiftUI

extension Palette {
    /// Settings: the icon tiles of its rows.
    enum Settings {
        /// The icon tiles of the Settings rows (the others are `record`, `acc`, `success` and `neutralAction`).
        static let iconIndigo = Color(hex: 0x5E4EE0)
        static let iconPurple = Color(hex: 0xBF5AF2)
        /// Cue Pro's tile is a deep gold with a yellow star (09 §11).
        static let iconPro = Color(hex: 0x3A2E00)
        /// The Settings rows that are not a place of their own (Restore, Terms, Acknowledgements, Version).
        static let iconNeutral = Color(hex: 0x6E7496, opacity: 0.35)
        static let iconTeal = Color(hex: 0x30B0C7)
        static let iconBlue = Color(hex: 0x0A84FF)
    }
}
