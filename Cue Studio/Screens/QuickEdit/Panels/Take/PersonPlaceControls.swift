//
//  PersonPlaceControls.swift
//  Cue Studio
//

import SwiftUI

/// Where the cut-out creator stands over a new background, in Background and in the panel of a photo or video shown Behind you:
/// Size (one undo step a slide), how to move them (drag on the preview, pinch to resize, `PersonPlaceLayer`), and back to where they
/// were recorded.
struct PersonPlaceControls: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let look = viewModel.look
        let placement = look.personPlacement
        VStack(alignment: .leading, spacing: 10) {
            PanelRowLabel(
                label: String(localized: "Where you are"),
                detail: placement.isAsRecorded ? String(localized: "As recorded") : String(localized: "Moved")
            )
            .accessibilityAddTraits(.isHeader)
            PanelSlider(
                label: String(localized: "Your size"), value: placement.scale * 100,
                range: PersonPlacement.scaleRange.lowerBound * 100...PersonPlacement.scaleRange.upperBound * 100, defaultValue: 100,
                format: .percent,
                identifier: "edit.personSize",
                onChange: { value in
                    var next = look.personPlacement
                    next.scale = value / 100
                    look.setPersonPlacement(next)
                },
                onEditingChanged: { editing in editing ? viewModel.beginPanelChange() : viewModel.endPanelChange() }
            )
            PanelNote(text: String(localized: "Drag yourself on the preview to move. Pinch to resize."), teaches: true)
            PanelButton(
                label: String(localized: "Back where you were recorded"), systemImage: "arrow.uturn.backward", isCompact: true,
                isEnabled: !placement.isAsRecorded, identifier: "edit.personReset"
            ) { look.resetPersonPlacement() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.personPlace")
    }
}
