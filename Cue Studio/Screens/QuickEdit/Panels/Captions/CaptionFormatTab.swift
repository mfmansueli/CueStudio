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
                label: String(localized: LocalizedStringResource("captionStyle.format", defaultValue: "Format")),
                detail: captions.captionFormat == nil ? String(localized: "as they were made") : nil,
                options: CaptionFormat.allCases.map { PanelOption($0, $0.label) },
                selection: captions.captionFormat, height: 38, identifier: "edit.captionFormat"
            ) { captions.setCaptionFormat($0) }
            PanelSegmented(
                label: String(localized: "Position"),
                options: CaptionPosition.allCases.map { PanelOption($0, $0.label) },
                selection: captions.captionPositionStop, height: 38, identifier: "edit.captionPosition"
            ) { captions.setCaptionPositionStop($0) }
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
            PanelNote(text: String(localized: "You can also drag the caption in the video. Another style keeps all of this."))
        } else {
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
}
