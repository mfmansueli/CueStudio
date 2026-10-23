//
//  ClipOrderSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Reorder": the clips in play order, each with its frame, what it is and how long, dragged by the handle into a new order.
/// Opened from the clip's tools or by holding a clip on the timeline (CapCut's long-press). Every move is one undo step; what
/// plays on a clip goes with it.
struct ClipOrderSheet: View {
    @Bindable var viewModel: QuickEditViewModel
    let thumbnails: VideoThumbnailService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SheetHeader(title: String(localized: "Reorder"), subtitle: String(localized: "Drag a clip to where it should play"))
                // Lined up with the rows and with every other sheet's title.
                .padding(.horizontal, 16)
            List {
                ForEach(viewModel.clips) { clip in
                    row(clip)
                        .listRowBackground(clip.id == viewModel.selection?.clipID ? Palette.Editor.accTile : Palette.Editor.panelCard)
                        .accessibilityIdentifier("edit.reorder.clip.\(clip.index)")
                }
                .onMove { from, to in
                    guard let source = from.first else { return }
                    viewModel.moveSection(from: source, to: to > source ? to - 1 : to)
                    Haptics.selection()
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
            .accessibilityIdentifier("edit.reorder.list")
        }
        .padding(.top, 8)
        .cueSheetChrome()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ clip: QuickEditViewModel.Clip) -> some View {
        HStack(spacing: 12) {
            ClipOrderThumbnail(url: url(of: clip), time: clip.thumbnailTime, thumbnails: thumbnails)
            VStack(alignment: .leading, spacing: 2) {
                Text("Clip \(clip.index + 1)").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                Text(verbatim: "\(clip.title) · \(DurationText.tenths(clip.duration))")
                    .font(.footnote).foregroundStyle(Palette.ink2).lineLimit(1)
            }
        }
        .frame(minHeight: Metrics.hitTarget)
        .accessibilityElement(children: .combine)
    }

    private func url(of clip: QuickEditViewModel.Clip) -> URL {
        clip.sourceID.flatMap { viewModel.clipSourceURLs[$0] } ?? viewModel.videoURL
    }
}
