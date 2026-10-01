//
//  QuickEditViewModel+Look.swift
//  Cue Studio
//

import Foundation

/// Adjust, Filters and Crop for the whole take. Each change shows live and is an undo step; a
/// slider's quick moves are one (`EditHistory.coalescingInterval`).
extension QuickEditViewModel {
    /// Adjust's sliders, −100…+100 (Sharpness 0…100).
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

        /// In the Advanced section.
        var isAdvanced: Bool { [.saturation, .highlights, .shadows, .sharpness].contains(self) }
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

    func adjustment(_ adjustment: Adjustment) -> Double {
        switch adjustment {
        case .exposure: edit.exposure
        case .contrast: edit.contrast
        case .warmth: edit.warmth
        case .saturation: edit.saturation
        case .highlights: edit.highlights
        case .shadows: edit.shadows
        case .sharpness: edit.sharpness
        }
    }

    func setAdjustment(_ adjustment: Adjustment, _ value: Double) {
        let range: ClosedRange<Double> = adjustment.isBipolar ? TakeEdit.adjustmentRange : 0...100
        let clamped = min(max(value.rounded(), range.lowerBound), range.upperBound)
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

    /// "Auto": a little brighter, punchier, warmer and more colorful, to fine-tune from.
    func autoAdjust() {
        changeLook { edit in
            edit.exposure = 10
            edit.contrast = 14
            edit.warmth = 8
            edit.saturation = 10
        }
        toast.show(String(localized: "Auto adjusted — fine-tune below"))
    }

    func resetAdjustments() {
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

    var hasAdjustments: Bool {
        Adjustment.allCases.contains { adjustment($0) != 0 }
    }

    // MARK: - Filters

    /// A filter, at full intensity the first time it's picked.
    func pickFilter(_ filter: VideoFilter) {
        var next = snapshot
        next.filter = filter
        var changed = edit
        changed.filter = filter
        if filter != edit.filter { changed.filterAmount = 1 }
        next.look = EditLook(changed)
        commit(next)
    }

    func setFilterAmount(_ amount: Double) {
        changeLook(key: "filter.amount") { $0.filterAmount = min(max(amount, 0), 1) }
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
