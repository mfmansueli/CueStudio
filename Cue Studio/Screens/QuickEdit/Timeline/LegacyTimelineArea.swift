//
//  LegacyTimelineArea.swift
//  Cue Studio
//

import SwiftUI

/// The timeline strip and its tracks, until the editor's own timeline replaces them.
struct LegacyTimelineArea: View {
    let viewModel: QuickEditViewModel

    @State private var zoom = TimelineZoomController()

    var body: some View {
        VStack(spacing: 6) {
            TimelineStripView(viewModel: viewModel, zoom: zoom)
            TimelineTracksView(viewModel: viewModel, zoom: zoom)
        }
        .padding(.horizontal, Metrics.gutter)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
