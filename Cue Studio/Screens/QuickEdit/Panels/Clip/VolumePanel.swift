//
//  VolumePanel.swift
//  Cue Studio
//

import SwiftUI

/// Volume, 0 to 200%, of the picked clip (with "Mute this clip"), music or voice-over; a video's own sound over the take, 0 to
/// 100% (muted until it's turned up). A clip and music keep their fades under Advanced. Music has "Lower under voice" with who
/// it goes down under, how far ("Lower by") and what it does in pauses, the same on every music clip at once, and ◐ to hear it
/// without lowering. When the sounds together go over full scale, a line says the preview may distort and the video won't.
struct VolumePanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        Group {
            if let media = viewModel.selectedMedia {
                mediaVolume(media)
            } else {
                clipVolume
            }
        }
        // The sounds together measured while Volume is open, again once a change rests (`QuickEditViewModel.measureMix`).
        .task(id: viewModel.edit) { await viewModel.measureMix() }
    }

    /// The edit's sounds go over full scale together: the preview (no limiter) may distort, the exported video doesn't.
    @ViewBuilder
    private var loudMixNote: some View {
        if viewModel.mixTooLoud {
            PanelNote(text: String(localized: "Too loud together · the preview may distort, the video won’t"), tint: Palette.warnText)
                .accessibilityIdentifier("edit.volume.loudMix")
        }
    }

    /// A video laid over the take: its own sound, the same level Media › Edit had.
    private func mediaVolume(_ media: MediaOverlay) -> some View {
        PanelFrame(viewModel: viewModel, panel: .volume) {
            PanelSlider(
                label: String(localized: "Sound"), value: (media.audioVolume ?? 0) * 100, range: 0...100, format: .percent,
                identifier: "edit.mediaSound",
                onChange: { viewModel.overlays.setMediaSoundVolume(media.id, $0 / 100) },
                onEditingChanged: { editing in editing ? viewModel.beginPanelChange() : viewModel.endPanelChange() }
            )
            PanelNote(text: String(localized: "0% keeps it muted under your voice. Turn it up to hear it."))
            loudMixNote
        }
    }

    private var clipVolume: some View {
        PanelFrame(viewModel: viewModel, panel: .volume, compare: pickedMusic.map(viewModel.audio.duckingCompare(for:))) {
            // The slider and the switch under it, 8 pt apart and without the 0%/200% captions (the value is written above the
            // track): "Mute this clip" then shows whole above the Home Indicator in the short panel of an iPhone 17 or SE.
            VStack(alignment: .leading, spacing: 8) {
                CueSlider(
                    value: Binding(get: { viewModel.clips.targetVolume * 100 }, set: { viewModel.clips.setTargetVolume(($0 / 5).rounded() * 5 / 100) }),
                    range: spec.range, step: spec.step, defaultValue: spec.defaultValue, style: .full, label: volumeLabel,
                    valueText: PanelValueFormat.percent.text(viewModel.clips.targetVolume * 100),
                    valueSamples: [PanelValueFormat.percent.text(spec.range.upperBound)], systemIcon: volumeIcon,
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
                    ) { viewModel.clips.setClipMuted(!(viewModel.targetClip?.isMuted ?? false)) }
                }
                loudMixNote
            }
            switch viewModel.selection {
            case .music(let id):
                if let music = viewModel.edit.music.first(where: { $0.id == id }) { musicAdvanced(music) }
            case .voiceOver:
                EmptyView()
            default:
                if let clip = viewModel.targetClip { clipAdvanced(clip) }
            }
        }
    }

    private var pickedMusic: MusicClip? {
        guard case .music(let id) = viewModel.selection else { return nil }
        return viewModel.edit.music.first { $0.id == id }
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

    /// A voice for a clip or a voice-over (a note is for music); the speaker for music.
    private var volumeIcon: CueIcon {
        if case .music = viewModel.selection { return .volume }
        return .cleanVoice
    }

    /// Whether it goes down under the voice (and under whom), how far, what it does in pauses, and the same on every music clip.
    @ViewBuilder
    private func ducking(_ music: MusicClip) -> some View {
        PanelToggleRow(
            label: String(localized: "Lower under voice"), detail: viewModel.audio.loweringScope(of: music),
            isOn: music.ducksUnderVoice, identifier: "edit.musicDucks"
        ) { viewModel.audio.setMusicDucks(music.id, !music.ducksUnderVoice) }
        if music.ducksUnderVoice {
            let duck = viewModel.audio.duck(of: music)
            PanelSlider(
                label: String(localized: "Lower by"), value: duck.depth, range: MusicDuck.depthRange, step: 1,
                defaultValue: MusicDuck.standard.depth, format: .decibels, identifier: "edit.musicDuckDepth",
                onChange: { viewModel.audio.setMusicDuckDepth(music.id, $0) },
                onEditingChanged: { editing in editing ? viewModel.beginPanelChange() : viewModel.endPanelChange() }
            )
            PanelSegmented(
                label: String(localized: "In pauses"),
                options: MusicDuckPauses.allCases.map { PanelOption($0, $0.label, key: $0.rawValue) },
                selection: duck.pauses, identifier: "edit.musicDuckPauses"
            ) { viewModel.audio.setMusicDuckPauses(music.id, $0) }
        }
        if viewModel.audio.musicLoweringDifferently(from: music) > 0 {
            PanelButton(
                label: String(localized: "Use on all music"), systemImage: "square.on.square", isCompact: true, identifier: "edit.musicDuckAll"
            ) { viewModel.audio.useLoweringOnAllMusic(from: music.id) }
        }
    }

    /// The clip's sound rising from silence at its start and falling to it at its end (no longer than the clip).
    @ViewBuilder
    private func clipAdvanced(_ clip: EditSegment) -> some View {
        let changed = [clip.soundFadeIn > 0, clip.soundFadeOut > 0].filter { $0 }.count
        let longest = min(EditSegment.soundFadeRange.upperBound, max(0.1, (clip.duration * 10).rounded(.down) / 10))
        PanelAdvancedButton(isOpen: viewModel.showsAdvanced, detail: changed > 0 ? PanelAdvancedButton.changed(changed) : nil) {
            viewModel.showsAdvanced.toggle()
        }
        if viewModel.showsAdvanced {
            PanelSlider(
                label: String(localized: "Fade in"), value: min(clip.soundFadeIn, longest), range: 0...longest, step: 0.1, defaultValue: 0,
                format: .seconds, identifier: "edit.clipFadeIn"
            ) { viewModel.clips.setClipSoundFadeIn($0) }
            PanelSlider(
                label: String(localized: "Fade out"), value: min(clip.soundFadeOut, longest), range: 0...longest, step: 0.1, defaultValue: 0,
                format: .seconds, identifier: "edit.clipFadeOut"
            ) { viewModel.clips.setClipSoundFadeOut($0) }
        }
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
            ) { viewModel.audio.setMusicFadeIn(music.id, $0) }
            PanelSlider(
                label: String(localized: "Fade out"), value: music.fadeOut, range: 0...MusicClip.fadeRange.upperBound, step: 0.1,
                format: .seconds, identifier: "edit.musicFadeOut"
            ) { viewModel.audio.setMusicFadeOut(music.id, $0) }
        }
    }
}
