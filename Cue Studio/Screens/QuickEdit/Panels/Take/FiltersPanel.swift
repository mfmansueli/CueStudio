//
//  FiltersPanel.swift
//  Cue Studio
//

import SwiftUI

/// Filters (whole take): Original, Vivid, Warm, Cool, Mono and Fade, each shown on a real frame of
/// the take; Intensity for the picked one.
struct FiltersPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var previews: [VideoFilter: UIImage] = [:]

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .filters) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(VideoFilter.editorFilters) { filter in
                        card(filter)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -16)
            if viewModel.edit.filter != .original {
                PanelSlider(
                    label: String(localized: "Intensity"), value: viewModel.edit.filterAmount * 100, range: 0...100,
                    format: .percent, identifier: "edit.filter.intensity"
                ) { viewModel.setFilterAmount($0 / 100) }
            }
        }
        .task { await loadPreviews() }
    }

    private func card(_ filter: VideoFilter) -> some View {
        let isOn = viewModel.edit.filter == filter
        return Button { viewModel.pickFilter(filter) } label: {
            VStack(spacing: 6) {
                Group {
                    if let image = previews[filter] {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Palette.surface2
                    }
                }
                .frame(width: 62, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(isOn ? Palette.acc : .clear, lineWidth: 2))
                Text(filter.label)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(isOn ? Palette.accText : Palette.ink.opacity(0.75))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("edit.filter.\(filter.rawValue)")
    }

    private func loadPreviews() async {
        guard previews.isEmpty, let frame = await thumbnails.thumbnail(for: viewModel.videoURL, maxPixelSize: 240) else { return }
        previews = await Task.detached { FilterPreviews.render(frame) }.value
    }
}
