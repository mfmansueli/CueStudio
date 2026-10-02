//
//  FilterGrade.swift
//  Cue Studio
//

import Foundation

/// The color grade of one filter of the collection, as plain math on a color: sRGB-encoded red,
/// green and blue in, graded ones out. `FilterLUT` samples it into the color cube Core Image draws
/// with, so a filter is one lookup per pixel and its look is defined, tested and tuned here, with
/// nothing borrowed: no third-party LUT, no licence to carry.
///
/// How a color is graded:
/// 1. **Tone.** The brightness follows an S-curve (more or less contrast), a lift of the blacks,
///    and a lower ceiling for the whites (faded, matte looks). The change is added to the three
///    channels alike, so the colors keep their hue and their relation to each other: detail is
///    never flattened by the curve and a face keeps the color it had.
/// 2. **Saturation.** Scaled around the brightness. A boost spares skin tones (`skinProtection`):
///    the colors that sit where skin does, orange to yellow with a moderate chroma, get less of it.
/// 3. **Warmth.** Red up and blue down (or the reverse), half as much on skin.
/// 4. **Split toning.** A tint in the shadows and another in the highlights, with no effect on
///    brightness and none on skin.
/// 5. **Mono.** A weighted mix of the channels in place of 2–4, with an optional tint of the grays.
nonisolated struct FilterGrade: Equatable, Sendable {
    typealias Color = SIMD3<Double>

    /// More (+) or less (−) contrast, −1…1; at most a 60% bend of the tone curve.
    var contrast = 0.0
    /// How much the blacks rise, 0…0.1.
    var lift = 0.0
    /// The brightest white, 0.9…1.
    var ceiling = 1.0
    var saturation = 1.0
    /// How much of a saturation boost skin is spared, 0…1.
    var skinProtection = 0.0
    /// Red up, blue down (+) or the reverse (−), as a gain.
    var warmth = 0.0
    var shadowTint = Color(0, 0, 0)
    var shadowAmount = 0.0
    var highlightTint = Color(0, 0, 0)
    var highlightAmount = 0.0
    /// In place of color: the channels' share of the gray, and a tint added to it (strongest in the
    /// middle tones).
    var monoMix: Color?
    var monoTint = Color(0, 0, 0)

    // MARK: - Grading

    func apply(to color: Color) -> Color {
        let luma = Self.luma(color)
        if let mix = monoMix {
            let gray = tone(mix.x * color.x + mix.y * color.y + mix.z * color.z)
            let tintWeight = 1 - abs(gray - 0.5) * 2
            return Self.clamped(Color(repeating: gray) + monoTint * tintWeight)
        }
        let skin = Self.skinWeight(color)
        let graded = tone(luma)
        var result = color + Color(repeating: graded - luma)
        let scale = saturation > 1 ? 1 + (saturation - 1) * (1 - skinProtection * skin) : saturation
        result = Color(repeating: graded) + (result - Color(repeating: graded)) * scale
        let gain = warmth * (1 - 0.5 * skin)
        result.x *= 1 + gain
        result.z *= 1 - gain
        let brightness = Self.luma(result)
        let spared = 1 - skinProtection * skin
        let shadows = (1 - brightness) * (1 - brightness)
        let highlights = brightness * brightness
        result += Self.chroma(shadowTint) * (shadowAmount * shadows * spared)
        result += Self.chroma(highlightTint) * (highlightAmount * highlights * spared)
        return Self.clamped(result)
    }

    /// The brightness through the S-curve, the lift and the ceiling.
    func tone(_ value: Double) -> Double {
        let curved = value + contrast * 0.6 * (Self.smoothstep(value) - value)
        return lift + curved * (ceiling - lift)
    }

    // MARK: - Pieces

    static func luma(_ color: Color) -> Double {
        0.2126 * color.x + 0.7152 * color.y + 0.0722 * color.z
    }

    /// `tint` without its brightness, so a tint changes color only.
    private static func chroma(_ tint: Color) -> Color {
        tint - Color(repeating: luma(tint))
    }

    static func smoothstep(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }

    private static func clamped(_ color: Color) -> Color {
        color.clamped(lowerBound: Color(repeating: 0), upperBound: Color(repeating: 1))
    }

    /// How much a color looks like skin, 0…1: hue from orange-red to yellow, a moderate chroma and
    /// not too dark, each with soft edges, so a boost fades out rather than cutting off.
    static func skinWeight(_ color: Color) -> Double {
        let (hue, saturation, value) = hsv(color)
        return bump(hue, from: 8, to: 42, fade: 18) * bump(saturation, from: 0.18, to: 0.65, fade: 0.15) * bump(value, from: 0.18, to: 1, fade: 0.1)
    }

    /// 1 between `low` and `high`, easing to 0 over `fade` outside them.
    private static func bump(_ value: Double, from low: Double, to high: Double, fade: Double) -> Double {
        if value >= low, value <= high { return 1 }
        let distance = value < low ? low - value : value - high
        return distance >= fade ? 0 : smoothstep(1 - distance / fade)
    }

    /// Hue in degrees, saturation and value of an sRGB color.
    static func hsv(_ color: Color) -> (hue: Double, saturation: Double, value: Double) {
        let high = max(color.x, color.y, color.z)
        let low = min(color.x, color.y, color.z)
        let range = high - low
        guard range > 0 else { return (0, 0, high) }
        var hue: Double
        if high == color.x {
            hue = (color.y - color.z) / range
        } else if high == color.y {
            hue = 2 + (color.z - color.x) / range
        } else {
            hue = 4 + (color.x - color.y) / range
        }
        hue = (hue * 60).truncatingRemainder(dividingBy: 360)
        return (hue < 0 ? hue + 360 : hue, range / high, high)
    }

    // MARK: - The collection

    /// The grade of a filter of the collection; nil for the first filters and Original.
    static func grade(for filter: VideoFilter) -> FilterGrade? {
        switch filter {
        case .natural:
            // Clean and true to life, with a little polish: a touch more contrast and color.
            return FilterGrade(contrast: 0.22, saturation: 1.10, skinProtection: 0.85)
        case .studio:
            // Talking head under good light: crisp, a little cooler, colors with punch, skin spared.
            return FilterGrade(
                contrast: 0.50, ceiling: 0.99, saturation: 1.22, skinProtection: 0.9, warmth: -0.02,
                shadowTint: Color(0, 0.06, 0.14), shadowAmount: 0.10
            )
        case .soft:
            // Airy and gentle: low contrast, lifted blacks, softer colors, a hint of warmth.
            return FilterGrade(
                contrast: -0.35, lift: 0.05, ceiling: 0.97, saturation: 0.90, skinProtection: 0.5, warmth: 0.02,
                shadowTint: Color(0.10, 0.04, 0.08), shadowAmount: 0.06, highlightTint: Color(0.10, 0.08, 0.02), highlightAmount: 0.05
            )
        case .cinema:
            // Teal in the shadows, warmth in the highlights, firm contrast; skin untouched by either.
            return FilterGrade(
                contrast: 0.45, lift: 0.025, ceiling: 0.96, saturation: 0.92, skinProtection: 1,
                shadowTint: Color(0, 0.30, 0.38), shadowAmount: 0.26, highlightTint: Color(0.45, 0.25, 0), highlightAmount: 0.13
            )
        case .warmEditorial:
            // Golden and matte, like a magazine's interiors: warm light, soft blacks, cream highlights.
            return FilterGrade(
                contrast: 0.28, lift: 0.035, ceiling: 0.975, saturation: 1, skinProtection: 0.85, warmth: 0.055,
                shadowTint: Color(0.22, 0.08, 0), shadowAmount: 0.09, highlightTint: Color(0.40, 0.28, 0.05), highlightAmount: 0.10
            )
        case .retro:
            // Faded film: raised blacks, a lowered white, muted colors, green-teal shadows, yellow highlights.
            return FilterGrade(
                contrast: -0.08, lift: 0.085, ceiling: 0.92, saturation: 0.84, skinProtection: 0.7, warmth: 0.04,
                shadowTint: Color(0, 0.22, 0.26), shadowAmount: 0.18, highlightTint: Color(0.40, 0.30, 0), highlightAmount: 0.12
            )
        case .monoSoft:
            // Black and white, gentle: low contrast, soft blacks, a trace of warmth in the grays.
            return FilterGrade(contrast: -0.10, lift: 0.03, ceiling: 0.985, monoMix: Color(0.30, 0.59, 0.11), monoTint: Color(0.02, 0.012, 0))
        case .monoContrast:
            // Black and white, dramatic: deep blacks, bright whites, skin a little lighter than the sky.
            return FilterGrade(contrast: 0.55, monoMix: Color(0.36, 0.52, 0.12))
        default:
            return nil
        }
    }
}
