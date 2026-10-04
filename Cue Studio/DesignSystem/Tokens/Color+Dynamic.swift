//
//  Color+Dynamic.swift
//  Cue Studio
//

import SwiftUI
import UIKit

// Nonisolated: UIKit resolves dynamic colors on background threads while rendering text, so the
// provider must not inherit the main actor.
nonisolated extension Color {
    /// `Color(hex: 0xFFD60A)`
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Parses "#RRGGBB" or "RRGGBB". Returns nil for anything else.
    init?(hexString: String) {
        let digits = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(hex: value)
    }

    /// A color with a stronger value for Increase Contrast (Settings › Accessibility › Display & Text
    /// Size). The increased-contrast values are for the text and lines that carry information while
    /// translucent: with the setting on they should be plainly stronger.
    init(normal: Color, increasedContrast: Color) {
        let normalColor = UIColor(normal)
        let highColor = UIColor(increasedContrast)
        self.init(uiColor: UIColor { @Sendable traits in
            traits.accessibilityContrast == .high ? highColor : normalColor
        })
    }
}
