//
//  TimelineTracksView.swift
//  Cue Studio
//

import SwiftUI

/// The shared timeline's tracks under the video strip in Edit: texts, captions, photos and videos,
/// and sound laid over the take (voice-overs). They use the strip's scale, zoom and scroll, so a
/// bar sits under the frames it shows over. A track with nothing on it takes no room.
///
/// Tapping a bar picks it (and lets go of any other); dragging it moves it in time; dragging an end
/// of the picked bar changes when it starts or stops; anywhere else the playhead follows the
/// finger. Each drag is one undo step.
struct TimelineTracksView: View {
    let viewModel: QuickEditViewModel
    let zoom: TimelineZoomController

    /// A track's height with one row of bars; overlapping bars stack in more rows.
    static let trackHeight: CGFloat = 24
    /// Extra height for each more row of overlapping bars.
    static let rowHeight: CGFloat = 12
    static let spacing: CGFloat = 4

    /// How tall the tracks are for `viewModel`'s edit: nothing when there's nothing on them.
    static func height(for viewModel: QuickEditViewModel) -> CGFloat {
        let tracks = tracks(for: viewModel)
        guard !tracks.isEmpty else { return 0 }
        return tracks.reduce(0) { $0 + $1.height } + spacing * CGFloat(tracks.count)
    }

    var body: some View {
        let tracks = Self.tracks(for: viewModel)
        GeometryReader { proxy in
            let layout = TimelineLayout(
                timeline: viewModel.edit.timeline, width: proxy.size.width, reach: viewModel.trimOrigin,
                zoom: zoom.zoom, offset: zoom.offset
            )
            VStack(spacing: Self.spacing) {
                ForEach(tracks) { track in
                    LayerTrackView(
                        viewModel: viewModel, bars: track.bars, tint: track.tint,
                        identifier: "edit.track.\(track.kind.rawValue)", height: track.height, scale: TrackScale(layout: layout)
                    )
                }
            }
        }
        .frame(height: Self.height(for: viewModel))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.tracks")
    }

    // MARK: - Tracks

    struct Track: Identifiable {
        let kind: LayerKind
        let bars: [LayerBar]
        let tint: Color
        let height: CGFloat
        var id: LayerKind { kind }
    }

    private static func tracks(for viewModel: QuickEditViewModel) -> [Track] {
        let all: [(LayerKind, [LayerBar], Color)] = [
            (.text, viewModel.textBars, Palette.acc),
            (.caption, viewModel.captionBars, Palette.ink2),
            (.media, viewModel.mediaBars, Palette.info),
            (.voiceOver, viewModel.voiceOverBars, Palette.success),
        ]
        return all.compactMap { kind, bars, tint in
            guard !bars.isEmpty else { return nil }
            let rows = max(1, LayerLanes.count(LayerLanes.lanes(for: bars)))
            return Track(kind: kind, bars: bars, tint: tint, height: trackHeight + rowHeight * CGFloat(rows - 1))
        }
    }
}
