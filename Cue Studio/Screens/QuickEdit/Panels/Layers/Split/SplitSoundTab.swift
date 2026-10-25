//
//  SplitSoundTab.swift
//  Cue Studio
//

import SwiftUI

/// The two sounds while the support shows, each on its own: the main video (down to silent, to hear only the support) and the
/// support's own sound (silent when it goes in), with whose voice the captions show; and every support muted at once, each
/// keeping its level for later.
struct SplitSoundTab: View {
    let viewModel: QuickEditViewModel
    let media: MediaOverlay

    private var overlays: OverlaysViewModel { viewModel.overlays }

    var body: some View {
        let mutesAll = viewModel.edit.splitScreen.mutesMedia
        VStack(alignment: .leading, spacing: 16) {
            PanelSlider(
                label: String(localized: "Main video"), value: (media.mainVolume ?? 1) * 100, range: 0...100, defaultValue: 100,
                format: .percent, identifier: "edit.split.mainVolume",
                onChange: { overlays.setMainVolume(media.id, $0 / 100) },
                onEditingChanged: { editing in editing ? viewModel.beginChange() : viewModel.endChange() }
            )
            if media.kind == .video, media.hasSound == true {
                PanelSlider(
                    label: String(localized: "This support"), value: (media.audioVolume ?? 0) * 100, range: 0...100, defaultValue: 0,
                    format: .percent, identifier: "edit.split.supportVolume",
                    onChange: { overlays.setMediaSoundVolume(media.id, $0 / 100) },
                    onEditingChanged: { editing in editing ? viewModel.beginChange() : viewModel.endChange() }
                )
                .disabled(mutesAll)
                PanelToggleRow(
                    label: String(localized: "Caption its voice"),
                    detail: String(localized: "In place of the main video’s while it shows · heard on its own, one voice at a time"),
                    isOn: media.captionsItsVoice == true, identifier: "edit.split.captionsItsVoice"
                ) { viewModel.captions.setCaptionsItsVoice(media.id, media.captionsItsVoice != true) }
            } else {
                PanelNote(text: media.kind == .photo ? String(localized: "A photo has no sound.") : String(localized: "This video has no sound."))
            }
            PanelToggleRow(
                label: String(localized: "Mute all supports"), detail: String(localized: "Your voice stays; each keeps its level for later"),
                isOn: mutesAll, identifier: "edit.split.muteAll"
            ) { overlays.setMutesAllMedia(!mutesAll) }
            PanelNote(text: String(localized: "Only while this support shows. Outside it, the main video plays as it is."))
        }
    }
}
