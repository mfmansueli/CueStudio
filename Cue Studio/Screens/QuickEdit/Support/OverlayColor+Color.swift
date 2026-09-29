//
//  OverlayColor+Color.swift
//  Cue Studio
//

import SwiftUI

extension OverlayColor {
    /// The swatch shown in the editor: the same color the export draws.
    var color: Color {
        let parts = components
        return Color(red: parts.red, green: parts.green, blue: parts.blue)
    }
}
