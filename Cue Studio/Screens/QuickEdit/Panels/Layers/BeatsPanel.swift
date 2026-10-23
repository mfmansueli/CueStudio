//
//  BeatsPanel.swift
//  Cue Studio
//

import SwiftUI

/// Beats (the picked music, from Files): Snap to beats, Move cuts to the beats, and Cut on the beats every 1, 2 or 4 beats.
/// While the beats are being found, or when the music has no steady beat, the subtitle says so and the actions wait.
struct BeatsPanel: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        let ready = viewModel.audio.hasBeats
        PanelFrame(viewModel: viewModel, panel: .beats) {
            PanelToggleRow(
                label: String(localized: "Snap to beats"), detail: String(localized: "The playhead and the edges stick to them"),
                isOn: viewModel.edit.snapsToBeats, identifier: "edit.beats.snap"
            ) { viewModel.audio.setSnapsToBeats(!viewModel.edit.snapsToBeats) }
            PanelButton(
                label: String(localized: "Move cuts to the beats"), systemImage: "arrow.left.and.right",
                isEnabled: ready && viewModel.edit.timeline.segments.count > 1, identifier: "edit.beats.moveCuts", action: viewModel.audio.moveCutsToBeats
            )
            PanelSegmented(
                label: String(localized: "Cut on"),
                options: [
                    PanelOption(1, String(localized: "Every beat"), key: "1"), PanelOption(2, String(localized: "Every 2"), key: "2"),
                    PanelOption(4, String(localized: "Every 4"), key: "4"),
                ],
                selection: viewModel.audio.beatCutEvery, identifier: "edit.beats.every"
            ) { viewModel.audio.beatCutEvery = $0 }
            PanelButton(
                label: String(localized: "Cut the video on the beats"), systemImage: "scissors", isEnabled: ready,
                identifier: "edit.beats.cut", action: viewModel.audio.cutOnBeats
            )
            PanelNote(text: String(localized: "Found on your iPhone in the music you added from Files."))
        }
    }
}
