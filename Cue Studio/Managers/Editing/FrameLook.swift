//
//  FrameLook.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// Adjust and Filters on a frame, with Core Image: exposure (`CIExposureAdjust`), contrast and
/// saturation (`CIColorControls`), warmth (`CITemperatureAndTint`), highlights and shadows
/// (`CIHighlightShadowAdjust`, with a gentle tone curve to brighten highlights, which it can only
/// darken), sharpness (`CISharpenLuminance`), then the filter mixed in at its intensity. The
/// preview, the export and the cover all go through here, with the look of the stretch they draw:
/// the take's, or the take's with a clip's overrides (`LookSettings`).
nonisolated enum FrameLook {
    /// The take's own look on `image`.
    static func apply(_ edit: TakeEdit, to image: CIImage) -> CIImage {
        apply(LookSettings(edit), to: image)
    }

    static func apply(_ look: LookSettings, to image: CIImage) -> CIImage {
        var output = image
        if look.exposure != 0 {
            let filter = CIFilter.exposureAdjust()
            filter.inputImage = output
            filter.ev = Float(look.exposure / 100 * 1.2)
            output = filter.outputImage ?? output
        }
        if look.contrast != 0 || look.saturation != 0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = output
            filter.contrast = Float(1 + look.contrast / 220)
            filter.saturation = Float(1 + look.saturation / 100)
            output = filter.outputImage ?? output
        }
        if look.warmth != 0 {
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = output
            filter.neutral = CIVector(x: 6500, y: 0)
            // Warmer means rendering as if lit by a cooler source.
            filter.targetNeutral = CIVector(x: 6500 + look.warmth * 25, y: 0)
            output = filter.outputImage ?? output
        }
        output = highlightsAndShadows(highlights: look.highlights, shadows: look.shadows, on: output)
        if look.sharpness > 0 {
            let filter = CIFilter.sharpenLuminance()
            filter.inputImage = output
            filter.sharpness = Float(min(look.sharpness, 100) / 100 * 0.8)
            filter.radius = 1.5
            output = filter.outputImage ?? output
        }
        guard look.filter != .original else { return output }
        let filtered = applyPreset(look.filter, to: output)
        let amount = min(max(look.filterAmount, 0), 1)
        guard amount < 0.999 else { return filtered }
        let mix = CIFilter.dissolveTransition()
        mix.inputImage = output
        mix.targetImage = filtered
        mix.time = Float(amount)
        return mix.outputImage?.cropped(to: output.extent) ?? filtered
    }

    /// −100…+100 each. Negative highlights and both directions of shadows go through
    /// `CIHighlightShadowAdjust`; positive highlights lift the top of a tone curve.
    private static func highlightsAndShadows(highlights: Double, shadows: Double, on image: CIImage) -> CIImage {
        var output = image
        if highlights < 0 || shadows != 0 {
            let filter = CIFilter.highlightShadowAdjust()
            filter.inputImage = output
            filter.highlightAmount = Float(1 + min(0, highlights) / 100)
            filter.shadowAmount = Float(shadows / 100)
            output = filter.outputImage ?? output
        }
        if highlights > 0 {
            let lift = CGFloat(highlights / 100) * 0.12
            let curve = CIFilter.toneCurve()
            curve.inputImage = output
            curve.point0 = CGPoint(x: 0, y: 0)
            curve.point1 = CGPoint(x: 0.25, y: 0.25)
            curve.point2 = CGPoint(x: 0.5, y: 0.5 + lift / 3)
            curve.point3 = CGPoint(x: 0.75, y: 0.75 + lift)
            curve.point4 = CGPoint(x: 1, y: 1)
            output = curve.outputImage ?? output
        }
        return output
    }

    private static func applyPreset(_ preset: VideoFilter, to image: CIImage) -> CIImage {
        switch preset {
        case .original:
            return image
        case .vivid:
            let filter = CIFilter.colorControls()
            filter.inputImage = image
            filter.saturation = 1.45
            filter.contrast = 1.08
            return filter.outputImage ?? image
        case .warm:
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = image
            filter.neutral = CIVector(x: 6500, y: 0)
            filter.targetNeutral = CIVector(x: 8200, y: 10)
            return filter.outputImage ?? image
        case .cool:
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = image
            filter.neutral = CIVector(x: 6500, y: 0)
            filter.targetNeutral = CIVector(x: 5200, y: 0)
            return filter.outputImage ?? image
        case .mono:
            let filter = CIFilter.photoEffectMono()
            filter.inputImage = image
            return filter.outputImage ?? image
        case .film:
            let filter = CIFilter.photoEffectTransfer()
            filter.inputImage = image
            return filter.outputImage ?? image
        case .fade:
            // Lower contrast, a little lift and less color: a washed, airy look.
            let filter = CIFilter.colorControls()
            filter.inputImage = image
            filter.contrast = 0.82
            filter.brightness = 0.05
            filter.saturation = 0.8
            return filter.outputImage ?? image
        }
    }
}
