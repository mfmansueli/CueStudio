//
//  ZoomPanel.swift
//  Cue Studio
//

import SwiftUI

/// Zoom (this clip): None, Push in, Pull out or Punch in; picking a move plays the clip's first
/// seconds to show it. Advanced: its intensity (1.3× at most).
struct ZoomPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let clip = viewModel.targetClip
        PanelFrame(viewModel: viewModel, panel: .zoom) {
            PanelTiles(
                options: [
                    PanelOption(SectionZoom?.none, String(localized: "None"), systemImage: "circle.slash", key: "none"),
                    PanelOption(SectionZoom?.some(.pushIn), SectionZoom.pushIn.label, systemImage: "arrow.down.right.and.arrow.up.left", key: "pushIn"),
                    PanelOption(SectionZoom?.some(.pullOut), SectionZoom.pullOut.label, systemImage: "arrow.up.left.and.arrow.down.right", key: "pullOut"),
                    PanelOption(SectionZoom?.some(.punchIn), SectionZoom.punchIn.label, systemImage: "plus.viewfinder", key: "punchIn"),
                ],
                selection: clip?.zoom, identifier: "edit.zoom"
            ) { viewModel.setClipZoom($0) }
            PanelAdvancedButton(isOpen: viewModel.showsAdvanced) { viewModel.showsAdvanced.toggle() }
            if viewModel.showsAdvanced {
                PanelSlider(
                    label: String(localized: "Intensity"), value: (clip?.zoomAmount ?? 0.5) * 100, range: 0...100,
                    format: .percent, identifier: "edit.zoom.intensity"
                ) { viewModel.setZoomIntensity($0) }
            }
        }
    }
}
