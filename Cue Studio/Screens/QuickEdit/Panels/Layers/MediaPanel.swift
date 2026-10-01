//
//  MediaPanel.swift
//  Cue Studio
//

import SwiftUI

/// A photo or video on top of the take, picked: full screen or in a window (its shape and size;
/// on the preview, drag it to move it and pinch to resize it), its place among the others, and in
/// Advanced its own sound (a video's) and keyframes.
struct MediaPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        if let media = viewModel.selectedMedia {
            PanelFrame(viewModel: viewModel, panel: .media) {
                PanelSegmented(
                    label: String(localized: "Layout"), options: MediaLayout.allCases.map { PanelOption($0, $0.label) },
                    selection: media.layout, identifier: "edit.mediaLayout"
                ) { layout in viewModel.updateMedia(media.id) { $0.layout = layout } }
                if media.layout == .window {
                    PanelSegmented(
                        label: String(localized: "Shape"), options: MediaShape.allCases.map { PanelOption($0, $0.label) },
                        selection: media.shape, identifier: "edit.mediaShape"
                    ) { shape in viewModel.updateMedia(media.id) { $0.shape = shape } }
                    PanelSlider(
                        label: String(localized: "Size"), value: media.width * 100,
                        range: MediaOverlay.widthRange.lowerBound * 100...MediaOverlay.widthRange.upperBound * 100,
                        format: .percent, identifier: "edit.mediaSize",
                        onChange: { width in viewModel.updateMedia(media.id) { $0.width = width / 100 } },
                        onEditingChanged: { editing in editing ? viewModel.beginChange() : viewModel.endChange() }
                    )
                }
                if viewModel.edit.media.count > 1 {
                    HStack(spacing: 8) {
                        PanelButton(
                            label: String(localized: "Bring forward"), systemImage: "square.2.layers.3d.top.filled",
                            isEnabled: viewModel.canRestack(media.id, up: true), identifier: "edit.mediaForwardButton"
                        ) { viewModel.restack(media.id, up: true) }
                        PanelButton(
                            label: String(localized: "Send backward"), systemImage: "square.2.layers.3d.bottom.filled",
                            isEnabled: viewModel.canRestack(media.id, up: false), identifier: "edit.mediaBackwardButton"
                        ) { viewModel.restack(media.id, up: false) }
                    }
                }
                PanelAdvancedButton(isOpen: viewModel.showsAdvanced) { viewModel.showsAdvanced.toggle() }
                if viewModel.showsAdvanced {
                    if media.kind == .video, media.hasSound == true {
                        PanelSlider(
                            label: String(localized: "Sound"), value: (media.audioVolume ?? 0) * 100, range: 0...100,
                            format: .percent, identifier: "edit.mediaSound",
                            onChange: { viewModel.setMediaSoundVolume(media.id, $0 / 100) },
                            onEditingChanged: { editing in editing ? viewModel.beginChange() : viewModel.endChange() }
                        )
                    }
                    MotionKeyframeControls(viewModel: viewModel)
                }
            }
        }
    }
}
