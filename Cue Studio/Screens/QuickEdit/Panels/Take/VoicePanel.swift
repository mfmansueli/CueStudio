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
        PanelFrame(viewModel: viewModel, panel: .voice) {
            strength(
                String(localized: "Enhance voice"), viewModel.edit.voiceEnhancement, "edit.enhanceVoice", icon: .cleanVoice
            ) { viewModel.setVoiceEnhancement($0) }
            strength(
                String(localized: "Reduce noise"), viewModel.edit.noiseReduction, "edit.reduceNoise", icon: .audio
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

    /// Off · Light · Strong as a slider that snaps from one to the next.
    private func strength(
        _ label: String, _ value: AudioStrength, _ identifier: String, icon: CueIcon, onChange: @escaping (AudioStrength) -> Void
    ) -> some View {
        CueSlider(
            value: Binding(
                get: { Double(AudioStrength.allCases.firstIndex(of: value) ?? 0) },
                set: { onChange(AudioStrength.allCases[max(0, min(AudioStrength.allCases.count - 1, Int($0.rounded())))]) }
            ),
            range: CueSliderSpec.cleanUpVoice.range, step: CueSliderSpec.cleanUpVoice.step,
            defaultValue: CueSliderSpec.cleanUpVoice.defaultValue, style: .full, label: label,
            valueText: value.label, systemIcon: icon, accessibilityIdentifier: identifier
        )
    }
}
