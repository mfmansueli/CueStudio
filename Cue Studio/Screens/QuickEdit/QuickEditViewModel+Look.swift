//
//  QuickEditViewModel+Look.swift
//  Cue Studio
//

import Foundation

/// Adjust, Filters and Crop. Adjust and Filters change the whole take, or one clip when opened from
/// it (`QuickEditViewModel+ClipLook`); Crop is the take's frame. Each change shows live and is an undo
/// step; a slider's quick moves are one (`EditHistory.coalescingInterval`). Auto, the measured
/// correction, is in `QuickEditViewModel+AutoLook`.
extension QuickEditViewModel {
    /// Adjust's settings, −100…+100 (Sharpness and Skin Smoothing 0…100), in the order of the dials.
    enum Adjustment: String, CaseIterable, Identifiable {
        case exposure, contrast, warmth, tint, saturation, vibrance, highlights, shadows, sharpness, skinSmoothing

        var id: String { rawValue }

        var label: String {
            switch self {
            case .exposure: String(localized: "Exposure")
            case .contrast: String(localized: "Contrast")
            case .warmth: String(localized: "Warmth")
            case .tint: String(localized: "Tint")
            case .saturation: String(localized: "Saturation")
            case .vibrance: String(localized: "Vibrance")
            case .highlights: String(localized: "Highlights")
            case .shadows: String(localized: "Shadows")
            case .sharpness: String(localized: "Sharpness")
            case .skinSmoothing: String(localized: "Skin Smoothing")
            }
        }

        /// What VoiceOver adds for the settings that need it.
        var hint: String? {
            switch self {
            case .skinSmoothing: String(localized: "Softens the skin of faces. Eyes, lips, hair and beard stay sharp.")
            default: nil
            }
        }

        var isBipolar: Bool { self != .sharpness && self != .skinSmoothing }
    }

    /// Changes light, color, frame or sound (`EditLook`) as an undo step.
    func changeLook(key: String? = nil, _ update: (inout TakeEdit) -> Void) {
        var changed = edit
        update(&changed)
        var next = snapshot
        next.look = EditLook(changed)
        commit(next, key: key)
    }

    // MARK: - Adjust

    /// The value the dial shows: the clip's (or the take's, where the clip sets none) when Adjust
    /// is changing a clip, else the take's.
    func adjustment(_ adjustment: Adjustment) -> Double {
        let look = effectiveLook
        switch adjustment {
        case .exposure: return look.exposure
        case .contrast: return look.contrast
        case .warmth: return look.warmth
        case .tint: return look.tint
        case .saturation: return look.saturation
        case .vibrance: return look.vibrance
        case .highlights: return look.highlights
        case .shadows: return look.shadows
        case .sharpness: return look.sharpness
        case .skinSmoothing: return look.skinSmoothing
        }
    }

    /// Whether the picked clip sets this dial itself (it shows the take's value otherwise); false
    /// when Adjust changes the whole take.
    func clipOverrides(_ adjustment: Adjustment) -> Bool {
        guard let look = lookClip?.look else { return false }
        return Self.overrideValue(of: adjustment, in: look) != nil
    }

    /// The dial has something to reset: off zero for the take, set by the clip for a clip.
    func canResetAdjustment(_ adjustment: Adjustment) -> Bool {
        lookClip != nil ? clipOverrides(adjustment) : self.adjustment(adjustment) != 0
    }

    func setAdjustment(_ adjustment: Adjustment, _ value: Double) {
        let range: ClosedRange<Double> = adjustment.isBipolar ? TakeEdit.adjustmentRange : 0...100
        let clamped = min(max(value.rounded(), range.lowerBound), range.upperBound)
        if lookClip != nil {
            updateClipLook(key: "adjust.\(adjustment.rawValue)") { Self.setOverride(of: adjustment, to: clamped, in: &$0) }
            return
        }
        changeLook(key: "adjust.\(adjustment.rawValue)") { edit in
            switch adjustment {
            case .exposure: edit.exposure = clamped
            case .contrast: edit.contrast = clamped
            case .warmth: edit.warmth = clamped
            case .tint: edit.tint = clamped
            case .saturation: edit.saturation = clamped
            case .vibrance: edit.vibrance = clamped
            case .highlights: edit.highlights = clamped
            case .shadows: edit.shadows = clamped
            case .sharpness: edit.sharpness = clamped
            case .skinSmoothing: edit.skinSmoothing = clamped
            }
        }
    }

    /// One dial back to where it starts: zero for the take, the take's value for a clip.
    func resetAdjustment(_ adjustment: Adjustment) {
        if lookClip != nil {
            updateClipLook(key: "adjust.\(adjustment.rawValue)") { Self.setOverride(of: adjustment, to: nil, in: &$0) }
        } else {
            setAdjustment(adjustment, 0)
        }
    }

