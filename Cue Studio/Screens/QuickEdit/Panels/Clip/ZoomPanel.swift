//
//  ZoomPanel.swift
//  Cue Studio
//

import SwiftUI

/// Zoom (this clip): None, Push in, Pull out or Punch in; picking a move plays the clip's first
/// seconds to show it, and "Preview" in the header plays them again. Advanced: its intensity (1.3× at most).
/// Under them, always in reach, the whole video's **Punch in on cuts** switch (`CutZoom`): every other clip a little closer,
/// toward the face when one is clearly in view. While it is on, its Subtle · Medium · Strong and the lines (a clip that keeps its
/// own zoom, a zoom held back by the video's pixels or to keep the head in the frame) come after the clip's own choices, in the
/// scrolling part: in the footer they left the clip's moves 6 pt to show in on an iPhone 17.
struct ZoomPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let clip = viewModel.targetClip
        PanelFrame(viewModel: viewModel, panel: .zoom, play: clip?.zoom == nil ? nil : PanelPlay(action: viewModel.clips.previewZoom)) {
            PanelTiles(
                options: [
                    PanelOption(SectionZoom?.none, String(localized: "None"), systemImage: "circle.slash", key: "none"),
                    PanelOption(SectionZoom?.some(.pushIn), SectionZoom.pushIn.label, systemImage: "plus.magnifyingglass", key: "pushIn"),
                    PanelOption(SectionZoom?.some(.pullOut), SectionZoom.pullOut.label, systemImage: "minus.magnifyingglass", key: "pullOut"),
                    PanelOption(SectionZoom?.some(.punchIn), SectionZoom.punchIn.label, systemImage: "plus.viewfinder", key: "punchIn"),
                ],
                selection: clip?.zoom, identifier: "edit.zoom"
            ) { viewModel.clips.setClipZoom($0) }
            PanelAdvancedButton(
                isOpen: viewModel.showsAdvanced,
                detail: (clip?.zoomAmount ?? EditSegment.defaultZoomAmount) != EditSegment.defaultZoomAmount ? PanelAdvancedButton.changed(1) : nil
            ) { viewModel.showsAdvanced.toggle() }
            if viewModel.showsAdvanced {
                PanelSlider(
                    label: String(localized: "Intensity"), value: (clip?.zoomAmount ?? 0.5) * 100, range: 0...100,
                    format: .percent, identifier: "edit.zoom.intensity"
                ) { viewModel.clips.setZoomIntensity($0) }
            }
            punchInSettings
        } footer: {
            let clips = viewModel.clips
            PanelToggleRow(label: String(localized: "Punch in on cuts"), detail: punchDetail, isOn: clips.punchesInOnCuts, identifier: "edit.zoom.cuts") {
                clips.setPunchesInOnCuts(!clips.punchesInOnCuts)
            }
            .disabled(!clips.canPunchInOnCuts && !clips.punchesInOnCuts)
        }
    }

    /// Punch in on cuts' strength and lines, while it is on.
    @ViewBuilder private var punchInSettings: some View {
        let clips = viewModel.clips
        if let zoom = viewModel.edit.cutZoom {
            VStack(alignment: .leading, spacing: 8) {
                PanelRowLabel(label: String(localized: "Punch in on cuts"))
                PanelSegmented(
                    options: PhraseZoom.Strength.allCases.map { PanelOption($0, $0.label) }, selection: zoom.strength,
                    identifier: "edit.zoom.cutsStrength"
                ) { clips.setCutZoomStrength($0) }
                .accessibilityLabel(Text("Intensity"))
                if let note = viewModel.cutZoomLimitNote {
                    PanelNote(text: note)
                        .accessibilityIdentifier("edit.zoom.cutsLimit")
                }
                if let note = clips.cutZoomClipNote {
                    PanelNote(text: note)
                        .accessibilityIdentifier("edit.zoom.cutsClip")
                }
            }
        }
    }

    private var punchDetail: String {
        let clips = viewModel.clips
        guard clips.canPunchInOnCuts || clips.punchesInOnCuts else { return String(localized: "Needs a cut in the video") }
        guard clips.punchesInOnCuts else { return String(localized: "Every other clip a little closer") }
        return String(
            localized: "\(clips.punchedClipCount) clips closer · toward your face when it’s clear",
            comment: "Under Punch in on cuts, while it is on"
        )
    }
}
