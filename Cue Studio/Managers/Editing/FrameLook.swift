//
//  FrameLook.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// Quick edit's Adjust and Filters as Core Image filters, applied to every frame of the preview and
/// the export.
nonisolated enum FrameLook {
    static func apply(_ edit: TakeEdit, to image: CIImage) -> CIImage {
        var output = image
        if edit.exposure != 0 {
            let filter = CIFilter.exposureAdjust()
            filter.inputImage = output
            filter.ev = Float(edit.exposure / 100 * 1.2)
            output = filter.outputImage ?? output
        }
        if edit.contrast != 0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = output
            filter.contrast = Float(1 + edit.contrast / 220)
            output = filter.outputImage ?? output
        }
        if edit.warmth != 0 {
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = output
            filter.neutral = CIVector(x: 6500, y: 0)
            // Warmer means rendering as if lit by a cooler source.
            filter.targetNeutral = CIVector(x: 6500 + edit.warmth * 25, y: 0)
            output = filter.outputImage ?? output
        }
        return applyPreset(edit.filter, to: output)
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
        }
    }
}
