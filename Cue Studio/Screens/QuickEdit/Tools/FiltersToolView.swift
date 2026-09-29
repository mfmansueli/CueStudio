//
//  FiltersToolView.swift
//  Cue Studio
//

import SwiftUI

/// Filters: Original, Vivid, Warm, Cool, Mono and Film, each previewed on a frame of the take.
struct FiltersToolView: View {
    @Bindable var viewModel: QuickEditViewModel

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var previews: [VideoFilter: UIImage] = [:]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(VideoFilter.allCases) { filter in
                    let isOn = viewModel.edit.filter == filter
                    Button { viewModel.setFilter(filter) } label: {
                        VStack(spacing: 6) {
                            Group {
                                if let image = previews[filter] {
                                    Image(uiImage: image).resizable().scaledToFill()
                                } else {
                                    LinearGradient(colors: [Palette.thumbnailTop, Palette.thumbnailBottom], startPoint: .top, endPoint: .bottom)
                                }
                            }
                            .frame(width: 58, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous).strokeBorder(isOn ? Palette.acc : .clear, lineWidth: 2))
                            Text(filter.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isOn ? Palette.acc : Palette.ink.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .accessibilityIdentifier("edit.filter.\(filter.rawValue)")
                }
            }
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
        .task {
            guard let poster = await thumbnails.thumbnail(for: viewModel.videoURL, maxPixelSize: 240) else { return }
            previews = FilterPreviews.render(poster)
        }
    }
}
