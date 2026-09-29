//
//  CaptionsToolView.swift
//  Cue Studio
//

import SwiftUI

/// Captions: on or off, three styles and three positions. They come from the script, timed to
/// the voice.
struct CaptionsToolView: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        VStack(spacing: 10) {
            Toggle(isOn: Binding(
                get: { viewModel.edit.showsCaptions },
                set: { shows in Task { await viewModel.setShowsCaptions(shows) } }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Captions")
                    Text(viewModel.isWritingCaptions ? String(localized: "Listening to your take…") : String(localized: "From your script, synced to your voice"))
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
            }
            .tint(Palette.success)
            .disabled(viewModel.isWritingCaptions)
            .padding(.horizontal, 16)
            .frame(minHeight: 58)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
            .accessibilityIdentifier("edit.captionsToggle")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(TypePreset.allCases) { preset in
                        let isOn = viewModel.edit.captionPreset == preset
                        Button {
                            Task { await viewModel.setCaptionPreset(preset) }
                        } label: {
                            captionSample(preset)
                                .frame(width: 112, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isOn ? Palette.acc : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(preset.label))
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                        .accessibilityIdentifier("edit.captionPreset.\(preset.rawValue)")
                    }
                }
            }
            .scrollIndicators(.hidden)
            Picker("Position", selection: $viewModel.edit.captionPosition) {
                ForEach(CaptionPosition.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    /// The preset drawn on captions exactly as the export draws them.
    private func captionSample(_ preset: TypePreset) -> some View {
        ZStack {
            LinearGradient(colors: [Palette.thumbnailTop, Palette.thumbnailBottom], startPoint: .top, endPoint: .bottom)
            if let image = TypeLookPreview.image(preset.look(for: .caption), use: .caption, sample: preset.label) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            }
        }
    }
}
