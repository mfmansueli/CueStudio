//
//  LookSettings.swift
//  Cue Studio
//

import Foundation

/// The light, color and filter one stretch of the video is drawn with: the take's own (Adjust and
/// Filters with nothing picked), or the take's with a clip's overrides on top (`ClipLook`). The
/// preview, the export and the cover all draw through `FrameLook` with one of these.
nonisolated struct LookSettings: Hashable, Sendable {
    var exposure: Double = 0
    var contrast: Double = 0
    var warmth: Double = 0
    var saturation: Double = 0
    var highlights: Double = 0
    var shadows: Double = 0
    var sharpness: Double = 0
    var filter: VideoFilter = .original
    var filterAmount: Double = 1

    init() {}

    /// The take's own look.
    init(_ edit: TakeEdit) {
        exposure = edit.exposure
        contrast = edit.contrast
        warmth = edit.warmth
        saturation = edit.saturation
        highlights = edit.highlights
        shadows = edit.shadows
        sharpness = edit.sharpness
        filter = edit.filter
        filterAmount = edit.filterAmount
    }

    /// These settings with what `override` sets on top; whatever it leaves alone is these.
    func overridden(by override: ClipLook?) -> LookSettings {
        guard let override else { return self }
        var result = self
        result.exposure = override.exposure ?? exposure
        result.contrast = override.contrast ?? contrast
        result.warmth = override.warmth ?? warmth
        result.saturation = override.saturation ?? saturation
        result.highlights = override.highlights ?? highlights
        result.shadows = override.shadows ?? shadows
        result.sharpness = override.sharpness ?? sharpness
        result.filter = override.filter ?? filter
        result.filterAmount = override.filterAmount ?? filterAmount
        return result
    }
}
