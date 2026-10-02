//
//  FrameLook+Filters.swift
//  Cue Studio
//

import CoreImage
import CoreImage.CIFilterBuiltins

/// The filter step: the preset drawn on the adjusted frame, mixed in at the intensity picked. The
/// first filters (Vivid, Warm, Cool, Mono, Film, Fade) are drawn as they always were
/// (`FrameLook+Legacy`); the collection is a graded color cube (`FilterGrade`, `FilterLUT`).
extension FrameLook {
    static func filtered(_ look: LookSettings, _ image: CIImage) -> CIImage {
        guard look.filter != .original else { return image }
        let filtered = applyPreset(look.filter, to: image)
        let amount = min(max(look.filterAmount, 0), 1)
        guard amount < 0.999 else { return filtered }
        let mix = CIFilter.dissolveTransition()
        mix.inputImage = image
        mix.targetImage = filtered
        mix.time = Float(amount)
        return mix.outputImage?.cropped(to: image.extent) ?? filtered
    }

    private static func applyPreset(_ preset: VideoFilter, to image: CIImage) -> CIImage {
        if let legacy = legacyPreset(preset, to: image) { return legacy }
        guard let grade = FilterGrade.grade(for: preset) else { return image }
        return FilterLUT.apply(grade, key: preset.rawValue, to: image)
    }
}
