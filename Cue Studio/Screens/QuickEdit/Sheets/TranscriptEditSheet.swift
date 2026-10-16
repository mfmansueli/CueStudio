//
//  TranscriptEditSheet.swift
//  Cue Studio
//

import SwiftUI

/// Edit by text, over the editor (half height, so the video stays in view): what was said, word by word, in the order it plays.
/// Tap a word to hear it, another to take every word between them. **Cut from video** takes them out of the video; **Fix
/// caption text** only changes what a caption says. Cut words of the take stay listed, crossed out, and can be put back.
/// Without a transcript yet, it offers to listen to the video.
struct TranscriptEditSheet: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetHeader(title: String(localized: "Edit by text"), subtitle: String(localized: "Cut words, and the video goes with them."))
            if viewModel.hasTranscript {
                words
                actions
            } else {
                listen
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .cueSheetChrome()
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("edit.transcript")
    }

    private var words: some View {
        let list = viewModel.transcriptWords
        let picked = viewModel.transcriptSelection
        return ScrollView {
            FlowLayout(spacing: 4, lineSpacing: 6) {
                ForEach(Array(list.enumerated()), id: \.element.id) { index, word in
                    let isPicked = picked?.contains(index) ?? false
                    Button { viewModel.tapTranscriptWord(at: index) } label: {
                        Text(word.text)
                            .font(.system(.body, weight: isPicked ? .semibold : .regular))
                            .strikethrough(word.isRemoved, color: Palette.ink2)
                            .foregroundStyle(isPicked ? Palette.accInk : (word.isRemoved ? Palette.ink2 : Palette.ink))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(isPicked ? Palette.acc : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .frame(minHeight: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(word.isRemoved ? "\(word.text), cut" : word.text))
                    .accessibilityAddTraits(isPicked ? .isSelected : [])
                    .accessibilityIdentifier("edit.transcript.word.\(index)")
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.automatic)
    }

    @ViewBuilder
    private var actions: some View {
        let picked = viewModel.selectedTranscriptWords
        if picked.isEmpty {
            PanelNote(text: String(localized: "Tap a word, then another to pick everything between. Crossed-out words were cut."))
        } else {
            VStack(spacing: 8) {
                if picked.contains(where: { !$0.isRemoved }) {
                    PanelButton(
                        label: String(localized: "Cut from video · \(picked.filter { !$0.isRemoved }.count) words"), systemImage: "scissors",
                        isPrimary: true, identifier: "edit.transcript.cut"
                    ) { viewModel.cutSelectedWords() }
                    PanelButton(
                        label: String(localized: "Fix caption text"), systemImage: "character.cursor.ibeam", identifier: "edit.transcript.fix"
                    ) { viewModel.fixCaptionOfSelectedWords() }
                }
                if picked.contains(where: \.isRemoved), !viewModel.edit.timeline.isArranged {
                    PanelButton(
                        label: String(localized: "Put back"), systemImage: "arrow.uturn.backward", identifier: "edit.transcript.restore"
                    ) { viewModel.restoreSelectedWords() }
                }
                PanelNote(text: String(localized: "Cut removes the words from the video. Fix caption text only changes what the caption says."))
            }
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var listen: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cue listens to the video on your iPhone to write down every word. Then you cut by text.")
                .font(.system(.subheadline))
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
            if viewModel.captionState.isWorking {
                HStack(spacing: 10) {
                    ProgressView().tint(Palette.ink)
                    Text("Listening…").font(.system(.subheadline, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
            } else {
                PanelButton(
                    label: String(localized: "Listen to the video"), systemImage: "waveform", isPrimary: true, identifier: "edit.transcript.listen"
                ) { viewModel.listenForTranscript() }
            }
            Spacer(minLength: 0)
        }
    }
}
