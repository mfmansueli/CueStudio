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
            // The slider and the switch under it, 8 pt apart and without the 0%/200% captions (the value is written above the
            // track): "Mute this clip" then shows whole above the Home Indicator in the short panel of an iPhone 17 or SE.
            VStack(alignment: .leading, spacing: 8) {
                CueSlider(
                    value: Binding(get: { viewModel.targetVolume * 100 }, set: { viewModel.setTargetVolume(($0 / 5).rounded() * 5 / 100) }),
                    range: spec.range, step: spec.step, defaultValue: spec.defaultValue, style: .full, label: volumeLabel,
                    valueText: PanelValueFormat.percent.text(viewModel.targetVolume * 100), systemIcon: volumeIcon,
                    accessibilityIdentifier: "edit.volume", onEditingChanged: { _ in }
                )
                switch viewModel.selection {
                case .music(let id):
                    if let music = viewModel.edit.music.first(where: { $0.id == id }) { ducking(music) }
                case .voiceOver:
                    EmptyView()
                default:
                    PanelToggleRow(
                        label: String(localized: "Mute this clip"), isOn: viewModel.targetClip?.isMuted ?? false,
                        identifier: "edit.volume.mute"
                    ) { viewModel.setClipMuted(!(viewModel.targetClip?.isMuted ?? false)) }
                }
            }
            if case .music(let id) = viewModel.selection, let music = viewModel.edit.music.first(where: { $0.id == id }) {
                musicAdvanced(music)
            }
        }
    }

    /// Your voice and a voice-over go to 200% (a soft tick at 100%, as recorded); music, which sits under the
    /// voice, to 100% (a soft tick at 20%).
    private var spec: CueSliderSpec {
        if case .music = viewModel.selection { return .music }
        return .voice
    }

    private var volumeLabel: String {
        switch viewModel.selection {
        case .music: String(localized: "Music")
        case .voiceOver: String(localized: "Voice-over")
        default: String(localized: "Your voice")
        }
    }

    private var volumeIcon: CueIcon {
        if case .music = viewModel.selection { return .volume }
        return .audio
    }

    private func ducking(_ music: MusicClip) -> some View {
        PanelToggleRow(
            label: String(localized: "Lower under voice"), detail: String(localized: "Quieter while someone speaks"),
            isOn: music.ducksUnderVoice, identifier: "edit.musicDucks"
        ) { viewModel.setMusicDucks(music.id, !music.ducksUnderVoice) }
    }

    @ViewBuilder
    private func musicAdvanced(_ music: MusicClip) -> some View {
        let changed = [music.fadeIn != MusicClip.defaultFadeIn, music.fadeOut != MusicClip.defaultFadeOut].filter { $0 }.count
        PanelAdvancedButton(isOpen: viewModel.showsAdvanced, detail: changed > 0 ? PanelAdvancedButton.changed(changed) : nil) {
            viewModel.showsAdvanced.toggle()
        }
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
