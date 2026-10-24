//
//  CaptionContrastProbe.swift
//  Cue Studio
//

import UIKit

/// How well a caption's words read on a picture, measured on the drawn pixels the way WCAG reads text on a busy background:
/// the words' color against what is right around each letter once the caption sits on `scene` (the box, a thick outline or
/// a dark halo; a thin outline is part of the letter, so the picture shows through it). A caption drawn over a white or a
/// black picture is the worst a video gives it. Used by the catalogue's tests and by Adjust's warning.
nonisolated enum CaptionContrastProbe {
    /// The line the probe draws: short words, so nothing shrinks.
    static let sample = "Make it real today"
    /// The frame it draws on: small, so a probe takes a few milliseconds.
    private static let frame = CGSize(width: 540, height: 960)

    /// The contrast of `settings`' words (and of the word being said, and of a word marked for emphasis, in their colors)
    /// against the pixels right around the letters, the caption drawn over `scene`.
    struct Reading: Equatable, Sendable {
        var words: Double
        var lit: Double
        var emphasis: Double
    }

    static func reading(_ settings: CaptionSettings, over scene: ColorContrast.RGB) -> Reading? {
        var plain = settings
        plain.motion = nil
        plain.customLook = nil
        guard let drawn = CaptionCollectionRenderer.image(sample, settings: plain, frame: frame),
              let mask = CaptionCollectionRenderer.image(sample, settings: maskSettings(plain), frame: frame),
              let around = surround(drawn: drawn, mask: mask, scene: scene) else { return nil }
        let spec = plain.spec
        func ratio(_ color: ColorContrast.RGB) -> Double { ColorContrast.ratio(color, around) }
        let text = ColorContrast.RGB(red: spec.textColor.red, green: spec.textColor.green, blue: spec.textColor.blue)
        let accent = settings.highlightColor.components
        let litColor: ColorContrast.RGB
        let litOn: ColorContrast.RGB
        if (settings.motion?.spoken ?? (spec.highlightsWithBox ? .box : .color)).boxes {
            // The word said is on its own box: its ink against the box.
            let ink = settings.highlightColor.readableInk.components
            litColor = ColorContrast.RGB(red: ink.red, green: ink.green, blue: ink.blue)
            litOn = ColorContrast.RGB(red: accent.red, green: accent.green, blue: accent.blue)
        } else {
            litColor = ColorContrast.RGB(red: accent.red, green: accent.green, blue: accent.blue)
            litOn = around
        }
        let marked = spec.emphasisColor.components
        return Reading(
            words: ratio(text), lit: ColorContrast.ratio(litColor, litOn),
            emphasis: ratio(ColorContrast.RGB(red: marked.red, green: marked.green, blue: marked.blue))
        )
    }

    /// The same layout with only the letters, white, solid: where the glyphs are.
    private static func maskSettings(_ settings: CaptionSettings) -> CaptionSettings {
        var mask = settings
        var adjustments = settings.adjustments ?? CaptionAdjustments()
        adjustments.textColor = .white
        adjustments.outline = CaptionOutlineWeight.none
        adjustments.shadow = CaptionShadowStyle.none
        adjustments.background = CaptionBackground.none
        mask.adjustments = adjustments
        return mask
    }

    /// The median color of the pixels one to two pixels outside the letters, the caption composited over `scene`.
    private static func surround(drawn: UIImage, mask: UIImage, scene: ColorContrast.RGB) -> ColorContrast.RGB? {
        guard let drawn = drawn.cgImage, let mask = mask.cgImage, drawn.width == mask.width, drawn.height == mask.height else { return nil }
        let width = drawn.width, height = drawn.height
        let picture = pixels(drawn, over: scene, width: width, height: height)
        let letters = pixels(mask, over: nil, width: width, height: height)
        func isLetter(_ x: Int, _ y: Int) -> Bool { letters[(y * width + x) * 4 + 3] > 128 }
        var reds: [Double] = [], greens: [Double] = [], blues: [Double] = []
        for y in 2..<(height - 2) {
            for x in 2..<(width - 2) where letters[(y * width + x) * 4 + 3] == 0 {
                var near = false
                for dy in -2...2 where !near {
                    for dx in -2...2 where isLetter(x + dx, y + dy) {
                        near = true
                        break
                    }
                }
                guard near else { continue }
                let index = (y * width + x) * 4
                reds.append(Double(picture[index]) / 255)
                greens.append(Double(picture[index + 1]) / 255)
                blues.append(Double(picture[index + 2]) / 255)
            }
        }
        guard !reds.isEmpty else { return nil }
        func median(_ values: [Double]) -> Double { values.sorted()[values.count / 2] }
        return ColorContrast.RGB(red: median(reds), green: median(greens), blue: median(blues))
    }

    /// The image's pixels (RGBA, 8 bits), drawn over a solid `scene` (or over nothing).
    private static func pixels(_ image: CGImage, over scene: ColorContrast.RGB?, width: Int, height: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return }
            if let scene {
                context.setFillColor(red: scene.red, green: scene.green, blue: scene.blue, alpha: 1)
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return bytes
    }
}
