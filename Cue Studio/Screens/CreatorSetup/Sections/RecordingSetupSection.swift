//
//  RecordingSetupSection.swift
//  Cue Studio
//

import SwiftUI

/// Creator Setup › Recording: camera, microphone, quality and format every recording starts from.
struct RecordingSetupSection: View {
    let viewModel: CreatorSetupViewModel
    let onPickMicrophone: () -> Void

    var body: some View {
        GroupedCard {
            SetupRow(title: String(localized: "Camera"), detail: String(localized: "Where every recording starts. Flip it anytime while recording.")) {
                HStack(spacing: 8) {
                    chip(String(localized: "Front"), isSelected: viewModel.usesFrontCamera, identifier: "creatorSetup.camera.front") {
                        viewModel.setFrontCamera(true)
                    }
                    chip(String(localized: "Back"), isSelected: !viewModel.usesFrontCamera, identifier: "creatorSetup.camera.back") {
                        viewModel.setFrontCamera(false)
                    }
                }
            }
            microphoneRow
            SetupRow(title: String(localized: "Recording quality"), detail: String(localized: "A platform can recommend another for a video — you choose.")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(VideoResolution.allCases) { resolution in
                            chip(
                                resolution.label, isSelected: viewModel.setup.resolution == resolution,
                                identifier: "creatorSetup.quality.\(resolution.rawValue)"
                            ) {
                                viewModel.setResolution(resolution)
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(FrameRate.allCases) { frameRate in
                            chip(String(localized: "\(frameRate.rawValue) fps"), isSelected: viewModel.setup.frameRate == frameRate, identifier: "creatorSetup.frameRate.\(frameRate.rawValue)") {
                                viewModel.setFrameRate(frameRate)
                            }
                        }
                    }
                }
            }
            SetupRow(title: String(localized: "Default format"), detail: String(localized: "Framing, safe zones, editing and export follow it.")) {
                HStack(spacing: 8) {
                    ForEach(AspectRatio.allCases) { aspect in
                        formatTile(aspect)
                    }
                }
            }
        }
    }

    private var microphoneRow: some View {
        Button(action: onPickMicrophone) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Microphone").foregroundStyle(Palette.ink)
                    Text(viewModel.microphoneDetail)
                        .font(.footnote)
                        .foregroundStyle(viewModel.isPreferredMicrophoneMissing ? Palette.warnText : Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text(viewModel.setup.microphone.label)
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink3)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("creatorSetup.microphoneButton")
    }

    private func formatTile(_ aspect: AspectRatio) -> some View {
        let isSelected = viewModel.setup.aspect == aspect
        return Button {
            viewModel.setAspect(aspect)
        } label: {
            SelectableCard(isSelected: isSelected, radius: 14) {
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Palette.ink, lineWidth: 1.6)
                        .frame(width: 22 * min(1, aspect.widthOverHeight), height: 22 * min(1, 1 / aspect.widthOverHeight))
                    Text(aspect.label).font(.footnote.weight(.semibold))
                }
                .frame(height: 62)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(aspect.label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("creatorSetup.format.\(aspect.rawValue)")
    }

    private func chip(_ title: String, isSelected: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            FilterChip(label: title, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}
