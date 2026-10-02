//
//  FiltersPanel.swift
//  Cue Studio
//

import SwiftUI

/// Filters (whole take, or the picked clip alone when opened from it): Original and the collection
/// (Natural, Studio, Soft, Cinema, Warm Editorial, Retro, Mono Soft, Mono Contrast), each shown on a
/// real frame of the video in scope, at the intensity it starts with; Intensity for the picked one.
/// A filter from before the collection shows only while it is the one picked. For a clip, Reset
/// gives it the take's filter again.
struct FiltersPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var previews: [VideoFilter: UIImage] = [:]

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .filters, onReset: reset) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(shownFilters) { filter in
                        card(filter)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -16)
            if viewModel.currentFilter != .original {
                PanelSlider(
                    label: String(localized: "Intensity"), value: viewModel.currentFilterAmount * 100, range: 0...100,
                    format: .percent, identifier: "edit.filter.intensity"
                ) { viewModel.setFilterAmount($0 / 100) }
            }
        }
        .task(id: previewKey) { await loadPreviews() }
    }

    /// Original and the collection; a filter from before it, too, while it is the one picked.
    private var shownFilters: [VideoFilter] {
        viewModel.currentFilter.isLegacy ? VideoFilter.editorFilters + [viewModel.currentFilter] : VideoFilter.editorFilters
    }

    /// The frame the thumbnails are drawn from: it changes with the clip in scope.
    private var previewKey: String {
        let source = viewModel.filterPreviewSource
        return "\(source.url.path(percentEncoded: false))@\(Int(source.time * 10))"
    }

    /// Only for a clip, and only once it sets its own filter.
    private var reset: (() -> Void)? {
        guard viewModel.clipOverridesFilter else { return nil }
        return { viewModel.resetClipFilter() }
    }

    private func card(_ filter: VideoFilter) -> some View {
        let isOn = viewModel.currentFilter == filter
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .frame(width: 62)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("edit.filter.\(filter.rawValue)")
    }

    private func loadPreviews() async {
        let key = previewKey
        if let kept = FilterPreviews.kept(for: key) {
            previews = kept
            return
        }
        let source = viewModel.filterPreviewSource
        let frame: UIImage?
        if source.time == 0.3 && source.url == viewModel.videoURL {
            frame = await thumbnails.thumbnail(for: source.url, maxPixelSize: 240)
        } else {
            frame = await thumbnails.frames(for: source.url, at: [source.time], tolerance: 0.25, maxPixelSize: 240).first ?? nil
        }
        guard let frame, !Task.isCancelled else { return }
        let rendered = await Task.detached { FilterPreviews.render(frame, key: key) }.value
        if !Task.isCancelled { previews = rendered }
    }
}
