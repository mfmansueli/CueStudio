//
//  MediaPanel.swift
//  Cue Studio
//

import SwiftUI

/// A photo or video on top of the take, picked (a support of the split screen has its own panel, `SplitScreenPanel`). A video
/// has two tabs (owner, canvas 2 F5, 07/11/2026): Show, full screen or in a window (its shape and size; on the preview, drag
/// it to move it and pinch to resize it), how opaque it is and its place among the others; Part, which part of it plays and
/// for how long (`MediaTrimStrip`). A photo has no part, so it has Show alone, without tabs. Its sound (Volume), motion
/// (Motion) and mask (Mask) stay tools of their own on its toolbar.
struct MediaPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        if let media = viewModel.selectedMedia, media.layout == .split {
            SplitScreenPanel(viewModel: viewModel, media: media)
        } else if let media = viewModel.selectedMedia {
            if Self.hasPart(media) {
                let tab = viewModel.panelTab == .part ? EditorPanelTab.part : .show
                PanelFrame(viewModel: viewModel, panel: .media) {
                    PanelTabs(tabs: EditorPanelTab.media, selection: tab) { viewModel.panelTab = $0 }
                } content: {
                    if tab == .part {
                        MediaTrimStrip(viewModel: viewModel, media: media)
                    } else {
                        show(media)
                    }
                }
            } else {
                PanelFrame(viewModel: viewModel, panel: .media) { show(media) }
            }
        }
    }

    /// A video whose length is known has a part to pick.
    static func hasPart(_ media: MediaOverlay) -> Bool {
        media.kind == .video && media.mediaDuration != nil
    }

    @ViewBuilder
    private func show(_ media: MediaOverlay) -> some View {
        PanelSegmented(
            label: String(localized: "Show as"), options: MediaLayout.offered.map { PanelOption($0, $0.label) },
            selection: media.layout, identifier: "edit.mediaLayout"
        ) { layout in Task { await viewModel.overlays.setMediaLayout(media.id, layout) } }
        if media.layout == .window {
            PanelSegmented(
                label: String(localized: "Window ratio"), options: MediaShape.allCases.map { PanelOption($0, $0.label) },
                selection: media.shape, identifier: "edit.mediaShape"
            ) { shape in viewModel.overlays.updateMedia(media.id) { $0.shape = shape } }
            PanelSlider(
                label: String(localized: "Size"), value: media.width * 100,
                range: MediaOverlay.widthRange.lowerBound * 100...MediaOverlay.widthRange.upperBound * 100,
                format: .percent, identifier: "edit.mediaSize",
                onChange: { width in viewModel.overlays.updateMedia(media.id) { $0.width = width / 100 } },
                onEditingChanged: { editing in editing ? viewModel.beginPanelChange() : viewModel.endPanelChange() }
            )
        }
        PanelSlider(
            label: String(localized: "Opacity"), value: (media.opacity ?? 1) * 100, range: 10...100, format: .percent,
            identifier: "edit.mediaOpacity",
            onChange: { value in viewModel.overlays.updateMedia(media.id) { $0.opacity = value >= 99.5 ? nil : value / 100 } },
            onEditingChanged: { editing in editing ? viewModel.beginPanelChange() : viewModel.endPanelChange() }
        )
        if viewModel.edit.media.count > 1 {
            HStack(spacing: 8) {
                PanelButton(
                    label: String(localized: "Bring forward"), systemImage: "square.2.layers.3d.top.filled",
                    isEnabled: viewModel.overlays.canRestack(media.id, up: true), identifier: "edit.mediaForwardButton"
                ) { viewModel.overlays.restack(media.id, up: true) }
                PanelButton(
                    label: String(localized: "Send backward"), systemImage: "square.2.layers.3d.bottom.filled",
                    isEnabled: viewModel.overlays.canRestack(media.id, up: false), identifier: "edit.mediaBackwardButton"
                ) { viewModel.overlays.restack(media.id, up: false) }
            }
        }
    }
}
