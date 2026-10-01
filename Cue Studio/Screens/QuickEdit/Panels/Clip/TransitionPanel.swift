//
//  TransitionPanel.swift
//  Cue Studio
//

import SwiftUI

/// The cut picked on the timeline: None keeps it a hard cut; Dissolve, Fade or Slide plays across
/// it (the playhead goes a second before the cut, so Play shows it). With more cuts, the same on
/// every one.
struct TransitionPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .transition) {
            PanelTiles(
                options: EditTransition.allCases.map { PanelOption($0, $0.label, systemImage: $0.systemImage, key: $0.rawValue) },
                selection: viewModel.selectedTransition, identifier: "edit.transition"
            ) { viewModel.setTransition($0) }
            if let note = viewModel.transitionNote {
                PanelNote(text: note)
            }
            if viewModel.cuts.count > 1, let transition = viewModel.selectedTransition {
                PanelButton(
                    label: String(localized: "Use on every cut"), systemImage: "square.on.square",
                    identifier: "edit.transition.everyCut"
                ) { viewModel.setTransitionOnEveryCut(transition) }
            }
        }
    }
}
