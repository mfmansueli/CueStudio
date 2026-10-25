//
//  SplitPartTab.swift
//  Cue Studio
//

import SwiftUI

/// The support's part and timing: for a video, which part of it plays and for how long (`MediaTrimStrip`); for a photo, how long
/// it shows; where it is in the video; and, when there is a space between it and the support before it (the main video takes
/// the whole frame there), "Close gap", which says what it does.
struct SplitPartTab: View {
    let viewModel: QuickEditViewModel
    let media: MediaOverlay

    private var overlays: OverlaysViewModel { viewModel.overlays }

    var body: some View {
        let span = viewModel.mediaBars.first { $0.id == media.id }?.span
        VStack(alignment: .leading, spacing: 16) {
            if media.kind == .video, media.mediaDuration != nil {
                MediaTrimStrip(viewModel: viewModel, media: media)
            } else if let span {
                PanelStepper(
                    label: String(localized: "Shows for"), value: DurationText.tenths(span.duration), identifier: "edit.mediaLength",
                    onDecrease: { overlays.setMediaLength(media.id, span.duration - 0.5) },
                    onIncrease: { overlays.setMediaLength(media.id, span.duration + 0.5) }
                )
            }
            if let span {
                PanelRowLabel(
                    label: String(localized: "In the video"),
                    detail: DurationText.editorRange(span.start, span.end)
                )
            }
            if let gap = overlays.gapBefore(media.id) {
                VStack(alignment: .leading, spacing: 8) {
                    PanelNote(text: String(localized: "\(DurationText.tenths(gap)) before it without a support: the main video takes the whole frame there."))
                    PanelButton(
                        label: String(localized: "Close gap"), systemImage: "arrow.left.to.line", identifier: "edit.split.closeGap"
                    ) { overlays.closeGap(before: media.id) }
                    PanelNote(text: String(localized: "Moves this support back to meet the one before. Your speech doesn’t change."))
                }
            }
        }
    }
}
