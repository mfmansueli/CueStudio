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

    /// A color that resolves per appearance.
    init(light: Color, dark: Color) {
        let lightColor = UIColor(light)
        let darkColor = UIColor(dark)
        self.init(uiColor: UIColor { @Sendable traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        })
    }
}
