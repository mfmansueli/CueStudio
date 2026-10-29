//
//  ClipLook.swift
//  Cue Studio
//

import Foundation

/// What one clip changes of the take's look: a base plus overrides. The take (Adjust, Skin, Filters and
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
    /// The clip's own Skin, apart from Adjust: Reset, Copy and Paste and "Use this on all" of one never touch the other.
    var skin: ClipSkin?
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
        [exposure, contrast, warmth, saturation, highlights, shadows, sharpness, vibrance, tint].contains { $0 != nil } || overridesAuto
    }

    /// Skin sets something on this clip (a 0 too: Skin off here while the video has it).
    var overridesSkin: Bool { skin != nil }

    /// Auto is set for this clip: measured on it, or turned down or off.
    var overridesAuto: Bool { auto != nil || autoAmount != nil }

    /// A filter is picked for this clip (the "Original" filter is a pick too: no filter here).
    var overridesFilter: Bool { filter != nil }

    /// `nil` when nothing is left to override.
    var normalized: ClipLook? { isEmpty ? nil : self }

    /// What a clip sets to show none of `take` (the whole video's look) and `background` (its recording's), as filmed: each part
    /// that draws something there is turned off here, and the rest left alone; nil when nothing draws.
    static func asFilmed(over take: LookSettings, background: BackgroundEffect?) -> ClipLook? {
        func off(_ value: Double) -> Double? { value != 0 ? 0 : nil }
        var look = ClipLook()
        look.exposure = off(take.exposure)
        look.contrast = off(take.contrast)
        look.warmth = off(take.warmth)
        look.saturation = off(take.saturation)
        look.highlights = off(take.highlights)
        look.shadows = off(take.shadows)
        look.sharpness = off(take.sharpness)
        look.vibrance = off(take.vibrance)
        look.tint = off(take.tint)
        if take.auto != nil, take.autoAmount > 0 { look.autoAmount = 0 }
        if take.skin.isOn { look.skin = ClipSkin(SkinLook()) }
        if take.filter != .original { look.filter = .original }
        if background?.isActive == true { look.background = BackgroundEffect() }
        return look.normalized
    }

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
        removeAuto()
    }

    /// Gives the clip the whole video's Skin again, every part of it.
    mutating func removeSkin() {
        skin = nil
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

    /// Gives the clip its recording's background again.
    mutating func removeBackground() {
        background = nil
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case exposure, contrast, warmth, saturation, highlights, shadows, sharpness, vibrance, tint, skin, auto, autoAmount, filter, filterAmount
        case background
    }

    private enum LegacyKeys: String, CodingKey {
        /// The first smoothing's dial on a clip, before Skin had a panel of its own: read into `skin`, never written again.
        case skinSmoothing
    }

    /// Clips saved before Skin had a panel of its own have the first smoothing's number, read by the engine it was made with
    /// (0 too: it was the clip's choice).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exposure = try container.decodeIfPresent(Double.self, forKey: .exposure)
        contrast = try container.decodeIfPresent(Double.self, forKey: .contrast)
        warmth = try container.decodeIfPresent(Double.self, forKey: .warmth)
        saturation = try container.decodeIfPresent(Double.self, forKey: .saturation)
        highlights = try container.decodeIfPresent(Double.self, forKey: .highlights)
        shadows = try container.decodeIfPresent(Double.self, forKey: .shadows)
        sharpness = try container.decodeIfPresent(Double.self, forKey: .sharpness)
        vibrance = try container.decodeIfPresent(Double.self, forKey: .vibrance)
        tint = try container.decodeIfPresent(Double.self, forKey: .tint)
        if container.contains(.skin) {
            skin = (try? container.decodeIfPresent(ClipSkin.self, forKey: .skin))?.normalized
        } else if let dial = try? decoder.container(keyedBy: LegacyKeys.self).decodeIfPresent(Double.self, forKey: .skinSmoothing) {
            skin = ClipSkin(smoothing: .firstEngine(dial))
        }
        auto = try container.decodeIfPresent(AutoCorrection.self, forKey: .auto)
        autoAmount = try container.decodeIfPresent(Double.self, forKey: .autoAmount)
        filter = try container.decodeIfPresent(VideoFilter.self, forKey: .filter)
        filterAmount = try container.decodeIfPresent(Double.self, forKey: .filterAmount)
        background = try container.decodeIfPresent(BackgroundEffect.self, forKey: .background)
    }
}
