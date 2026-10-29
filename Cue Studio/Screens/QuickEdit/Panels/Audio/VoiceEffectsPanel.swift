//
//  VoiceEffectsPanel.swift
//  Cue Studio
//

import SwiftUI

/// Voice effects, on the picked clip or voice-over: None and the effects as tiles in one sideways row, "Amount" once one is picked, and ◐ in the
/// header to hear the voice without it. The subtitle says where it lands and what the picked effect is for ("Voice-over 1 · A
/// machine talking"); the note under it, that Studio Voice (which only makes the voice clearer) keeps working apart.
struct VoiceEffectsPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    private var audio: AudioViewModel { viewModel.audio }

    private var setting: VoiceEffectSetting? {
        audio.voiceEffectTarget.flatMap(audio.voiceEffect(of:))
    }

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .voiceEffects, compare: audio.voiceEffectCompare) {
            PanelTiles(
                options: [PanelOption<VoiceEffect?>(nil, String(localized: "None"), systemImage: "circle.slash", key: "none")]
                    + VoiceEffect.allCases.map { PanelOption<VoiceEffect?>($0, $0.label, systemImage: $0.systemImage, key: $0.rawValue) },
                selection: setting?.effect, scrollsSideways: true, identifier: "edit.voiceEffect"
            ) { audio.setVoiceEffect($0) }
            .disabled(!audio.voiceEffectIsHeard)
            if let setting {
                PanelSlider(
                    label: String(localized: "Amount"), value: setting.amount * 100,
                    range: VoiceEffectSetting.amountRange.lowerBound * 100...VoiceEffectSetting.amountRange.upperBound * 100, step: 5,
                    defaultValue: VoiceEffectSetting.defaultAmount * 100, format: .percent, identifier: "edit.voiceEffectAmount",
                    onChange: { audio.setVoiceEffectAmount($0 / 100) },
                    onEditingChanged: { editing in editing ? viewModel.beginPanelChange() : viewModel.endPanelChange() }
                )
            }
            PanelNote(text: audio.voiceEffectIsHeard
                ? String(localized: "Studio Voice keeps working underneath.")
                : String(localized: "This clip is muted: turn its sound on to hear an effect."))
        }
    }
}
