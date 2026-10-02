//
//  ColorContrast.swift
//  Cue Studio
//

import Foundation

/// Contrast between two colors, the way Apple's accessibility guidelines and WCAG 2 measure it
/// (relative luminance, sRGB). Pure, so the palette is checked against it in tests: the light
/// appearance can't ship with a yellow that disappears on white.
///
/// The minimums are the Human Interface Guidelines': 4.5:1 for text, 3:1 for large text (about
/// 18 pt, or 14 pt bold) and for the parts of a control that say what it is (an icon, an outline).
nonisolated enum ColorContrast {
    static let textMinimum = 4.5
    static let largeTextMinimum = 3.0
    static let componentMinimum = 3.0

    /// A color in sRGB, each channel 0…1.
    struct RGB: Equatable, Sendable {
        var red: Double
        var green: Double
        var blue: Double

        init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        /// `RGB(hex: 0xFFD60A)`
        init(hex: UInt32) {
            self.init(
                red: Double((hex >> 16) & 0xFF) / 255,
                green: Double((hex >> 8) & 0xFF) / 255,
                blue: Double(hex & 0xFF) / 255
            )
        }
    }

    /// How bright the color looks to the eye, 0 (black) to 1 (white).
    static func luminance(_ color: RGB) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
    }

    /// 1 (the same color) to 21 (black on white).
    static func ratio(_ first: RGB, _ second: RGB) -> Double {
        let a = luminance(first)
        let b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// What `foreground` at `alpha` looks like over `background`: translucent text has to be
    /// measured as the color it ends up being.
    static func composite(_ foreground: RGB, alpha: Double, over background: RGB) -> RGB {
        let a = min(max(alpha, 0), 1)
        return RGB(
            red: foreground.red * a + background.red * (1 - a),
            green: foreground.green * a + background.green * (1 - a),
            blue: foreground.blue * a + background.blue * (1 - a)
        )
    }
}
