//
//  SplitFramingTab.swift
//  Cue Studio
//

import SwiftUI

/// How each content sits in its area: which area (the main video or the support; the picked one is outlined on the preview,
/// where dragging and pinching move and zoom it), Fill or Fit, the zoom, and back to the start. The main video's framing is
/// its recording's: every clip of it shows the same way, apart from how it fills the whole frame.
struct SplitFramingTab: View {
    let viewModel: QuickEditViewModel
    let media: MediaOverlay

    private var overlays: OverlaysViewModel { viewModel.overlays }

    var body: some View {
        let area = overlays.selectedArea
        let framing = overlays.areaFraming(area, of: media.id)
        VStack(alignment: .leading, spacing: 16) {
            PanelSegmented(
                label: String(localized: "Area"), options: SplitArea.allCases.map { PanelOption($0, $0.label) },
                selection: area, accent: true, identifier: "edit.split.area"
            ) { overlays.selectedArea = $0 }
            PanelSegmented(
                options: AreaFit.allCases.map { PanelOption($0, $0.label) }, selection: framing.fit, identifier: "edit.split.fit"
            ) { fit in
                var next = framing
                next.fit = fit
                overlays.setAreaFraming(next, for: area, of: media.id)
            }
            PanelSlider(
                label: String(localized: "Zoom"), value: framing.clampedZoom * 100,
                range: AreaFraming.zoomRange.lowerBound * 100...AreaFraming.zoomRange.upperBound * 100, defaultValue: 100,
                format: .percent, identifier: "edit.split.zoom",
                onChange: { zoom in
                    var next = framing
                    next.zoom = zoom / 100
                    overlays.setAreaFraming(next, for: area, of: media.id)
                },
                onEditingChanged: { editing in editing ? viewModel.beginPanelChange() : viewModel.endPanelChange() }
            )
            PanelButton(
                label: String(localized: "Center and fill"), systemImage: "arrow.counterclockwise",
                isEnabled: framing != AreaFraming(), identifier: "edit.split.resetFraming"
            ) { overlays.setAreaFraming(AreaFraming(), for: area, of: media.id) }
            PanelNote(text: area == .main
                ? String(localized: "Drag and pinch it on the video. Every clip of this recording sits the same way; on the whole frame it stays as it is.")
                : String(localized: "Drag and pinch it on the video."))
        }
    }
}
