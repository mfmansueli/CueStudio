//
//  CaptionPlayheadWatcher.swift
//  Cue Studio
//

import SwiftUI

/// Reads the player's clock in its own small view, so only it redraws while the video plays, and
/// tells Captions when the line under the playhead changes.
struct CaptionPlayheadWatcher: View {
    let viewModel: QuickEditViewModel
    let onChange: (UUID?) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: viewModel.activeCaptionCueID, initial: true) { _, id in onChange(id) }
            .accessibilityHidden(true)
    }
}
