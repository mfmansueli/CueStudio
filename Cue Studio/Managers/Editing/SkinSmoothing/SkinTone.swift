//
//  SkinTone.swift
//  Cue Studio
//

import Foundation

/// A face's own skin tone and how noisy its picture is, measured once per detection on what is surely skin: the centre of its color (the chroma of
/// YCbCr, which is much the same across light and dark skin, and its brightness) and how far from it a pixel may be and still be skin. Everything is in
/// sRGB-encoded values, 0 to 1, the scale the filter works on.
nonisolated struct SkinTone: Hashable, Sendable {
    /// The centre of the skin's chroma (blue and red differences, from −0.5 to 0.5) and its brightness.
    var cb: Double
    var cr: Double
    var luma: Double
    /// Closer than this to the centre in chroma is skin for sure; the gate closes over the next `chromaFade`.
    var chromaReach: Double
    /// How much of the fine detail in the skin is noise (the same units as the detail the filter reads).
    var noise: Double

    static let chromaFade = 0.05
}

/// Measures a `SkinTone` on a face's pixels. Pure: it reads bytes, so it is tested with bytes.
nonisolated enum SkinToneAnalyzer {
    /// The fewest surely-skin pixels a measure is worth anything on.
    static let minimumSamples = 60
    /// About how many pixels of a face are looked at.
    private static let sampleBudget = 3_000

    /// The tone of the pixels `core` marks (8-bit weights, one per pixel) in `rgba` (sRGB-encoded 8-bit RGBA, rows from the top, the same size).
    /// nil when there are too few of them to tell.
    static func measure(rgba: [UInt8], core: [UInt8], noise: Double) -> SkinTone? {
        let count = min(core.count, rgba.count / 4)
        // A few thousand pixels say what the skin is like: looking at every eighth of a big face keeps this quick (and the sorting below short).
        let step = max(1, count / sampleBudget)
        var cbs: [Double] = [], crs: [Double] = [], lumas: [Double] = []
        for index in stride(from: 0, to: count, by: step) where core[index] >= 128 {
            let (cb, cr, luma) = chroma(red: Double(rgba[index * 4]) / 255, green: Double(rgba[index * 4 + 1]) / 255, blue: Double(rgba[index * 4 + 2]) / 255)
            cbs.append(cb)
            crs.append(cr)
            lumas.append(luma)
        }
        guard cbs.count >= minimumSamples else { return nil }
        let cb = median(cbs), cr = median(crs), luma = median(lumas)
        // How far the skin spreads from its centre: pores, light and shade, a little redness.
        let spread = median(zip(cbs, crs).map { hypot($0 - cb, $1 - cr) })
        return SkinTone(cb: cb, cr: cr, luma: luma, chromaReach: min(0.12, max(0.05, 2.5 * spread + 0.02)), noise: noise)
    }

    /// How noisy the skin is: the spread of the green channel's difference from the average of its neighbours (a robust estimate, so pores and edges
    /// don't count), on 8-bit green values `green` of a patch `width` pixels wide, in encoded units.
    static func noise(green: [UInt8], width: Int) -> Double {
        guard width >= 5, green.count % width == 0 else { return 0 }
        let height = green.count / width
        guard height >= 5 else { return 0 }
        var residuals: [Double] = []
        residuals.reserveCapacity((width - 2) * (height - 2))
        green.withUnsafeBufferPointer { pixels in
            for row in 1..<(height - 1) {
                let above = (row - 1) * width, here = row * width, below = (row + 1) * width
                for column in 1..<(width - 1) {
                    let ring = Int(pixels[above + column - 1]) + Int(pixels[above + column]) + Int(pixels[above + column + 1])
                        + Int(pixels[here + column - 1]) + Int(pixels[here + column + 1])
                        + Int(pixels[below + column - 1]) + Int(pixels[below + column]) + Int(pixels[below + column + 1])
                    residuals.append(Double(pixels[here + column]) - Double(ring) / 8)
                }
            }
        }
        let middle = median(residuals)
        let deviation = median(residuals.map { abs($0 - middle) })
        // 1.4826 turns a median deviation into a standard deviation; 8/9 undoes what the average of the neighbours takes out.
        return min(0.12, deviation * 1.4826 / 255 * (9.0 / 8).squareRoot())
    }

    /// Chroma (blue difference, red difference) and brightness of an sRGB-encoded color, ITU-R BT.601 as JPEG: the same numbers the filter's matrices use.
    static func chroma(red: Double, green: Double, blue: Double) -> (cb: Double, cr: Double, luma: Double) {
        (
            -0.168_736 * red - 0.331_264 * green + 0.5 * blue,
            0.5 * red - 0.418_688 * green - 0.081_312 * blue,
            0.299 * red + 0.587 * green + 0.114 * blue
        )
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
