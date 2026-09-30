//
//  ChromaKeyCube.swift
//  Cue Studio
//

import Foundation

/// A chroma key as a color cube for Core Image (`CIColorCube`): every color maps to itself with
/// the key color gone (transparent), a soft edge around it, and the key's tint taken off what
/// stays (spill). Colors are compared by their chroma (Cb, Cr) at the same brightness, so a screen
/// in shadow and in light both go, while near-black stays (dark hair, clothes). Pure, so the math
/// is tested without images.
nonisolated enum ChromaKeyCube {
    /// Points along each side of the cube: 32³ entries, enough for smooth edges.
    static let size = 32

    /// How much of `color` (sRGB, 0 to 1) stays: 0 on the key, 1 far from it.
    static func alpha(red: Double, green: Double, blue: Double, key: ChromaKey) -> Double {
        let distance = chromaDistance(red, green, blue, key)
        // The tolerance reaches up to about half the chroma plane.
        let inner = key.tolerance * 0.5
        let outer = inner + max(0.001, key.softness * 0.3)
        var alpha: Double
        if distance <= inner {
            alpha = 0
        } else if distance >= outer {
            alpha = 1
        } else {
            let share = (distance - inner) / (outer - inner)
            alpha = share * share * (3 - 2 * share)
        }
        // Nearly black has no color to judge: it stays.
        let value = max(red, green, blue)
        return max(alpha, max(0, 1 - value / 0.12))
    }

    /// `color` with the key's tint taken off: the key's strongest channel is brought toward the
    /// strongest of the other two, by `spill`.
    static func despilled(red: Double, green: Double, blue: Double, key: ChromaKey) -> (red: Double, green: Double, blue: Double) {
        var channels = [red, green, blue]
        let keyChannels = [key.red, key.green, key.blue]
        guard let strongest = keyChannels.indices.max(by: { keyChannels[$0] < keyChannels[$1] }) else { return (red, green, blue) }
        let others = channels.indices.filter { $0 != strongest }.map { channels[$0] }
        let limit = others.max() ?? 0
        if channels[strongest] > limit {
            channels[strongest] -= (channels[strongest] - limit) * key.spill
        }
        return (channels[0], channels[1], channels[2])
    }

    /// The cube's data: `size`³ RGBA floats, premultiplied, red changing fastest.
    static func data(for key: ChromaKey) -> Data {
        let size = self.size
        var values = [Float](repeating: 0, count: size * size * size * 4)
        var index = 0
        for blueStep in 0..<size {
            for greenStep in 0..<size {
                for redStep in 0..<size {
                    let red = Double(redStep) / Double(size - 1)
                    let green = Double(greenStep) / Double(size - 1)
                    let blue = Double(blueStep) / Double(size - 1)
                    let alpha = alpha(red: red, green: green, blue: blue, key: key)
                    let kept = despilled(red: red, green: green, blue: blue, key: key)
                    values[index] = Float(kept.red * alpha)
                    values[index + 1] = Float(kept.green * alpha)
                    values[index + 2] = Float(kept.blue * alpha)
                    values[index + 3] = Float(alpha)
                    index += 4
                }
            }
        }
        return values.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    /// Distance between two colors' chroma (Cb, Cr), each brought to full brightness first.
    private static func chromaDistance(_ red: Double, _ green: Double, _ blue: Double, _ key: ChromaKey) -> Double {
        let color = chroma(brightened(red, green, blue)), target = chroma(brightened(key.red, key.green, key.blue))
        return ((color.cb - target.cb) * (color.cb - target.cb) + (color.cr - target.cr) * (color.cr - target.cr)).squareRoot()
    }

    private static func chroma(_ color: (Double, Double, Double)) -> (cb: Double, cr: Double) {
        let (red, green, blue) = color
        return (-0.168_736 * red - 0.331_264 * green + 0.5 * blue, 0.5 * red - 0.418_688 * green - 0.081_312 * blue)
    }

    /// The color scaled so its strongest channel is 1 (black stays black).
    private static func brightened(_ red: Double, _ green: Double, _ blue: Double) -> (Double, Double, Double) {
        let value = max(red, green, blue)
        guard value > 0.000_1 else { return (0, 0, 0) }
        return (red / value, green / value, blue / value)
    }
}
