//
//  FilterTexture.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// What a filter adds beyond color, drawn after its grade (`FilterGrade`): film grain that changes every frame, a glow
/// around the highlights, darker corners, sharpening, and for a camcorder look a softer picture with colour fringes and
/// faint scan lines. Sizes follow the picture's width (a 1080-wide frame is the reference), so the preview, the export and
/// a thumbnail look alike; the grain of a moment is the same in the preview and the export.
nonisolated struct FilterTexture: Equatable, Sendable {
    /// Grain strength: how far a grain moves a pixel from its value, 0…0.3.
    var grain = 0.0
    /// Grain size at a 1080-wide frame: 1 fine, 2 coarse.
    var grainSize = 1.0
    /// The highlights' glow (bloom), 0…1.
    var glow = 0.0
    /// Darker corners, 0…1.
    var vignette = 0.0
    /// Sharpening of the brightness, 0…1.
    var sharpen = 0.0
    /// A softer picture: the blur's radius at a 1080-wide frame.
    var softness = 0.0
    /// Red and blue shifted apart, in points at a 1080-wide frame.
    var colorFringe = 0.0
    /// Dark scan lines' opacity, 0…0.3.
    var scanlines = 0.0

    /// Grain frames a second: a new pattern this often, as film runs.
    static let grainRate = 24.0

    /// What `filter` adds; nil for the filters that are color alone.
    static func texture(for filter: VideoFilter) -> FilterTexture? {
        switch filter {
        case .warmFilm: FilterTexture(grain: 0.07, grainSize: 1.3, glow: 0.12, vignette: 0.25)
        case .goldenGlow: FilterTexture(grain: 0.02, glow: 0.35, vignette: 0.15)
        case .digicam: FilterTexture(grain: 0.035, grainSize: 0.8, sharpen: 0.45)
        case .vhs: FilterTexture(grain: 0.06, grainSize: 1.6, vignette: 0.2, softness: 1.2, colorFringe: 2.6, scanlines: 0.12)
        case .filmMono: FilterTexture(grain: 0.09, grainSize: 1.4, vignette: 0.3)
        default: nil
        }
    }

    /// `image` with the texture, at the moment `time` (nil: a still, one fixed grain).
    func apply(to image: CIImage, time: TimeInterval?) -> CIImage {
        let extent = image.extent
        guard extent.width > 0, !extent.isInfinite else { return image }
        let unit = extent.width / 1080
        var output = image
        if softness > 0 {
            output = output.clampedToExtent().applyingGaussianBlur(sigma: softness * unit).cropped(to: extent)
        }
        if colorFringe > 0 { output = Self.fringed(output, by: colorFringe * unit) }
        if sharpen > 0 {
            let filter = CIFilter.sharpenLuminance()
            filter.inputImage = output
            filter.sharpness = Float(sharpen)
            filter.radius = Float(1.5 * unit)
            output = filter.outputImage?.cropped(to: extent) ?? output
        }
        if glow > 0 {
            let filter = CIFilter.bloom()
            filter.inputImage = output.clampedToExtent()
            filter.radius = Float(18 * unit)
            filter.intensity = Float(glow)
            output = filter.outputImage?.cropped(to: extent) ?? output
        }
        if scanlines > 0 { output = Self.lined(output, opacity: scanlines, unit: unit) }
        if vignette > 0 {
            let filter = CIFilter.vignetteEffect()
            filter.inputImage = output
            filter.center = CGPoint(x: extent.midX, y: extent.midY)
            filter.radius = Float(hypot(extent.width, extent.height) / 2 * 0.95)
            filter.intensity = Float(vignette)
            filter.falloff = 0.6
            output = filter.outputImage?.cropped(to: extent) ?? output
        }
        if grain > 0 { output = grained(output, unit: unit, time: time) }
        return output
    }

    // MARK: - Pieces

    /// Monochrome grain around mid gray, soft-lit onto the picture (mid gray changes nothing), moved to a new place every
    /// grain frame.
    private func grained(_ image: CIImage, unit: CGFloat, time: TimeInterval?) -> CIImage {
        let extent = image.extent
        guard let noise = CIFilter.randomGenerator().outputImage else { return image }
        let frame = Int(((time ?? 0) * Self.grainRate).rounded())
        // A frame's own spot in the noise: far apart for neighbouring frames, the same for the same moment.
        let spot = CGPoint(x: CGFloat((frame &* 7919) % 2048), y: CGFloat((frame &* 104_729) % 2048))
        let strength = CGFloat(min(max(grain, 0), 0.3)) * 2
        let bias = 0.5 - strength / 2
        let gray = noise.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: strength, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: strength, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: strength, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: bias, y: bias, z: bias, w: 0),
        ])
        let size = max(1, CGFloat(grainSize) * unit)
        let layer = gray
            .transformed(by: CGAffineTransform(translationX: -spot.x, y: -spot.y).scaledBy(x: size, y: size))
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
            .cropped(to: extent)
        return layer.applyingFilter("CISoftLightBlendMode", parameters: [kCIInputBackgroundImageKey: image]).cropped(to: extent)
    }

    /// Red moved one way and blue the other by `shift` points, green in place.
    private static func fringed(_ image: CIImage, by shift: CGFloat) -> CIImage {
        let extent = image.extent
        let clamped = image.clampedToExtent()
        func channel(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, moved dx: CGFloat) -> CIImage {
            clamped.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: red, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: green, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: blue, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            ]).transformed(by: CGAffineTransform(translationX: dx, y: 0))
        }
        let red = channel(1, 0, 0, moved: -shift)
        let green = channel(0, 1, 0, moved: 0)
        let blue = channel(0, 0, 1, moved: shift)
        // Screen puts channels that don't overlap back together exactly (a + b − ab, with ab = 0) and keeps the picture
        // opaque; adding them would add their opacity too.
        let joined = red.applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: green])
            .applyingFilter("CIScreenBlendMode", parameters: [kCIInputBackgroundImageKey: blue])
        return joined.cropped(to: extent)
    }

    /// Thin dark lines across, every 3 points.
    private static func lined(_ image: CIImage, opacity: Double, unit: CGFloat) -> CIImage {
        let extent = image.extent
        let stripes = CIFilter.stripesGenerator()
        stripes.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: CGFloat(opacity))
        stripes.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        stripes.width = Float(max(1, 1.5 * unit))
        stripes.sharpness = 0.6
        guard let lines = stripes.outputImage else { return image }
        let across = lines.transformed(by: CGAffineTransform(rotationAngle: .pi / 2)).cropped(to: extent)
        return across.composited(over: image).cropped(to: extent)
    }
}
