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
    var vibrance: Double = 0
    var tint: Double = 0
    /// What Auto measured, and how much of it shows (0 to 1); applied first, before the dials.
    var auto: AutoCorrection?
    var autoAmount: Double = 1
    var filter: VideoFilter = .original
    var filterAmount: Double = 1
    /// How the dials are read (`currentVersion`: calibrated, gentle near zero; 1: the first numbers,
    /// kept for edits saved with them so they look the same).
    var version = LookSettings.currentVersion

    static let currentVersion = 2

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
        vibrance = edit.vibrance
        tint = edit.tint
        auto = edit.autoCorrection
        autoAmount = edit.autoAmount
        filter = edit.filter
        filterAmount = edit.filterAmount
        version = edit.lookVersion
    }

    /// Nothing is changed: the frame is drawn as recorded.
    var isNeutral: Bool {
        var neutral = self
        neutral.version = LookSettings.currentVersion
        neutral.filterAmount = 1
        neutral.autoAmount = 1
        return neutral == LookSettings()
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
        result.vibrance = override.vibrance ?? vibrance
        result.tint = override.tint ?? tint
        result.auto = override.auto ?? auto
        result.autoAmount = override.autoAmount ?? autoAmount
        result.filter = override.filter ?? filter
        result.filterAmount = override.filterAmount ?? filterAmount
        return result
    }
}
