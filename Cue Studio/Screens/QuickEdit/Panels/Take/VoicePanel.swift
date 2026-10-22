//
//  VoicePanel.swift
//  Cue Studio
//

import SwiftUI

/// Studio Voice: Enhance voice and Reduce noise, each Off, Soft or Strong; "Compare with original" plays the untreated sound,
/// as loud, with "Original audio" on the preview. In a montage, which recordings it treats (the take always; the others can
/// be left as recorded, the picked clip's one marked) and "Even out volume" between them. Music and the sound of videos over
/// the take are never treated.
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
                label: viewModel.comparesOriginal ? String(localized: "Playing original · tap to stop") : String(localized: "Compare with original"),
                systemImage: "ear", isEnabled: viewModel.canCompareOriginal || viewModel.comparesOriginal,
                identifier: "edit.compareOriginal"
            ) { viewModel.toggleComparison() }
            if !viewModel.canCompareOriginal, !viewModel.comparesOriginal {
                PanelNote(text: String(localized: "Turn on Enhance voice or Reduce noise to compare."))
            }
            if !viewModel.voiceRecordings.isEmpty { recordings }
        }
    }

    /// Which recordings are treated, and evening out their volume.
    private var recordings: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Applies to")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 4)
            ForEach(viewModel.voiceRecordings) { recording in
                PanelToggleRow(
                    label: recording.title,
                    detail: recording.isPickedClip ? String(localized: "The clip you picked") : (recording.canChange ? nil : String(localized: "Always")),
                    isOn: recording.isTreated, identifier: "edit.voice.recording.\(recording.id)"
                ) {
                    guard recording.canChange, let id = recording.sourceID else { return }
                    viewModel.setTreatsVoice(of: id, !recording.isTreated)
                }
                .disabled(!recording.canChange)
            }
            PanelToggleRow(
                label: String(localized: "Even out volume between clips"),
                detail: String(localized: "Brings each clip's voice to this take's level, without clipping."),
                isOn: viewModel.edit.evensOutVoices, identifier: "edit.voice.evenOut"
            ) { viewModel.setEvensOutVoices(!viewModel.edit.evensOutVoices) }
            PanelNote(text: String(localized: "Music and the sound of photos or videos on top stay as they are."))
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
