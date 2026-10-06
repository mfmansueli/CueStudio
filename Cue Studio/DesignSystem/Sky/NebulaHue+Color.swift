//
//  NebulaHue+Color.swift
//  Cue Studio
//

import SwiftUI

extension NebulaHue {
    /// The nebula's own colour, solid: its peak opacity comes from the nebula (`StarfieldMath.Nebula.opacity`).
    var color: Color {
        switch self {
        case .violet: Palette.nebulaViolet
        case .blue: Palette.nebulaBlue
        case .magenta: Palette.nebulaMagenta
        case .teal: Palette.nebulaTeal
        }
    }
}
