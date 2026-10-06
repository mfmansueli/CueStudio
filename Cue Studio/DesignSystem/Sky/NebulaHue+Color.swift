//
//  NebulaHue+Color.swift
//  Cue Studio
//

import SwiftUI

extension NebulaHue {
    /// The nebula's own colour, solid: its peak opacity comes from the nebula (`StarfieldMath.Nebula.opacity`).
    var color: Color {
        switch self {
        case .violet: Palette.Sky.nebulaViolet
        case .blue: Palette.Sky.nebulaBlue
        case .magenta: Palette.Sky.nebulaMagenta
        case .teal: Palette.Sky.nebulaTeal
        }
    }
}
