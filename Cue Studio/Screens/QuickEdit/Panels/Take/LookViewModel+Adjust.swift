//
//  LookViewModel+Adjust.swift
//  Cue Studio
//

import Foundation

/// Adjust, Filters and Crop. Adjust and Filters change the whole take, or one clip when opened from
/// it (`LookViewModel+ClipScope`); Crop is the take's frame. Each change shows live and is an undo
/// step; a slider's quick moves are one (`EditHistory.coalescingInterval`). Auto, the measured
/// correction, is in `LookViewModel+Auto`.
extension LookViewModel {
    /// Adjust's settings, −100…+100 (Sharpness 0…100), in the order of the dials. Skin is a tool of its own (`LookViewModel+Skin`).
    enum Adjustment: String, CaseIterable, Identifiable {
        case exposure, contrast, warmth, tint, saturation, vibrance, highlights, shadows, sharpness

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
            }
        }

        var isBipolar: Bool { self != .sharpness }
    }

    // MARK: - Adjust

    /// The value the dial shows: the clip's (or the take's, where the clip sets none) when Adjust
    /// is changing a clip, else the take's.
    func adjustment(_ adjustment: Adjustment) -> Double {
        Self.value(of: adjustment, in: effectiveLook)
    }

    /// Whether the picked clip sets this dial itself (it shows the take's value otherwise); false
    /// when Adjust changes the whole take.
    func clipOverrides(_ adjustment: Adjustment) -> Bool {
        guard let look = lookClip?.look else { return false }
        return Self.overrideValue(of: adjustment, in: look) != nil
    }

    /// The dial has something to reset: off zero in what the panel shows (on a clip, its own value or the whole video's).
    func canResetAdjustment(_ adjustment: Adjustment) -> Bool {
        self.adjustment(adjustment) != 0
    }

    func setAdjustment(_ adjustment: Adjustment, _ value: Double) {
        let range: ClosedRange<Double> = adjustment.isBipolar ? TakeEdit.adjustmentRange : 0...100
        let clamped = min(max(value.rounded(), range.lowerBound), range.upperBound)
        if lookClip != nil {
            updateClipLook(key: "adjust.\(adjustment.rawValue)") { Self.setOverride(of: adjustment, to: clamped, in: &$0) }
            return
        }
        changeEdit(key: "adjust.\(adjustment.rawValue)") { edit in
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
            }
        }
    }

    /// One dial back to zero, on the take or the clip: a clip showing the take's value gets its own zero, one showing its own
    /// gives it up where the take's is zero too.
    func resetAdjustment(_ adjustment: Adjustment) {
        if lookClip != nil {
            let inherits = Self.value(of: adjustment, in: LookSettings(edit)) == 0
            updateClipLook(key: "adjust.\(adjustment.rawValue)") { Self.setOverride(of: adjustment, to: inherits ? nil : 0, in: &$0) }
        } else {
            setAdjustment(adjustment, 0)
        }
    }

    /// Every dial at zero and no Auto, on the take or the clip: the clip without Adjust whatever the take has (its own zeros where
    /// the take's dials aren't, its Auto off where the take has one). "Use this on all" follows the take again.
    func resetAdjustments() {
        if lookClip != nil {
            let take = LookSettings(edit)
            updateClipLook { look in
                look.removeAdjustment()
                for adjustment in Adjustment.allCases where Self.value(of: adjustment, in: take) != 0 {
                    Self.setOverride(of: adjustment, to: 0, in: &look)
                }
                if take.auto != nil, take.autoAmount > 0 { look.autoAmount = 0 }
            }
            return
        }
        changeEdit { edit in
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
                }
            }
        }
    }

    /// Something to reset: a dial off zero for the take, or Auto; on a clip, a dial off zero or Auto showing, its own or the take's.
    var hasAdjustments: Bool {
        if lookClip != nil { return Adjustment.allCases.contains { adjustment($0) != 0 } || (hasAuto && effectiveLook.autoAmount > 0) }
        return Adjustment.allCases.contains { adjustment($0) != 0 } || edit.autoCorrection != nil
    }

    private static func value(of adjustment: Adjustment, in look: LookSettings) -> Double {
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
        }
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
        }
    }

    // MARK: - Filters

    /// The filter and its intensity Filters shows: the clip's (or the take's, where the clip sets
    /// none) when it is changing a clip, else the take's.
    var currentFilter: VideoFilter { effectiveLook.filter }

    var currentFilterAmount: Double { effectiveLook.filterAmount }

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
    var filterPreviewSource: (url: URL, time: TimeInterval, orientation: ClipOrientation) {
        if let clip = lookClip, let url = recordingURL(of: clip.sourceID) {
            return (url, clip.sourceStart + min(0.5, clip.span.duration / 2), clip.orientation)
        }
        // The take's frame as the clip that plays it shows it.
        let playing = edit.timeline.segments.first { $0.sourceID == nil && $0.sourceStart <= 0.3 && 0.3 < $0.sourceEnd }
        return (videoURL, 0.3, playing?.orientation ?? .identity)
    }

    func setFilterAmount(_ amount: Double) {
        let clamped = min(max(amount, 0), 1)
        if lookClip != nil {
            updateClipLook(key: "filter.amount") { $0.filterAmount = clamped }
        } else {
            changeEdit(key: "filter.amount") { $0.filterAmount = clamped }
        }
    }

    /// Filters' Reset has something to take off: a filter the panel shows (on a clip, its own or the whole video's).
    var hasFilterSettings: Bool {
        currentFilter != .original
    }

    /// Filters' Reset, in one undo step: the whole video without a filter, or the clip without one whatever the whole video has
    /// (Original of its own when the whole video has a filter). "Use this on all" in the whole video's Filters gives it the whole
    /// video's again.
    func resetFilter() {
        if lookClip != nil {
            let videoHasFilter = edit.filter != .original
            updateClipLook { look in
                look.removeFilter()
                if videoHasFilter { look.filter = .original }
            }
            return
        }
        var next = snapshot
        next.filter = .original
        var changed = edit
        changed.filter = .original
        changed.filterAmount = 1
        next.look = EditLook(changed)
        commit(next)
    }

    // MARK: - Crop

    func setAspect(_ aspect: AspectRatio) {
        let take = session.take
        changeEdit { edit in
            edit.aspect = aspect
            edit.cropOffset = 0
            // The captions' safe margins are the new shape's: a 9:16 platform's kept on 4:5 or 1:1 put lines where neither the
            // preview nor the file should (owner, 07/11/2026). The guide picked stays this video's, back when the shape has it.
            edit.captionCollection?.safeMargins = CaptionSafeArea.margins(for: take, aspect: aspect, pick: edit.safeGuide)
        }
    }

    func setCropFit(_ fit: CropFit) {
        changeEdit { $0.cropFit = fit }
    }
}
