//
//  TransitionPanel.swift
//  Cue Studio
//

import SwiftUI

/// The cut picked on the timeline: None keeps it a hard cut; Dissolve, Fade, Slide, Zoom, Blur, Flash, Push, Punch or Wipe
/// plays across it (the playhead goes a second before the cut, so Play shows it), as long as its Duration says. With more
/// cuts, the same on every one.
struct TransitionPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .transition) {
            PanelTiles(
                options: EditTransition.allCases.map { PanelOption($0, $0.label, systemImage: $0.systemImage, key: $0.rawValue) },
                selection: viewModel.selectedTransition, identifier: "edit.transition"
            ) { viewModel.setTransition($0) }
            if let duration = viewModel.selectedTransitionDuration {
                PanelSlider(
                    label: String(localized: "Duration"), value: duration, range: EditTransition.durationRange, step: 0.05,
                    defaultValue: viewModel.selectedTransition?.duration, format: .seconds, identifier: "edit.transition.duration",
                    onChange: { viewModel.setTransitionDuration($0) }
                )
            }
            if let note = viewModel.transitionNote {
                PanelNote(text: note)
            }
        } footer: {
            // Always in reach, under the scrolling choices: the panel is short on a small iPhone.
            if viewModel.cuts.count > 1, let transition = viewModel.selectedTransition {
                PanelButton(
                    label: String(localized: "Use on every cut"), systemImage: "square.on.square",
                    identifier: "edit.transition.everyCut"
                ) { viewModel.setTransitionOnEveryCut(transition) }
            }
        }
    }
}
