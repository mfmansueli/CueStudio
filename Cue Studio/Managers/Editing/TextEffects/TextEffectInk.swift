//
//  TextEffectInk.swift
//  Cue Studio
//

import CoreGraphics

/// A color a text effect paints with, in sRGB (0 to 1) with its opacity: mixed, lightened and darkened as the materials need,
/// then handed to Core Graphics or the GPU.
nonisolated struct TextEffectInk: Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// From "#RRGGBB".
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    static let white = TextEffectInk(red: 1, green: 1, blue: 1)
    static let black = TextEffectInk(red: 0, green: 0, blue: 0)

    /// Part of the way to `other` (0 is itself, 1 is `other`).
    func mixed(with other: TextEffectInk, _ amount: Double) -> TextEffectInk {
        let part = min(max(amount, 0), 1)
        func mix(_ from: Double, _ to: Double) -> Double { from + (to - from) * part }
        return TextEffectInk(red: mix(red, other.red), green: mix(green, other.green), blue: mix(blue, other.blue), alpha: mix(alpha, other.alpha))
    }

    /// Toward white by `amount`, keeping its opacity.
    func lightened(_ amount: Double) -> TextEffectInk {
        var mixed = mixed(with: .white, amount)
        mixed.alpha = alpha
        return mixed
    }

    /// Toward black by `amount`, keeping its opacity.
    func darkened(_ amount: Double) -> TextEffectInk {
        var mixed = mixed(with: .black, amount)
        mixed.alpha = alpha
        return mixed
    }

    func opacity(_ value: Double) -> TextEffectInk {
        var copy = self
        copy.alpha = min(max(value, 0), 1)
        return copy
    }

    /// WCAG's relative luminance.
    var luminance: Double {
        0.2126 * Self.linear(red) + 0.7152 * Self.linear(green) + 0.0722 * Self.linear(blue)
    }

    /// In linear light, premultiplied by its opacity: what the GPU fills with (`TextEffectRenderer`).
    var linearPremultiplied: SIMD4<Float> {
        SIMD4(Float(Self.linear(red) * alpha), Float(Self.linear(green) * alpha), Float(Self.linear(blue) * alpha), Float(alpha))
    }

    /// More vivid: pushed away from its own gray by `amount` (a neon tube's tint).
    func saturated(_ amount: Double) -> TextEffectInk {
        let gray = (red + green + blue) / 3
        func push(_ value: Double) -> Double { min(max(gray + (value - gray) * (1 + amount), 0), 1) }
        return TextEffectInk(red: push(red), green: push(green), blue: push(blue), alpha: alpha)
    }

    var cgColor: CGColor {
        CGColor(colorSpace: TextEffectPainter.colorSpace, components: [red, green, blue, alpha].map { CGFloat($0) })
            ?? CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// An sRGB component in linear light.
    private static func linear(_ value: Double) -> Double {
        value <= 0.040_45 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
}
