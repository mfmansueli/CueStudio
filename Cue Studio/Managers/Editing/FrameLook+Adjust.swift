//
//  FrameLook+Adjust.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// The calibrated reading of the Adjust dials (`LookSettings.version` 2), in the order a colorist
/// would use: exposure, white balance, highlights and shadows, contrast, saturation, vibrance, and
/// sharpness last. How far each dial goes is `LookCalibration`. Contrast and the lift of the
/// highlights are curves drawn in sRGB-encoded values (Core Image works in linear light, where a
/// curve around the middle would be far too strong in the shadows).
nonisolated extension FrameLook {
    static func adjusted(_ look: LookSettings, _ image: CIImage) -> CIImage {
        var output = image
        output = exposure(look.exposure, on: output)
        if look.warmth != 0 {
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = output
            filter.neutral = CIVector(x: 6500, y: 0)
            // Warmer means rendering as if lit by a cooler source.
            filter.targetNeutral = CIVector(x: CGFloat(LookCalibration.warmthKelvin(look.warmth)), y: 0)
            output = filter.outputImage ?? output
        }
        output = whiteBalanceTint(look.tint, on: output)
        output = highlightsAndShadows(highlights: look.highlights, shadows: look.shadows, on: output)
        output = contrast(look.contrast, on: output)
        if look.saturation != 0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = output
            filter.saturation = Float(LookCalibration.saturationScale(look.saturation))
            output = filter.outputImage ?? output
        }
        output = vibrance(look.vibrance, on: output)
        if look.sharpness > 0 {
            let filter = CIFilter.sharpenLuminance()
            filter.inputImage = output
            filter.sharpness = Float(LookCalibration.sharpness(look.sharpness))
            filter.radius = Float(LookCalibration.sharpenRadius(forWidth: output.extent.width))
            output = filter.outputImage ?? output
        }
        return output
    }

    // MARK: - Steps

    private static func exposure(_ value: Double, on image: CIImage) -> CIImage {
        guard value != 0 else { return image }
        let filter = CIFilter.exposureAdjust()
        filter.inputImage = image
        filter.ev = Float(LookCalibration.exposureStops(value))
        return filter.outputImage ?? image
    }

    /// Green to magenta: the green channel's gain, with the others scaled so the brightness holds.
    /// Shared with the first reading of the dials, which never had it.
    static func whiteBalanceTint(_ value: Double, on image: CIImage) -> CIImage {
        guard value != 0 else { return image }
        let green = LookCalibration.tintGreenGain(value)
        let keep = 1 / (1 + 0.7152 * (green - 1))
        let filter = CIFilter.colorMatrix()
        filter.inputImage = image
        filter.rVector = CIVector(x: CGFloat(keep), y: 0, z: 0, w: 0)
        filter.gVector = CIVector(x: 0, y: CGFloat(keep * green), z: 0, w: 0)
        filter.bVector = CIVector(x: 0, y: 0, z: CGFloat(keep), w: 0)
        filter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        return filter.outputImage ?? image
    }

    private static func highlightsAndShadows(highlights: Double, shadows: Double, on image: CIImage) -> CIImage {
        var output = image
        if highlights < 0 || shadows != 0 {
            let filter = CIFilter.highlightShadowAdjust()
            filter.inputImage = output
            filter.highlightAmount = Float(LookCalibration.highlightAmount(highlights))
            filter.shadowAmount = Float(LookCalibration.shadowAmount(shadows))
            output = filter.outputImage ?? output
        }
        let lift = CGFloat(LookCalibration.highlightLift(highlights))
        if lift > 0 {
            output = inSRGB(output) { encoded in
                curve(
                    [CGPoint(x: 0, y: 0), CGPoint(x: 0.25, y: 0.25), CGPoint(x: 0.5, y: 0.5 + lift / 3), CGPoint(x: 0.75, y: 0.75 + lift), CGPoint(x: 1, y: 1)],
                    on: encoded
                )
            }
        }
        return output
    }

    private static func contrast(_ value: Double, on image: CIImage) -> CIImage {
        guard value != 0 else { return image }
        let points = LookCalibration.contrastCurve(strength: LookCalibration.contrastStrength(value))
        return inSRGB(image) { curve(points, on: $0) }
    }

    /// `CIVibrance`: lifts the muted colors and spares skin and the colors already strong.
    /// Shared with the first reading of the dials, which never had it.
    static func vibrance(_ value: Double, on image: CIImage) -> CIImage {
        guard value != 0 else { return image }
        let filter = CIFilter.vibrance()
        filter.inputImage = image
        filter.amount = Float(LookCalibration.vibranceAmount(value))
        return filter.outputImage ?? image
    }

    // MARK: - Curves

    /// A five-point tone curve (`points` left to right).
    static func curve(_ points: [CGPoint], on image: CIImage) -> CIImage {
        guard points.count == 5 else { return image }
        let filter = CIFilter.toneCurve()
        filter.inputImage = image
        filter.point0 = points[0]
        filter.point1 = points[1]
        filter.point2 = points[2]
        filter.point3 = points[3]
        filter.point4 = points[4]
        return filter.outputImage ?? image
    }

    /// `work` on the picture in sRGB-encoded values, back to linear after.
    static func inSRGB(_ image: CIImage, _ work: (CIImage) -> CIImage) -> CIImage {
        let encode = CIFilter.linearToSRGBToneCurve()
        encode.inputImage = image
        guard let encoded = encode.outputImage else { return image }
        let decode = CIFilter.sRGBToneCurveToLinear()
        decode.inputImage = work(encoded)
        return decode.outputImage ?? image
    }
}