    /// Every dial back to where it starts: all zero for the take; for a clip, none set by the clip,
    /// so it plays with the take's.
    func resetAdjustments() {
        if lookClip != nil {
            updateClipLook { $0.removeAdjustment() }
            return
        }
        changeLook { edit in
            edit.autoCorrection = nil
            edit.autoAmount = 1
            for adjustment in Adjustment.allCases {
                switch adjustment {
                case .exposure: edit.exposure = 0
                case .contrast: edit.contrast = 0
                case .warmth: edit.warmth = 0
                case .tint: edit.tint = 0
                case .saturation: edit.saturation = 0
                case .vibrance: edit.vibrance = 0
                case .highlights: edit.highlights = 0
                case .shadows: edit.shadows = 0
                case .sharpness: edit.sharpness = 0
                case .skinSmoothing: edit.skinSmoothing = 0
                }
            }
        }
    }

    /// Something to reset: a dial off zero for the take, a dial the clip sets for a clip.
    var hasAdjustments: Bool {
        if let clip = lookClip { return clip.look?.overridesAdjustment ?? false }
        return Adjustment.allCases.contains { adjustment($0) != 0 } || edit.autoCorrection != nil
    }

    private static func overrideValue(of adjustment: Adjustment, in look: ClipLook) -> Double? {
        switch adjustment {
        case .exposure: look.exposure
        case .contrast: look.contrast
        case .warmth: look.warmth
        case .tint: look.tint
        case .saturation: look.saturation
        case .vibrance: look.vibrance
        case .highlights: look.highlights
        case .shadows: look.shadows
        case .sharpness: look.sharpness
        case .skinSmoothing: look.skinSmoothing
        }
    }

    private static func setOverride(of adjustment: Adjustment, to value: Double?, in look: inout ClipLook) {
        switch adjustment {
        case .exposure: look.exposure = value
        case .contrast: look.contrast = value
        case .warmth: look.warmth = value
        case .tint: look.tint = value
        case .saturation: look.saturation = value
        case .vibrance: look.vibrance = value
        case .highlights: look.highlights = value
        case .shadows: look.shadows = value
        case .sharpness: look.sharpness = value
        case .skinSmoothing: look.skinSmoothing = value
        }
    }

    // MARK: - Filters

    /// The filter and its intensity Filters shows: the clip's (or the take's, where the clip sets
    /// none) when it is changing a clip, else the take's.
    var currentFilter: VideoFilter { effectiveLook.filter }

    var currentFilterAmount: Double { effectiveLook.filterAmount }

    /// The picked clip sets its own filter or intensity.
    var clipOverridesFilter: Bool {
        guard let look = lookClip?.look else { return false }
        return look.filter != nil || look.filterAmount != nil
    }

    /// A filter, at the intensity it starts with (`VideoFilter.defaultAmount`) the first time it's
    /// picked; picking it again keeps the intensity the creator set.
    func pickFilter(_ filter: VideoFilter) {
        if lookClip != nil {
            let isNew = filter != currentFilter
            updateClipLook { look in
                look.filter = filter
                if isNew { look.filterAmount = filter.defaultAmount }
            }
            return
        }
        var next = snapshot
        next.filter = filter
        var changed = edit
        changed.filter = filter
        if filter != edit.filter { changed.filterAmount = filter.defaultAmount }
        next.look = EditLook(changed)
        commit(next)
    }

    /// Where the Filters thumbnails come from: a frame of the clip in scope, or of the take.
    var filterPreviewSource: (url: URL, time: TimeInterval) {
        if let clip = lookClip, let url = recordingURL(of: clip.sourceID) {
            return (url, clip.sourceStart + min(0.5, clip.span.duration / 2))
        }
        return (videoURL, 0.3)
    }

    func setFilterAmount(_ amount: Double) {
        let clamped = min(max(amount, 0), 1)
        if lookClip != nil {
            updateClipLook(key: "filter.amount") { $0.filterAmount = clamped }
        } else {
            changeLook(key: "filter.amount") { $0.filterAmount = clamped }
        }
    }

    /// The clip plays with the take's filter again.
    func resetClipFilter() {
        updateClipLook { $0.removeFilter() }
    }

    // MARK: - Crop

    func setAspect(_ aspect: AspectRatio) {
        changeLook { edit in
            edit.aspect = aspect
            edit.cropOffset = 0
        }
    }

    func setCropFit(_ fit: CropFit) {
        changeLook { $0.cropFit = fit }
    }
}
