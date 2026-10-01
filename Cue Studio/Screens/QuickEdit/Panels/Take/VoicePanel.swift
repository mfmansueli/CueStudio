//
//  VoicePanel.swift
//  Cue Studio
//

import SwiftUI

/// Voice (whole take): Enhance voice and Reduce noise, each Off, Soft or Strong; "Compare with
/// original" plays the untreated sound, as loud, with "Original audio" on the preview.
struct VoicePanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let strengths = AudioStrength.allCases.map { PanelOption($0, $0.label) }
        PanelFrame(viewModel: viewModel, panel: .voice) {
            PanelSegmented(
                label: String(localized: "Enhance voice"), detail: String(localized: "Clearer, fuller speech"),
                options: strengths, selection: viewModel.edit.voiceEnhancement, identifier: "edit.enhanceVoice"
            ) { viewModel.setVoiceEnhancement($0) }
            PanelSegmented(
                label: String(localized: "Reduce noise"), detail: String(localized: "Hiss, hum and room echo"),
                options: strengths, selection: viewModel.edit.noiseReduction, identifier: "edit.reduceNoise"
            ) { viewModel.setNoiseReduction($0) }
            PanelButton(
                label: viewModel.comparesOriginal ? String(localized: "Playing original — tap to stop") : String(localized: "Compare with original"),
                systemImage: "ear", isEnabled: viewModel.canCompareOriginal || viewModel.comparesOriginal,
                identifier: "edit.compareOriginal"
            ) { viewModel.toggleComparison() }
            if !viewModel.canCompareOriginal, !viewModel.comparesOriginal {
                PanelNote(text: String(localized: "Turn on Enhance voice or Reduce noise to compare."))
            }
        }
    }
}
