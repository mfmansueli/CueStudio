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
            if viewModel.clips.hasTranscript {
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
        let list = viewModel.clips.transcriptWords
        let picked = viewModel.clips.transcriptSelection
        return ScrollView {
            FlowLayout(spacing: 4, lineSpacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { index, word in
                    let isPicked = picked?.contains(index) ?? false
                    // The two ends of the pick carry a mark: where the cut starts, and (once tapped) where it ends.
                    let isStart = picked?.lowerBound == index
                    let isEnd = picked.map { $0.upperBound == index && $0.lowerBound != index } ?? false
                    Button { viewModel.clips.tapTranscriptWord(at: index) } label: {
                        HStack(spacing: 3) {
                            if isStart { Image(systemName: "arrow.right.to.line").font(.editorGlyph(EditorGlyph.small, weight: .bold)) }
                            Text(word.text)
                            if isEnd { Image(systemName: "arrow.left.to.line").font(.editorGlyph(EditorGlyph.small, weight: .bold)) }
                        }
                            .font(.system(.body, weight: isPicked ? .semibold : .regular))
                            .strikethrough(word.isRemoved, color: Palette.ink2)
                            .foregroundStyle(isPicked ? Palette.accInk : (word.isRemoved ? Palette.ink2 : Palette.ink))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(
                                isPicked ? Palette.acc : Color.clear,
                                in: RoundedRectangle(cornerRadius: Metrics.editorThumbnailRadius, style: .continuous)
                            )
                            // Each word is a 44 pt target (HIG), rows touching.
                            .frame(minHeight: Metrics.hitTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(word.isRemoved ? Text("\(word.text), cut") : Text(verbatim: word.text))
                    .accessibilityValue(isStart ? Text("Start of the pick") : (isEnd ? Text("End of the pick") : Text(verbatim: "")))
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
        let picked = viewModel.clips.selectedTranscriptWords
        if picked.isEmpty {
            // A montage's cut words leave the list (they may be from a copy of a clip): there, Undo brings them back.
            PanelNote(text: viewModel.edit.timeline.isArranged
                ? String(localized: "Tap the first word of the part to cut, then its last word. Undo brings back what you cut.")
                : String(localized: "Tap the first word of the part to cut, then its last word. Crossed-out words were cut."))
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
                if picked.contains(where: \.isRemoved), !viewModel.edit.timeline.isArranged {
                    PanelButton(
                        label: String(localized: "Put back"), systemImage: "arrow.uturn.backward", identifier: "edit.transcript.restore"
                    ) { viewModel.clips.restoreSelectedWords() }
                }
                PanelNote(text: String(localized: "Cut removes the words from the video. Fix caption text only changes what the caption says."))
            }
            .padding(.bottom, 8)
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
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("edit.transcript.pickGuide")
            Button(String(localized: "Pick again")) { viewModel.clips.clearTranscriptSelection() }
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.accText)
                .frame(minHeight: Metrics.hitTarget)
                .accessibilityIdentifier("edit.transcript.pickAgain")
        }
    }

    @ViewBuilder
    private var listen: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cue listens to the video on your iPhone to write down every word. Then you cut by text.")
                .font(.system(.subheadline))
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
            let state = viewModel.captions.captionState
            if state.isWorking {
                HStack(spacing: 10) {
                    ProgressView().tint(Palette.ink)
                    Text(state.message ?? String(localized: "Listening…")).font(.system(.subheadline, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
            } else {
                // Listening ended without words: why, and a second try only when one can help (never a button that loops).
                if state != .idle, let message = state.message {
                    PanelNote(text: message, tint: Palette.warnText)
                        .accessibilityIdentifier("edit.transcript.problem")
                }
                if state == .idle || state.canRetry {
                    PanelButton(
                        label: state == .idle ? String(localized: "Listen to the video") : String(localized: "Try again"),
                        systemImage: "waveform", isPrimary: true, identifier: "edit.transcript.listen"
                    ) { viewModel.listenForTranscript() }
                }
            }
            Spacer(minLength: 0)
        }
    }
}
