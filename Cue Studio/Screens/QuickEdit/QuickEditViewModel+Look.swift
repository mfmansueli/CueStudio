//
//  QuickEditViewModel+Look.swift
//  Cue Studio
//

import Foundation

/// Adjust, Filters and Crop. Adjust and Filters change the whole take, or one clip when opened from
/// it (`QuickEditViewModel+ClipLook`); Crop is the take's frame. Each change shows live and is an undo
/// step; a slider's quick moves are one (`EditHistory.coalescingInterval`).
extension QuickEditViewModel {
    /// Adjust's settings, −100…+100 (Sharpness 0…100).
    enum Adjustment: String, CaseIterable, Identifiable {
        case exposure, contrast, warmth, saturation, highlights, shadows, sharpness

        var id: String { rawValue }

        var label: String {
            switch self {
            case .exposure: String(localized: "Exposure")
            case .contrast: String(localized: "Contrast")
            case .warmth: String(localized: "Warmth")
            case .saturation: String(localized: "Saturation")
            case .highlights: String(localized: "Highlights")
            case .shadows: String(localized: "Shadows")
            case .sharpness: String(localized: "Sharpness")
            }
        }

        var isBipolar: Bool { self != .sharpness }
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
        case .saturation: return look.saturation
        case .highlights: return look.highlights
        case .shadows: return look.shadows
        case .sharpness: return look.sharpness
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
            case .saturation: edit.saturation = clamped
            case .highlights: edit.highlights = clamped
            case .shadows: edit.shadows = clamped
            case .sharpness: edit.sharpness = clamped
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

    /// "Auto": a little brighter, punchier, warmer and more colorful, to fine-tune from.
    func autoAdjust() {
        if lookClip != nil {
            updateClipLook { look in
                look.exposure = 10
                look.contrast = 14
                look.warmth = 8
                look.saturation = 10
            }
        } else {
            changeLook { edit in
                edit.exposure = 10
                edit.contrast = 14
                edit.warmth = 8
                edit.saturation = 10
            }
        }
        toast.show(String(localized: "Auto adjusted — fine-tune below"))
    }

    /// Every dial back to where it starts: all zero for the take; for a clip, none set by the clip,
    /// so it plays with the take's.
    func resetAdjustments() {
        if lookClip != nil {
            updateClipLook { $0.removeAdjustment() }
            return
        }
        changeLook { edit in
            for adjustment in Adjustment.allCases {
                switch adjustment {
                case .exposure: edit.exposure = 0
                case .contrast: edit.contrast = 0
                case .warmth: edit.warmth = 0
                case .saturation: edit.saturation = 0
                case .highlights: edit.highlights = 0
                case .shadows: edit.shadows = 0
                case .sharpness: edit.sharpness = 0
                }
            }
        }
    }

    /// Something to reset: a dial off zero for the take, a dial the clip sets for a clip.
    var hasAdjustments: Bool {
        if let clip = lookClip { return clip.look?.overridesAdjustment ?? false }
        return Adjustment.allCases.contains { adjustment($0) != 0 }
    }

    private static func overrideValue(of adjustment: Adjustment, in look: ClipLook) -> Double? {
        switch adjustment {
        case .exposure: look.exposure
        case .contrast: look.contrast
        case .warmth: look.warmth
        case .saturation: look.saturation
        case .highlights: look.highlights
        case .shadows: look.shadows
        case .sharpness: look.sharpness
        }
    }

    private static func setOverride(of adjustment: Adjustment, to value: Double?, in look: inout ClipLook) {
        switch adjustment {
        case .exposure: look.exposure = value
        case .contrast: look.contrast = value
        case .warmth: look.warmth = value
        case .saturation: look.saturation = value
        case .highlights: look.highlights = value
        case .shadows: look.shadows = value
        case .sharpness: look.sharpness = value
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

    /// A filter, at full intensity the first time it's picked.
    func pickFilter(_ filter: VideoFilter) {
        if lookClip != nil {
            let isNew = filter != currentFilter
            updateClipLook { look in
                look.filter = filter
                if isNew { look.filterAmount = 1 }
            }
            return
        }
        var next = snapshot
        next.filter = filter
        var changed = edit
        changed.filter = filter
        if filter != edit.filter { changed.filterAmount = 1 }
        next.look = EditLook(changed)
        commit(next)
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

    func resetCropPosition() {
        changeLook { $0.cropOffset = 0 }
    }
}
