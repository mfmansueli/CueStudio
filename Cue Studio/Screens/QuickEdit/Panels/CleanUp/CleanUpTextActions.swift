//
//  CleanUpTextActions.swift
//  Cue Studio
//

import SwiftUI

/// Clean up › Text's bottom while words are picked: where the pick is, **Cut from video** (picture, sound and captions go),
/// **Fix caption text** (only the words a caption shows; nothing is cut), and **Put back** for cut words. With nothing picked,
/// how to pick.
struct CleanUpTextActions: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let picked = viewModel.clips.selectedTranscriptWords
        if picked.isEmpty {
            PanelNote(text: String(localized: "Tap the first word of the part to cut, then its last word. Crossed-out words were cut."))
        } else {
            VStack(spacing: 8) {
                pickGuide(picked)
                if picked.contains(where: { !$0.isRemoved }) {
                    PanelButton(
                        label: String(localized: "Cut \(picked.filter { !$0.isRemoved }.count) words from the video"), systemImage: "scissors",
                        isPrimary: true, identifier: "edit.transcript.cut"
                    ) { viewModel.clips.cutSelectedWords() }
                    PanelButton(
                        label: String(localized: "Fix caption text"), systemImage: "character.cursor.ibeam", identifier: "edit.transcript.fix"
                    ) { viewModel.fixCaptionOfSelectedWords() }
                }
                if picked.contains(where: \.isRemoved) {
                    PanelButton(
                        label: String(localized: "Put back"), systemImage: "arrow.uturn.backward", identifier: "edit.transcript.restore"
                    ) { viewModel.clips.restoreSelectedWords() }
                }
                PanelNote(text: String(localized: "Cut removes the words from the video. Fix caption text only changes what the caption says."), teaches: true)
            }
        }
    }

    /// Says where the pick is: after the first tap, that it's the start and the next tap picks the end; after the second, the
    /// stretch and a way to start over.
    private func pickGuide(_ picked: [TranscriptWord]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Group {
                if picked.count == 1, let first = picked.first {
                    Text("Start: “\(first.text)”. Now tap the last word of the part.")
                } else if let first = picked.first, let last = picked.last {
                    Text("From “\(first.text)” to “\(last.text)”")
                }
            }
            .cueFont(.subheadline, weight: .semibold)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("edit.transcript.pickGuide")
            Button(String(localized: "Pick again")) { viewModel.clips.clearTranscriptSelection() }
                .cueFont(.subheadline, weight: .semibold)
                .foregroundStyle(Palette.accText)
                .frame(minHeight: Metrics.hitTarget)
                .accessibilityIdentifier("edit.transcript.pickAgain")
        }
    }
}
