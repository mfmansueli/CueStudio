//
//  ClipCropPanel.swift
//  Cue Studio
//

import SwiftUI

/// Crop (this clip): Original, Free or a shape (9:16, 4:5, 1:1, 16:9) for the box drawn over the clip's whole picture on the
/// video (`ClipCropLayer`: drag it, pull a corner), Rotate a quarter turn clockwise, and Mirror.
struct ClipCropPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    private var clips: ClipsViewModel { viewModel.clips }

    var body: some View {
        let clip = viewModel.targetClip
        PanelFrame(viewModel: viewModel, panel: .clipCrop) {
            PanelChips(options: shapes, selection: shape(of: clip), identifier: "edit.clipCrop.shape") { pick in
                clips.setClipCropShape(original: pick == "original", ratio: AspectRatio(rawValue: pick), pictureSize: pictureSize)
            }
            HStack(spacing: 8) {
                PanelButton(
                    label: String(localized: "Rotate"), systemImage: "rotate.right", identifier: "edit.clipCrop.rotate"
                ) { clips.rotateClip(recordingSize: recordingSize) }
                // A switch: lit (yellow) while the clip is mirrored, as Mirror on the clip's bar.
                PanelButton(
                    label: String(localized: "Mirror"), systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                    isPrimary: clip?.isMirrored == true, identifier: "edit.clipCrop.mirror", action: clips.toggleClipMirror
                )
                .accessibilityValue(clip?.isMirrored == true ? Text("On") : Text("Off"))
                .accessibilityAddTraits(.isToggle)
            }
            PanelNote(text: String(localized: "Drag the box or pull its corners on the video."))
        }
        .task { await viewModel.overlays.loadRecordingSizes() }
    }

    /// Original, Free, then the shapes; the keys are the ratios' own ("9:16").
    private var shapes: [PanelOption<String>] {
        [
            PanelOption("original", String(localized: "Original"), key: "original"),
            PanelOption("free", String(localized: "Free"), key: "free"),
        ] + AspectRatio.allCases.map { PanelOption($0.rawValue, $0.label, key: $0.rawValue) }
    }

    private func shape(of clip: EditSegment?) -> String {
        guard let crop = clip?.crop else { return "original" }
        return crop.ratio?.rawValue ?? "free"
    }

    /// The clip's recording as filmed, upright, once read.
    private var recordingSize: CGSize? {
        guard let clip = viewModel.targetClip else { return nil }
        return viewModel.overlays.recordingSizes[clip.sourceID]
    }

    /// The clip's picture turned, in which the box is drawn (the take's frame until the recording is read).
    private var pictureSize: CGSize {
        clips.turnedPictureSize(ofRecording: recordingSize ?? CGSize(width: 1000 * viewModel.edit.aspect.widthOverHeight, height: 1000))
    }
}
