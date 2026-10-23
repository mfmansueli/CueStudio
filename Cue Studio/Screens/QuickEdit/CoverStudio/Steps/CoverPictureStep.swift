//
//  CoverPictureStep.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI

/// Picture: a frame of the video (the strip, then one frame at a time) or a photo; zoom (also with two fingers on the cover),
/// and Reset back to filling the cover. A before/after picks which half it works on, and edits its labels.
struct CoverPictureStep: View {
    @Bindable var viewModel: CoverStudioViewModel
    let frameRate: Double

    @State private var photo: PhotosPickerItem?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if viewModel.composition.activeSplit != nil {
                PanelSegmented(
                    options: [PanelOption(false, String(localized: "Before")), PanelOption(true, String(localized: "After"))],
                    selection: viewModel.editsSecondPicture, identifier: "cover.half"
                ) { viewModel.editsSecondPicture = $0 }
            }
            HStack(spacing: 8) {
                let frameTitle = typeSize.isAccessibilitySize ? String(localized: "Video") : String(localized: "Frame from video")
                sourceButton(frameTitle, systemImage: "film", isOn: !viewModel.pictureIsPhoto) {
                    // Back to the frame it showed before the photo.
                    if viewModel.pictureIsPhoto { viewModel.useFrame(atEdited: viewModel.lastFrameTime ?? 0) }
                }
                let isPhoto = viewModel.pictureIsPhoto
                let ink = isPhoto ? Palette.chipOnInk : Palette.ink
                let fill = isPhoto ? Palette.chipOn : Palette.fill
                let height = Metrics.hitTarget
                PhotosPicker(selection: $photo, matching: .images, photoLibrary: .shared()) {
                    // Built here: the picker's label closure isn't on the main actor.
                    Label(String(localized: "Photo"), systemImage: "photo.on.rectangle")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: height)
                        .background(fill, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cover.photo")
            }
            if !viewModel.pictureIsPhoto {
                CoverFrameStrip(
                    edit: viewModel.edit, videoURL: viewModel.videoURL, time: viewModel.pictureEditedTime,
                    onScrub: { time in
                        viewModel.beginGesture()
                        viewModel.useFrame(atEdited: time)
                    },
                    onPick: { time in
                        viewModel.useFrame(atEdited: time)
                        viewModel.endGesture()
                    }
                )
                HStack(spacing: 8) {
                    stepButton("chevron.left", label: Text("One frame back"), id: "cover.frameBack") {
                        viewModel.stepFrame(by: -1, frameRate: frameRate)
                    }
                    Text(timeLabel)
                        .monoFont(.footnote, weight: .semibold)
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity)
                    stepButton("chevron.right", label: Text("One frame forward"), id: "cover.frameForward") {
                        viewModel.stepFrame(by: 1, frameRate: frameRate)
                    }
                }
                // Time runs left to right in every language, like the strip above.
                .environment(\.layoutDirection, .leftToRight)
            }
            PanelSlider(
                label: String(localized: "Zoom"), value: viewModel.framing.zoom * 100,
                range: CoverFraming.zoomRange.lowerBound * 100...CoverFraming.zoomRange.upperBound * 100, step: 5, defaultValue: 100,
                format: .percent, identifier: "cover.zoom",
                onChange: { viewModel.setZoom($0 / 100) },
                onEditingChanged: { editing in if editing { viewModel.beginGesture() } else { viewModel.endGesture() } }
            )
            HStack {
                PanelNote(text: String(localized: "Drag the cover to move the picture, pinch to zoom."))
                Spacer(minLength: 8)
                Button(String(localized: "Reset")) { viewModel.resetFraming() }
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(viewModel.framing.isUntouched ? Palette.ink2 : Palette.accText)
                    .disabled(viewModel.framing.isUntouched)
                    .frame(minHeight: Metrics.hitTarget)
                    .accessibilityIdentifier("cover.resetFraming")
            }
            if let split = viewModel.composition.activeSplit { labels(split) }
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                await viewModel.usePhoto(item)
                photo = nil
            }
        }
    }

    /// Where the frame is, or why there's no time: the after half shows the before's picture until one is picked.
    private var timeLabel: String {
        if viewModel.editsSecondPicture, viewModel.composition.activeSplit?.source == nil {
            return String(localized: "Same picture as Before · pick a frame")
        }
        return viewModel.pictureEditedTime.map { DurationText.editor($0) } ?? String(localized: "Not in the video")
    }

    private func labels(_ split: CoverSplit) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PanelToggleRow(label: String(localized: "Labels"), isOn: split.showsLabels, identifier: "cover.splitLabels") {
                viewModel.setShowsSplitLabels(!split.showsLabels)
            }
            if split.showsLabels {
                HStack(spacing: 8) {
                    labelField(String(localized: "Before"), text: split.beforeLabel, id: "cover.beforeLabel") { viewModel.setSplitLabels(before: $0) }
                    labelField(String(localized: "After"), text: split.afterLabel, id: "cover.afterLabel") { viewModel.setSplitLabels(after: $0) }
                }
            }
        }
    }

    private func labelField(_ prompt: String, text: String, id: String, onChange: @escaping (String) -> Void) -> some View {
        TextField(prompt, text: Binding(get: { text }, set: { onChange(String($0.prefix(18))) }))
            .font(.system(.callout, weight: .semibold))
            .submitLabel(.done)
            .padding(.horizontal, 12)
            .frame(height: Metrics.hitTarget)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
            .accessibilityLabel(Text(prompt))
            .accessibilityIdentifier(id)
    }

    private func sourceButton(_ title: String, systemImage: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { sourceLabel(title, systemImage: systemImage, isOn: isOn) }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? .isSelected : [])
            .accessibilityIdentifier("cover.frameSource")
    }

    private func sourceLabel(_ title: String, systemImage: String, isOn: Bool) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(isOn ? Palette.chipOnInk : Palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
            .background(isOn ? Palette.chipOn : Palette.fill, in: Capsule())
            .contentShape(Capsule())
    }

    private func stepButton(_ symbol: String, label: Text, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.editorGlyph(EditorGlyph.button, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .background(Palette.fill, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}
