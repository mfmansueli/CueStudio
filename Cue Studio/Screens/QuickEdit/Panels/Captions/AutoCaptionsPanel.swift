//
//  AutoCaptionsPanel.swift
//  Cue Studio
//

import SwiftUI

/// Auto captions, before the take has any: the language spoken (a row that opens the list in place) and "Generate captions". Cue
/// listens on the iPhone and the list opens on the new lines. When nothing can be heard, the
/// lines can be written by hand.
struct AutoCaptionsPanel: View {
    @Bindable var viewModel: QuickEditViewModel
    /// The languages opened in place, under their row, the way Captions opens them.
    @State private var showsLanguages = false

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .autoCaptions) {
            languageRow
            if showsLanguages {
                PanelInlineList(
                    note: String(localized: "The language you speak in the video"),
                    options: [PanelOption(CueLanguage?.none, String(localized: "Automatic"), key: "automatic")]
                        + CueLanguage.allCases.map { PanelOption(Optional($0), $0.nativeName, key: $0.rawValue) },
                    selection: viewModel.edit.captionLanguage, identifier: "edit.autoCaptions.language"
                ) { language in
                    viewModel.setCaptionLanguage(language)
                    showsLanguages = false
                }
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

    /// "Spoken language   Automatic ⌄": one row, the same as every other choice from a list; tapping opens the list under it.
    private var languageRow: some View {
        Button {
            Haptics.selection()
            showsLanguages.toggle()
        } label: {
            HStack(spacing: 8) {
                Text("Spoken language").font(.system(.subheadline, weight: .semibold))
                Spacer(minLength: 8)
                Text(verbatim: viewModel.edit.captionLanguage?.nativeName ?? String(localized: "Automatic"))
                    .font(.system(.subheadline))
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.editorGlyph(EditorGlyph.chip, weight: .bold))
                    .foregroundStyle(Palette.ink2)
                    .rotationEffect(.degrees(showsLanguages ? 180 : 0))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: Metrics.hitTarget)
            .editorCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(Text(verbatim: viewModel.edit.captionLanguage?.nativeName ?? String(localized: "Automatic")))
        .accessibilityAddTraits(showsLanguages ? .isSelected : [])
        .accessibilityIdentifier("edit.autoCaptions.languageRow")
    }

    /// Nothing could be heard: the lines can still be written.
    private var showsWriteByHand: Bool {
        switch viewModel.captionState {
        case .noAudio, .noSpeech, .unavailable, .failed: true
        default: false
        }
    }
}
