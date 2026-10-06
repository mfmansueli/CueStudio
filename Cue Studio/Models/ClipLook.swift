//
//  ClipLook.swift
//  Cue Studio
//

import Foundation

/// What one clip changes of the take's look: a base plus overrides. The take (Adjust, Filters and
/// Background with no clip picked) is the base; a clip with nothing here plays with it, and a value
/// set here replaces the take's for that clip only (`LookSettings.overridden(by:)`). Taking a
/// value away gives the clip the take's again, so a clip never holds a copy of what it doesn't
/// change. Split and Duplicate carry it along (the pieces are copies of the clip), so cutting a
/// clip never changes how it looks.
nonisolated struct ClipLook: Codable, Hashable, Sendable {
    var exposure: Double?
    var contrast: Double?
    var warmth: Double?
    var saturation: Double?
    var highlights: Double?
    var shadows: Double?
    var sharpness: Double?
    var vibrance: Double?
    var tint: Double?
    var skinSmoothing: Double?
    /// The clip's own Auto (what was measured on this clip), and how much of it shows; an amount of
    /// 0 with no correction turns the take's Auto off for this clip.
    var auto: AutoCorrection?
    var autoAmount: Double?
    var filter: VideoFilter?
    /// How much of the filter shows, 0 to 1.
    var filterAmount: Double?
    /// The clip's own background, in place of its recording's (`TakeEdit.backgrounds`).
    var background: BackgroundEffect?

    init() {}

    /// Nothing is overridden: the clip plays with the take's look.
    var isEmpty: Bool { self == ClipLook() }

    /// Adjust changes something on this clip.
    var overridesAdjustment: Bool {
        [exposure, contrast, warmth, saturation, highlights, shadows, sharpness, vibrance, tint, skinSmoothing].contains { $0 != nil }
            || overridesAuto
    }

    /// Auto is set for this clip: measured on it, or turned down or off.
    var overridesAuto: Bool { auto != nil || autoAmount != nil }

    /// A filter is picked for this clip (the "Original" filter is a pick too: no filter here).
    var overridesFilter: Bool { filter != nil }

    /// `nil` when nothing is left to override.
    var normalized: ClipLook? { isEmpty ? nil : self }

    /// Gives the clip the take's Adjust values again.
    mutating func removeAdjustment() {
        exposure = nil
        contrast = nil
        warmth = nil
        saturation = nil
        highlights = nil
        shadows = nil
        sharpness = nil
        vibrance = nil
        tint = nil
        skinSmoothing = nil
        removeAuto()
    }

    /// Gives the clip the take's Auto again.
    mutating func removeAuto() {
        auto = nil
        autoAmount = nil
    }

    /// Gives the clip the take's filter again.
    mutating func removeFilter() {
        filter = nil
        filterAmount = nil
    }
}
