//
//  LookCalibration.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// How far each Adjust dial moves the picture, from a dial's −100…+100 (Sharpness 0…100). Pure
/// numbers, apart from Core Image, so they can be tested and tuned in one place.
///
/// Version 2 of the look (`LookSettings.version`) is gentler near zero, where a dial is a
/// fine-tuning, and stops short at the ends of the dial where the picture breaks: skin turning
/// orange, saturation going plastic, shadows crushed, halos around edges. Zero is always neutral.
/// Edits saved before it (version 1) keep drawing with the first numbers (`FrameLook+Legacy`).
nonisolated enum LookCalibration {
    /// A dial's value as a share of the dial, −1…1 (0…1 for Sharpness), eased near zero: small
    /// moves are small, and the full dial still reaches the full effect.
    static func eased(_ value: Double, exponent: Double = 1.4) -> Double {
        let share = min(max(value / 100, -1), 1)
        return share < 0 ? -pow(-share, exponent) : pow(share, exponent)
    }

    /// Exposure in stops. ±1.2 at the ends, 0.07 at ±10.
    static func exposureStops(_ value: Double) -> Double {
        eased(value) * 1.2
    }

    /// Contrast as the strength of an S-curve around the middle gray (see `contrastCurve`), −1…1.
    static func contrastStrength(_ value: Double) -> Double {
        eased(value, exponent: 1.25)
    }

    /// The five points of the contrast curve, in sRGB-encoded values: the diagonal bent toward a
    /// smoothstep (an S) for more contrast, or the other way for less. Black and white stay put,
    /// and the middle gray's slope changes by at most 30%.
    static func contrastCurve(strength: Double) -> [CGPoint] {
        let blend = strength * 0.6
        return (0...4).map { index in
            let x = Double(index) / 4
            let smooth = x * x * (3 - 2 * x)
            return CGPoint(x: x, y: x + blend * (smooth - x))
        }
    }

    /// Saturation scale: down to gray at −100, up to ×1.7 at +100.
    static func saturationScale(_ value: Double) -> Double {
        let share = eased(value, exponent: 1.2)
        return share < 0 ? 1 + share : 1 + share * 0.7
    }

    /// `CIVibrance` amount: it lifts the muted colors and spares skin and the colors already strong.
    static func vibranceAmount(_ value: Double) -> Double {
        eased(value, exponent: 1.2) * 0.9
    }

    /// The light (kelvin) the picture is taken as lit by, for Warmth: a shift in mireds, which is
    /// how warmth is perceived, up to 35 mireds from daylight (about +1900 K and −1200 K). A higher
    /// number is warmer: `FrameLook` balances that light back to daylight, as a photo editor's
    /// temperature slider does.
    static func warmthKelvin(_ value: Double) -> Double {
        let mired = 1_000_000 / 6500.0 - eased(value, exponent: 1.2) * 35
        return 1_000_000 / mired
    }

    /// Green gain for Tint: magenta at +100, green at −100, ±12%.
    static func tintGreenGain(_ value: Double) -> Double {
        1 - eased(value, exponent: 1.2) * 0.12
    }

    /// `CIHighlightShadowAdjust` highlights for the dial: 1 leaves them, 0.15 at −100.
    static func highlightAmount(_ value: Double) -> Double {
        1 - max(0, -eased(value, exponent: 1.1)) * 0.85
    }

    /// How much the top of the tone curve lifts for a positive Highlights.
    static func highlightLift(_ value: Double) -> Double {
        max(0, eased(value, exponent: 1.1)) * 0.1
    }

    /// `CIHighlightShadowAdjust` shadows for the dial: +0.8 opens them, −0.5 deepens them but
    /// never to black.
    static func shadowAmount(_ value: Double) -> Double {
        let share = eased(value, exponent: 1.2)
        return share < 0 ? share * 0.5 : share * 0.8
    }

    /// Sharpening strength, 0…0.6 (`CISharpenLuminance`).
    static func sharpness(_ value: Double) -> Double {
        pow(min(max(value / 100, 0), 1), 1.3) * 0.6
    }

    /// The radius of the sharpening in pixels for a frame this wide: fine, so edges don't glow,
    /// and growing with the picture so a 4K frame is sharpened as a 1080p one.
    static func sharpenRadius(forWidth width: Double) -> Double {
        0.9 * min(max(width / 1080, 0.75), 2.5)
    }
}
