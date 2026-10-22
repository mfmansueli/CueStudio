//
//  VoicePanel.swift
//  Cue Studio
//

import SwiftUI

/// Studio Voice: Enhance voice and Reduce noise, each Off, Light or Strong; ◐ in the header plays the
/// untreated sound, as loud, with "Original audio" on the preview (a tap until the next one, or only
/// while held). In a montage, which recordings it treats (the take always; the others can
/// be left as recorded, the picked clip's one marked) and "Even out volume" between them. Music and the sound of videos over
/// the take are never treated.
struct VoicePanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .voice, compare: viewModel.soundCompare) {
            strength(
                String(localized: "Enhance voice"), viewModel.edit.voiceEnhancement, "edit.enhanceVoice"
            ) { viewModel.setVoiceEnhancement($0) }
            strength(
                String(localized: "Reduce noise"), viewModel.edit.noiseReduction, "edit.reduceNoise"
            ) { viewModel.setNoiseReduction($0) }
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

    /// Off · Light · Strong: three words, so a segmented control, the same as every other 2–4 word choice in the editor.
    private func strength(
        _ label: String, _ value: AudioStrength, _ identifier: String, onChange: @escaping (AudioStrength) -> Void
    ) -> some View {
        PanelSegmented(
            label: label, options: AudioStrength.allCases.map { PanelOption($0, $0.label, key: $0.rawValue) },
            selection: value, identifier: identifier, onSelect: onChange
        )
    }
}
