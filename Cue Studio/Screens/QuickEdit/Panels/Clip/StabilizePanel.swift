//
//  StabilizePanel.swift
//  Cue Studio
//

import SwiftUI

/// Stabilize (this clip): Off, Gentle, Standard or Strong, how much the clip is zoomed in to hide the edges (or how far the
/// analysis is), and "Use on all 3 clips" (the count says what changes before the tap; owner, canvas 2 R2).
struct StabilizePanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let clip = viewModel.targetClip
        PanelFrame(viewModel: viewModel, panel: .stabilize) {
            PanelTiles(
                options: [
                    PanelOption(StabilizationLevel?.none, String(localized: "None"), systemImage: "circle.slash", key: "off"),
                    PanelOption(StabilizationLevel?.some(.gentle), StabilizationLevel.gentle.label, systemImage: "water.waves", key: "gentle"),
                    PanelOption(
                        StabilizationLevel?.some(.standard), StabilizationLevel.standard.label, systemImage: "camera.metering.center.weighted",
                        key: "standard"
                    ),
                    PanelOption(StabilizationLevel?.some(.strong), StabilizationLevel.strong.label, systemImage: "figure.walk", key: "strong"),
                ],
                selection: clip?.stabilization, identifier: "edit.stabilize"
            ) { viewModel.look.setStabilization($0) }
            if let note = viewModel.look.stabilizationNote {
                PanelNote(text: note)
                    .accessibilityIdentifier("edit.stabilize.note")
            }
            if clip?.stabilization != nil, viewModel.edit.timeline.segments.count > 1 {
                PanelButton(
                    label: String(localized: "Use on all \(viewModel.edit.timeline.segments.count) clips"), systemImage: "square.stack.3d.up",
                    identifier: "edit.stabilize.everyClip",
                    action: viewModel.look.useStabilizationOnEveryClip
                )
            }
        }
    }
}
