//
//  VolumePanel.swift
//  Cue Studio
//

import SwiftUI

/// Volume, 0 to 200%, of the picked clip (with "Mute this clip"), music or voice-over. Music keeps
/// its fades and "Lower under voice" under Advanced.
struct VolumePanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .volume) {
            PanelSlider(
                label: String(localized: "Volume"), value: viewModel.targetVolume * 100, range: 0...200,
                format: .percent, identifier: "edit.volume"
            ) { viewModel.setTargetVolume($0 / 100) }
            switch viewModel.selection {
            case .music(let id):
                if let music = viewModel.edit.music.first(where: { $0.id == id }) { musicAdvanced(music) }
            case .voiceOver:
                EmptyView()
            default:
                PanelToggleRow(
                    label: String(localized: "Mute this clip"), isOn: viewModel.targetClip?.isMuted ?? false,
                    identifier: "edit.volume.mute"
                ) { viewModel.setClipMuted(!(viewModel.targetClip?.isMuted ?? false)) }
            }
        }
    }

    @ViewBuilder
    private func musicAdvanced(_ music: MusicClip) -> some View {
        PanelToggleRow(
            label: String(localized: "Lower under voice"), detail: String(localized: "Quieter while someone speaks"),
            isOn: music.ducksUnderVoice, identifier: "edit.musicDucks"
        ) { viewModel.setMusicDucks(music.id, !music.ducksUnderVoice) }
        PanelAdvancedButton(isOpen: viewModel.showsAdvanced) { viewModel.showsAdvanced.toggle() }
        if viewModel.showsAdvanced {
            PanelSlider(
                label: String(localized: "Fade in"), value: music.fadeIn, range: 0...MusicClip.fadeRange.upperBound, step: 0.1,
                format: .seconds, identifier: "edit.musicFadeIn"
            ) { viewModel.setMusicFadeIn(music.id, $0) }
            PanelSlider(
                label: String(localized: "Fade out"), value: music.fadeOut, range: 0...MusicClip.fadeRange.upperBound, step: 0.1,
                format: .seconds, identifier: "edit.musicFadeOut"
            ) { viewModel.setMusicFadeOut(music.id, $0) }
        }
    }
}
