//
//  AutoCaptionsPanel.swift
//  Cue Studio
//

import SwiftUI

/// Auto captions, before the take has any: the language spoken and "Generate captions". Cue
/// listens on the iPhone and the list opens on the new lines. When nothing can be heard, the
/// lines can be written by hand.
struct AutoCaptionsPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .autoCaptions) {
            VStack(alignment: .leading, spacing: 8) {
                PanelRowLabel(label: String(localized: "Spoken language"))
                PanelChips(
                    options: [PanelOption(CueLanguage?.none, String(localized: "Auto"), key: "automatic")]
                        + CueLanguage.allCases.map { PanelOption(Optional($0), $0.nativeName, key: $0.rawValue) },
                    selection: viewModel.edit.captionLanguage, identifier: "edit.autoCaptions.language"
                ) { viewModel.setCaptionLanguage($0) }
            }
            if let conflict = viewModel.captionLanguageConflict {
                PanelNote(text: conflict.message, tint: Palette.warnText)
                    .accessibilityIdentifier("edit.captionsLanguageNote")
            }
            CaptionStatusRow(viewModel: viewModel)
            PanelButton(
                label: viewModel.captionState.isWorking ? String(localized: "Listening…") : String(localized: "Generate captions"),
                systemImage: "sparkles", isPrimary: true, isEnabled: !viewModel.captionState.isWorking && viewModel.isReady,
                identifier: "edit.captionsMakeButton"
            ) { viewModel.makeCaptions() }
            if showsWriteByHand {
                PanelButton(
                    label: String(localized: "Write them myself"), systemImage: "pencil",
                    identifier: "edit.captionsWriteButton", action: viewModel.writeCaptionsByHand
                )
            }
        }
    }

    /// Nothing could be heard: the lines can still be written.
    private var showsWriteByHand: Bool {
        switch viewModel.captionState {
        case .noAudio, .noSpeech, .unavailable, .failed: true
        default: false
        }
    }
}
