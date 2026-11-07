//
//  BeatsPanel.swift
//  Cue Studio
//

import SwiftUI

/// Beats (the picked music, Cue's or from Files), what a creator comes for first (owner, canvas 2 F11): Cut on every beat, 2
/// or 4, and the button that says the interval it cuts on. Then Snap to beats and moving the cuts already made to the nearest
/// beat, which makes no new cut. While the beats are being found, or when the music has no steady beat, the subtitle says so
/// and the actions wait. The note says where the beats were found: Cue's music or the creator's file.
struct BeatsPanel: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        let ready = viewModel.audio.hasBeats
        PanelFrame(viewModel: viewModel, panel: .beats) {
            PanelSegmented(
                label: String(localized: "Cut on"),
                options: [
                    PanelOption(1, String(localized: "Every beat"), key: "1"), PanelOption(2, String(localized: "Every 2"), key: "2"),
                    PanelOption(4, String(localized: "Every 4"), key: "4"),
                ],
                selection: viewModel.audio.beatCutEvery, identifier: "edit.beats.every"
            ) { viewModel.audio.beatCutEvery = $0 }
            PanelButton(
                label: Self.cutLabel(every: viewModel.audio.beatCutEvery), systemImage: "scissors", isEnabled: ready,
                identifier: "edit.beats.cut", action: viewModel.audio.cutOnBeats
            )
            PanelToggleRow(
                label: String(localized: "Snap to beats"), detail: String(localized: "The playhead and the edges stick to them"),
                isOn: viewModel.edit.snapsToBeats, identifier: "edit.beats.snap"
            ) { viewModel.audio.setSnapsToBeats(!viewModel.edit.snapsToBeats) }
            PanelButton(
                label: String(localized: "Move my cuts to the nearest beat"), systemImage: "arrow.left.and.right",
                isEnabled: ready && viewModel.edit.timeline.segments.count > 1, identifier: "edit.beats.moveCuts", action: viewModel.audio.moveCutsToBeats
            )
            PanelNote(text: viewModel.audio.beatsSourceNote, teaches: true)
        }
    }

    /// The cut button names the interval picked above it.
    static func cutLabel(every: Int) -> String {
        switch every {
        case 2: String(localized: "Cut every 2 beats")
        case 4: String(localized: "Cut every 4 beats")
        default: String(localized: "Cut on every beat")
        }
    }
}
