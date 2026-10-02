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
        [exposure, contrast, warmth, saturation, highlights, shadows, sharpness].contains { $0 != nil }
    }

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
    }

    /// Gives the clip the take's filter again.
    mutating func removeFilter() {
        filter = nil
        filterAmount = nil
    }
}
