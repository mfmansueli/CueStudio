//
//  CaptionFormatTab.swift
//  Cue Studio
//

import SwiftUI

/// Caption style › Format: how the lines are cut into what shows at once (`CaptionFormat`), where they sit, how big, how wide
/// and how aligned. What this tab sets stays when another style is picked: a style changes the look, never the layout.
struct CaptionFormatTab: View {
    @Bindable var viewModel: QuickEditViewModel

    private var captions: CaptionsViewModel { viewModel.captions }

    var body: some View {
        if let settings = viewModel.edit.captionCollection {
            PanelSegmented(
                label: String(localized: "Text per caption", comment: "Caption style › Layout: how much each caption shows (One word · Short phrase · Two lines). Portuguese \"Texto por legenda\" (owner)."),
                detail: captions.captionFormat == nil ? String(localized: "as they were made") : nil,
                options: CaptionFormat.allCases.map { PanelOption($0, $0.label) },
                selection: captions.captionFormat, height: 38, identifier: "edit.captionFormat"
            ) { captions.setCaptionFormat($0) }
            if captions.captionFormat == .oneWord, captions.linesWithoutWordTiming > 0 {
                PanelNote(text: String(localized: "\(captions.linesWithoutWordTiming) lines stay as short phrases: their words aren't timed to the voice. Set them in a line's More › Word timing."))
                    .accessibilityIdentifier("edit.captionFormat.untimed")
            }
            PanelSegmented(
                label: String(localized: "Position"),
                options: CaptionPosition.allCases.map { PanelOption($0, $0.label) },
                selection: captions.captionPositionStop, height: 38, identifier: "edit.captionPosition"
            ) { captions.setCaptionPositionStop($0) }
            if viewModel.edit.media.contains(where: { $0.layout == .split }) { seamRow }
            // S · M · L · XL: four words, so a segmented control, like Position above it.
            PanelSegmented(
                label: String(localized: "Size"),
                options: CaptionSize.allCases.map { PanelOption($0, $0.label, key: "\($0.rawValue)") },
                selection: CaptionSize.nearest(to: captions.captionPointSize), height: 38, identifier: "edit.captionSize"
            ) { captions.setCaptionPointSize($0.points) }
            PanelSegmented(
                label: String(localized: "Width"),
                options: CaptionWidth.allCases.map { PanelOption($0, $0.label) },
                selection: settings.width ?? CaptionWidth.nearest(to: settings.spec.widthFraction), height: 38, identifier: "edit.captionWidth"
            ) { captions.setCaptionWidth($0) }
            PanelSegmented(
                label: String(localized: "Alignment"),
                options: LineAlignment.allCases.map { PanelOption($0, $0.label, systemImage: $0.systemImage) },
                selection: settings.spec.alignment, height: 38, identifier: "edit.captionAlignment"
            ) { captions.setCaptionAlignment($0) }
            PanelNote(text: String(localized: "You can also drag the caption in the video. Another style keeps all of this."), teaches: true)
        } else {
            legacyControls
        }
    }

    /// "On the seam": while the split screen shows (one over the other), the captions sit on its seam.
    private var seamRow: some View {
        let isSideBySide = viewModel.overlays.splitLayout.arrangement == .sideBySide
        return PanelToggleRow(
            label: String(localized: "On the seam during the split screen"),
            detail: isSideBySide
                ? String(localized: "Side by side has no seam across: the captions stay where you put them")
                : String(localized: "Everywhere else, where you put them"),
            isOn: viewModel.edit.splitScreen.captionsOnSeam, identifier: "edit.captionsOnSeam"
        ) { captions.setCaptionsOnSeam(!viewModel.edit.splitScreen.captionsOnSeam) }
        .disabled(isSideBySide)
    }

    /// Captions from before the style catalogue: where they sit and how big.
    @ViewBuilder
    private var legacyControls: some View {
        PanelSegmented(
            label: String(localized: "Position"),
            options: CaptionPosition.allCases.map { PanelOption($0, $0.label) },
            selection: captions.captionPositionStop, height: 38, identifier: "edit.captionPosition"
        ) { captions.setCaptionPositionStop($0) }
        PanelSegmented(
            label: String(localized: "Size"),
            options: CaptionSize.allCases.map { PanelOption($0, $0.label, key: "\($0.rawValue)") },
            selection: CaptionSize.nearest(to: captions.captionPointSize), height: 38, identifier: "edit.captionSize"
        ) { captions.setCaptionPointSize($0.points) }
    }
}
