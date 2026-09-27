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
            HStack(spacing: 8) {
                ForEach(CaptionStyle.allCases) { style in
                    let isOn = viewModel.edit.captionStyle == style
                    Button {
                        Task { await viewModel.setCaptionStyle(style) }
                    } label: {
                        CaptionStyleSample(style: style)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isOn ? Palette.acc : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(style.label))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            Picker("Position", selection: $viewModel.edit.captionPosition) {
                ForEach(CaptionPosition.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }
}
